#!/bin/bash

#==============================================================================
# Script: manage_pg.sh
# Descrição: Painel All-in-One autônomo de gerenciamento do PostgreSQL no Proxmox VE
# Autor: Hugllas Lima
# Data: 23/09/2026
# Versão: 2.0 (100% Autônomo - todas as funções integradas em um único script)
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

# Definição das cores ANSI para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Sem Cor

# Funções de exibição colorida por finalidade (cores por função)
log_step() {
    echo -e "\n${BLUE}${BOLD}$1${NC}"
}

log_info() {
    echo -e "${CYAN}$1${NC}"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERRO] $1${NC}"
}

# Verificação de privilégios de superusuário (root)
if [ "$EUID" -ne 0 ] && [ "$(whoami)" != "postgres" ]; then
    log_error "Este script deve ser executado como root, com sudo ou com o usuário 'postgres'!"
    echo "Exemplo: sudo ./manage_pg.sh"
    exit 1
fi

# Localização dinâmica dos arquivos de configuração do PostgreSQL
find_pg_conf() {
    PG_HBA=$(find /etc/postgresql/ -name pg_hba.conf 2>/dev/null | sort -V | tail -n 1)
    PG_CONF=$(find /etc/postgresql/ -name postgresql.conf 2>/dev/null | sort -V | tail -n 1)
}

#==============================================================================
# 1. FUNÇÃO: INSTALAR POSTGRESQL 16 (+ TIMESCALEDB OPCIONAL)
#==============================================================================
instalar_postgresql() {
    echo ""
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}${BOLD} Instalador: PostgreSQL 16 (Ubuntu Server)        ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo ""

    read -p "Deseja instalar a extensão TimescaleDB neste servidor? (Recomendado para Zabbix/Métricas) (s/n): " INSTALL_TS

    log_step "[1/8] Atualizando pacotes do sistema..."
    apt update && apt upgrade -y
    apt install -y gnupg postgresql-common apt-transport-https lsb-release wget

    log_step "[2/8] Adicionando repositório do PostgreSQL..."
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

    if [ "$INSTALL_TS" = "s" ] || [ "$INSTALL_TS" = "S" ]; then
        log_step "[3/8] Adicionando repositório do TimescaleDB..."
        wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
        echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list

        log_step "[4/8] Instalando PostgreSQL 16 e TimescaleDB..."
        apt update
        apt install -y postgresql-16 timescaledb-2-postgresql-16
        log_success "PostgreSQL 16 e TimescaleDB instalados com sucesso."
    else
        log_step "[3/8] Repositório TimescaleDB..."
        log_info "TimescaleDB ignorado pelo usuário."

        log_step "[4/8] Instalando PostgreSQL 16 (Puro)..."
        apt update
        apt install -y postgresql-16
        log_success "PostgreSQL 16 instalado com sucesso."
    fi

    log_step "[5/8] Definindo senha do usuário 'postgres'..."
    read -s -p "Digite a SENHA para o usuário 'postgres': " PG_PASSWORD
    echo ""
    read -s -p "Confirme a SENHA: " PG_PASSWORD_CONFIRM
    echo ""

    if [ "$PG_PASSWORD" != "$PG_PASSWORD_CONFIRM" ]; then
        log_error "As senhas não conferem!"
        return 1
    fi

    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';"
    log_success "Senha do usuário 'postgres' definida com sucesso."

    log_step "[6/8] Configurando acessos de rede..."
    read -p "Deseja liberar acesso externo (ex: pgAdmin) para este servidor? (s/n): " ALLOW_EXT

    if [ "$ALLOW_EXT" = "s" ] || [ "$ALLOW_EXT" = "S" ]; then
        find_pg_conf
        if [ -n "$PG_CONF" ] && [ -f "$PG_CONF" ]; then
            sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
            sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
        fi

        echo ""
        log_info "Configurando redes autorizadas para acesso..."
        echo -e "${YELLOW}Exemplos:${NC}"
        echo "  - 10.10.0.0/22   (Rede Datacenter/Proxmox)"
        echo "  - 172.16.2.0/26  (Rede VPN)"
        echo "  - 192.168.1.0/24 (Rede Doméstica / Local)"
        echo ""

        declare -a NETWORKS
        local NETWORK_COUNT=0

        while true; do
            read -p "Digite a rede/IP que deseja liberar (ou 'pronto' para finalizar): " NETWORK_INPUT

            if [ "$NETWORK_INPUT" = "pronto" ] || [ "$NETWORK_INPUT" = "PRONTO" ]; then
                if [ $NETWORK_COUNT -eq 0 ]; then
                    log_error "Você precisa adicionar pelo menos uma rede!"
                    continue
                fi
                break
            fi

            if [[ $NETWORK_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
                NETWORKS+=("$NETWORK_INPUT")
                ((NETWORK_COUNT++))
                log_success "Rede adicionada: $NETWORK_INPUT"
            else
                log_error "Formato inválido! Use o formato CIDR (ex: 10.10.0.0/22 ou 192.168.1.0/24)"
            fi
        done

        if [ -n "$PG_HBA" ] && [ -f "$PG_HBA" ]; then
            echo ""
            log_info "Adicionando redes ao pg_hba.conf..."
            for NETWORK in "${NETWORKS[@]}"; do
                echo "host    all             all             $NETWORK               scram-sha-256" >> "$PG_HBA"
                log_success "Rede liberada: $NETWORK"
            done
        fi
        log_success "Acesso externo LIBERADO para ${NETWORK_COUNT} rede(s)."
    else
        log_warning "Acesso externo BLOQUEADO (Apenas localhost)."
    fi

    if [ "$INSTALL_TS" = "s" ] || [ "$INSTALL_TS" = "S" ]; then
        log_step "[7/8] Otimizando o banco de dados com timescaledb-tune..."
        timescaledb-tune --quiet --yes
        log_success "Parâmetros de performance do PostgreSQL otimizados."
    else
        log_step "[7/8] Otimização de performance..."
        log_info "TimescaleDB não selecionado. Otimização com timescaledb-tune ignorada."
    fi

    log_step "[8/8] Reiniciando serviço PostgreSQL..."
    systemctl restart postgresql
    systemctl enable postgresql

    SERVER_IP=$(hostname -I | awk '{print $1}')
    [ -z "$SERVER_IP" ] && SERVER_IP="<IP_DO_SERVIDOR>"

    echo ""
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}${BOLD} [OK] Instalação concluída com sucesso! ${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}Informações de Acesso:${NC}"
    echo -e "   ${BOLD}Usuário:${NC} ${GREEN}postgres${NC}"
    echo -e "   ${BOLD}Porta:${NC} ${YELLOW}5432${NC}"
    echo -e "   ${BOLD}Acesso Local:${NC} ${BLUE}psql -U postgres${NC}"
    echo -e "   ${BOLD}Acesso Remoto:${NC} ${BLUE}psql -h $SERVER_IP -U postgres${NC}"
    echo ""
}

#==============================================================================
# 2. FUNÇÃO: CRIAR BANCO DE DADOS E USUÁRIO
#==============================================================================
criar_banco() {
    echo ""
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN}${BOLD} Assistente de Criação de Banco de Dados e Usuário  ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""

    read -p "Digite o nome do NOVO BANCO DE DADOS (ex: zabbix): " DBNAME
    if [ -z "$DBNAME" ]; then
        log_error "O nome do banco de dados não pode ficar vazio!"
        return 1
    fi

    read -p "Digite o nome do NOVO USUÁRIO (ex: zabbix): " DBUSER
    if [ -z "$DBUSER" ]; then
        log_error "O nome do usuário não pode ficar vazio!"
        return 1
    fi

    read -s -p "Digite a SENHA para este usuário: " DBPASS
    echo ""
    read -s -p "Confirme a SENHA: " DBPASS_CONFIRM
    echo ""

    if [ "$DBPASS" != "$DBPASS_CONFIRM" ]; then
        log_error "As senhas não conferem!"
        return 1
    fi

    if [ -z "$DBPASS" ]; then
        log_error "A senha não pode ficar vazia!"
        return 1
    fi

    log_step "Criando usuário e banco de dados no PostgreSQL..."
    sudo -u postgres psql -c "CREATE USER \"$DBUSER\" WITH PASSWORD '$DBPASS';"
    sudo -u postgres psql -c "CREATE DATABASE \"$DBNAME\" OWNER \"$DBUSER\";"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DBNAME\" TO \"$DBUSER\";"
    log_success "Banco '$DBNAME' e usuário '$DBUSER' provisionados com sucesso."

    echo ""
    read -p "Deseja habilitar a extensão TimescaleDB neste banco? (Recomendado para Zabbix) (s/n): " ENABLE_TS
    if [ "$ENABLE_TS" = "s" ] || [ "$ENABLE_TS" = "S" ]; then
        log_info "Habilitando a extensão TimescaleDB no banco '$DBNAME'..."
        if sudo -u postgres psql -d "$DBNAME" -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" >/dev/null 2>&1; then
            TS_STATUS="Ativada"
            log_success "Extensão TimescaleDB ativada com sucesso."
        else
            TS_STATUS="Falhou (extensão não instalada no servidor)"
            log_warning "Não foi possível ativar TimescaleDB. O pacote da extensão está instalado?"
        fi
    else
        TS_STATUS="Desativada"
        log_info "Extensão TimescaleDB não solicitada."
    fi

    SERVER_IP=$(hostname -I | awk '{print $1}')
    [ -z "$SERVER_IP" ] && SERVER_IP="<IP_DO_SERVIDOR>"

    echo ""
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}${BOLD} [OK] BANCO DE DADOS E USUÁRIO CRIADOS COM SUCESSO!  ${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}Resumo do Provisionamento:${NC}"
    echo -e "   ${BOLD}Banco de Dados:${NC} ${BLUE}$DBNAME${NC}"
    echo -e "   ${BOLD}Usuário (Owner):${NC} ${GREEN}$DBUSER${NC}"
    echo -e "   ${BOLD}TimescaleDB:${NC} ${YELLOW}$TS_STATUS${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}String de Conexão (URL):${NC}"
    echo -e "   ${YELLOW}postgresql://${DBUSER}:${DBPASS}@${SERVER_IP}:5432/${DBNAME}${NC}"
    echo ""
}

#==============================================================================
# 3. MÓDULO: GERENCIAMENTO DE REDES (pg_hba.conf) SEM DOWNTIME
#==============================================================================
listar_redes() {
    find_pg_conf
    if [ -z "$PG_HBA" ] || [ ! -f "$PG_HBA" ]; then
        log_error "Arquivo pg_hba.conf não foi encontrado! O PostgreSQL está instalado?"
        return 1
    fi

    echo ""
    log_info "Redes externas cadastradas em: $PG_HBA"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    
    local count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+([^[:space:]]+) ]]; then
            local net="${BASH_REMATCH[1]}"
            if [ "$net" != "127.0.0.1/32" ] && [ "$net" != "::1/128" ]; then
                ((count++))
                echo -e "  [${YELLOW}$count${NC}] Rede/IP autorizado: ${GREEN}${BOLD}$net${NC}"
            fi
        fi
    done < "$PG_HBA"

    if [ $count -eq 0 ]; then
        log_warning "Nenhuma rede externa personalizada encontrada (apenas conexões locais)."
    fi
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

adicionar_rede() {
    find_pg_conf
    if [ -z "$PG_HBA" ] || [ ! -f "$PG_HBA" ]; then
        log_error "Arquivo pg_hba.conf não foi encontrado!"
        return 1
    fi

    echo ""
    log_info "Adicionar nova rede ou IP autorizado"
    echo "Exemplos:"
    echo "  - 10.10.0.0/22    (Rede Datacenter/Proxmox)"
    echo "  - 172.16.2.0/26   (Rede VPN)"
    echo "  - 192.168.1.0/24  (Rede Doméstica / Local)"
    echo "  - 10.10.1.160/32  (IP específico)"
    echo ""

    read -p "Digite a rede/IP em formato CIDR (ou 'cancelar'): " NEW_NET

    if [ "$NEW_NET" = "cancelar" ] || [ -z "$NEW_NET" ]; then
        log_info "Operação cancelada."
        return 0
    fi

    if [[ ! $NEW_NET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
        log_error "Formato inválido! Use notação CIDR válida (ex: 10.10.0.0/22 ou 192.168.1.0/24)."
        return 1
    fi

    if grep -qE "^[[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+$NEW_NET" "$PG_HBA"; then
        log_warning "A rede '$NEW_NET' já está cadastrada no pg_hba.conf!"
        return 0
    fi

    if [ -n "$PG_CONF" ] && [ -f "$PG_CONF" ]; then
        if grep -qE "^#?listen_addresses = 'localhost'" "$PG_CONF"; then
            sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
            sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
            log_info "Configurado 'listen_addresses = *' no postgresql.conf."
        fi
    fi

    echo "host    all             all             $NEW_NET               scram-sha-256" >> "$PG_HBA"
    log_success "Rede '$NEW_NET' adicionada ao pg_hba.conf."

    if command -v systemctl >/dev/null 2>&1; then
        log_info "Recarregando configurações do PostgreSQL (sem downtime)..."
        systemctl reload postgresql
        log_success "Serviço PostgreSQL recarregado com sucesso!"
    fi
}

remover_rede() {
    find_pg_conf
    if [ -z "$PG_HBA" ] || [ ! -f "$PG_HBA" ]; then
        log_error "Arquivo pg_hba.conf não foi encontrado!"
        return 1
    fi

    echo ""
    log_info "Redes disponíveis para remoção:"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"

    declare -a NET_ARRAY
    local count=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+([^[:space:]]+) ]]; then
            local net="${BASH_REMATCH[1]}"
            if [ "$net" != "127.0.0.1/32" ] && [ "$net" != "::1/128" ]; then
                ((count++))
                NET_ARRAY[$count]="$net"
                echo -e "  [${YELLOW}$count${NC}] $net"
            fi
        fi
    done < "$PG_HBA"

    if [ $count -eq 0 ]; then
        log_warning "Nenhuma rede personalizada encontrada para remoção."
        return 0
    fi
    echo -e "${CYAN}----------------------------------------------------------------${NC}"

    read -p "Digite o NÚMERO da rede que deseja REMOVER (ou '0' para cancelar): " OPCAO_DEL

    if [ "$OPCAO_DEL" = "0" ] || [ -z "$OPCAO_DEL" ]; then
        log_info "Operação cancelada."
        return 0
    fi

    local TARGET_NET="${NET_ARRAY[$OPCAO_DEL]}"
    if [ -z "$TARGET_NET" ]; then
        log_error "Opção inválida!"
        return 1
    fi

    read -p "Tem certeza que deseja remover o acesso da rede '$TARGET_NET'? (s/n): " CONFIRM_DEL
    if [ "$CONFIRM_DEL" = "s" ] || [ "$CONFIRM_DEL" = "S" ]; then
        sed -i "\|host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+$TARGET_NET|d" "$PG_HBA"
        log_success "Rede '$TARGET_NET' removida com sucesso do pg_hba.conf."

        if command -v systemctl >/dev/null 2>&1; then
            log_info "Recarregando configurações do PostgreSQL..."
            systemctl reload postgresql
            log_success "Configurações aplicadas!"
        fi
    else
        log_info "Remoção cancelada."
    fi
}

menu_redes() {
    while true; do
        echo ""
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${CYAN}${BOLD}     MÓDULO: GERENCIAMENTO DE REDES E ACESSOS       ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e "  ${BOLD}1)${NC} Listar redes autorizadas"
        echo -e "  ${BOLD}2)${NC} Adicionar nova rede/IP (CIDR)"
        echo -e "  ${BOLD}3)${NC} Remover rede/IP existente"
        echo -e "  ${BOLD}0)${NC} Voltar ao menu principal"
        echo -e "${CYAN}----------------------------------------------------${NC}"
        read -p "Selecione uma opção [0-3]: " SUB_OPCAO

        case "$SUB_OPCAO" in
            1) listar_redes ;;
            2) adicionar_rede ;;
            3) remover_rede ;;
            0) break ;;
            *) log_error "Opção inválida!" ;;
        esac
    done
}

#==============================================================================
# 4. FUNÇÃO: EXCLUIR BANCO DE DADOS
#==============================================================================
excluir_banco() {
    echo ""
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${CYAN}${BOLD} Assistente de Exclusão de Banco de Dados PostgreSQL${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""

    log_info "Bancos de dados disponíveis no servidor:"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    sudo -u postgres psql -t -A -F " | " -c "
        SELECT d.datname AS banco, pg_catalog.pg_get_userbyid(d.datdba) AS dono, pg_size_pretty(pg_database_size(d.datname)) AS tamanho
        FROM pg_database d
        WHERE d.datistemplate = false AND d.datname NOT IN ('postgres')
        ORDER BY d.datname;
    " | while IFS=" | " read -r DBNAME OWNER SIZE; do
        if [ -n "$DBNAME" ]; then
            echo -e "  [BD] Banco: ${BLUE}${BOLD}$DBNAME${NC} | Dono: ${GREEN}$OWNER${NC} | Tamanho: ${YELLOW}$SIZE${NC}"
        fi
    done
    echo -e "${CYAN}----------------------------------------------------${NC}"
    echo ""

    read -p "Digite o NOME DO BANCO DE DADOS que deseja EXCLUIR: " TARGET_DB

    if [ -z "$TARGET_DB" ]; then
        log_error "O nome do banco de dados não pode ficar vazio!"
        return 1
    fi

    if [ "$TARGET_DB" = "postgres" ] || [ "$TARGET_DB" = "template0" ] || [ "$TARGET_DB" = "template1" ]; then
        log_error "Por segurança, bancos internos do sistema ('$TARGET_DB') não podem ser removidos!"
        return 1
    fi

    DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$TARGET_DB';")
    if [ "$DB_EXISTS" != "1" ]; then
        log_error "O banco de dados '$TARGET_DB' não foi encontrado no servidor!"
        return 1
    fi

    DB_OWNER=$(sudo -u postgres psql -tAc "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='$TARGET_DB';")

    echo ""
    log_warning "Atenção: Todos os dados, tabelas e registros contidos em '${TARGET_DB}' serão PERDIDOS!"

    read -p "Deseja realizar um backup de segurança deste banco antes de excluir? (s/n): " DO_BACKUP
    if [ "$DO_BACKUP" = "s" ] || [ "$DO_BACKUP" = "S" ]; then
        BACKUP_DIR="/root/backups_postgres"
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/${TARGET_DB}_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        log_info "Gerando cópia de segurança em $BACKUP_FILE..."
        if sudo -u postgres pg_dump "$TARGET_DB" | gzip > "$BACKUP_FILE"; then
            log_success "Backup concluído: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
        else
            log_error "Falha ao realizar o backup!"
            read -p "Deseja continuar com a exclusão mesmo assim? (s/n): " CONTINUE_ANYWAY
            if [ "$CONTINUE_ANYWAY" != "s" ] && [ "$CONTINUE_ANYWAY" != "S" ]; then
                log_info "Operação cancelada pelo usuário."
                return 1
            fi
        fi
    fi

    echo ""
    read -p "Para confirmar a EXCLUSÃO PERMANENTE, digite exatamente '$TARGET_DB': " CONFIRM_NAME

    if [ "$CONFIRM_NAME" != "$TARGET_DB" ]; then
        log_info "Confirmação incorreta. Operação cancelada. Nenhuma exclusão foi realizada."
        return 0
    fi

    echo ""
    log_info "Encerrando conexões ativas com o banco '$TARGET_DB'..."
    sudo -u postgres psql -c "
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE datname = '$TARGET_DB' AND pid <> pg_backend_pid();
    " >/dev/null 2>&1 || true

    log_info "Excluindo banco de dados '$TARGET_DB'..."
    if sudo -u postgres psql -c "DROP DATABASE \"$TARGET_DB\" WITH (FORCE);" 2>/dev/null; then
        log_success "Banco de dados '$TARGET_DB' excluído com sucesso!"
    elif sudo -u postgres psql -c "DROP DATABASE \"$TARGET_DB\";"; then
        log_success "Banco de dados '$TARGET_DB' excluído com sucesso!"
    else
        log_error "Falha ao tentar excluir o banco de dados '$TARGET_DB'."
        return 1
    fi

    if [ -n "$DB_OWNER" ] && [ "$DB_OWNER" != "postgres" ]; then
        echo ""
        read -p "O banco pertencia ao usuário '$DB_OWNER'. Deseja EXCLUIR também este usuário? (s/n): " DROP_USER
        if [ "$DROP_USER" = "s" ] || [ "$DROP_USER" = "S" ]; then
            OTHER_DBS=$(sudo -u postgres psql -tAc "SELECT datname FROM pg_database WHERE pg_catalog.pg_get_userbyid(datdba) = '$DB_OWNER' AND datname != '$TARGET_DB';")
            if [ -n "$OTHER_DBS" ]; then
                log_warning "O usuário '$DB_OWNER' ainda é proprietário de outro(s) banco(s): $(echo $OTHER_DBS | tr '\n' ' ')"
                log_warning "O usuário '$DB_OWNER' NÃO foi excluído para evitar quebras em outros serviços."
            else
                log_info "Excluindo o usuário '$DB_OWNER'..."
                if sudo -u postgres psql -c "DROP USER \"$DB_OWNER\";"; then
                    log_success "Usuário '$DB_OWNER' excluído com sucesso!"
                else
                    log_error "Não foi possível excluir o usuário '$DB_OWNER'."
                fi
            fi
        fi
    fi

    echo ""
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}${BOLD} [OK] Operação finalizada com sucesso!              ${NC}"
    echo -e "${GREEN}====================================================${NC}"
}

#==============================================================================
# 5. FUNÇÃO: STATUS DO SERVIÇO E CONEXÕES ATIVAS
#==============================================================================
status_servico() {
    echo ""
    log_info "Status do serviço PostgreSQL:"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status postgresql --no-pager
    fi
    echo -e "${CYAN}----------------------------------------------------${NC}"

    if command -v psql >/dev/null 2>&1 && id "postgres" >/dev/null 2>&1; then
        echo ""
        log_info "Conexões ativas no banco de dados:"
        sudo -u postgres psql -c "
            SELECT pid, usename, datname, client_addr, state 
            FROM pg_stat_activity 
            WHERE pid <> pg_backend_pid();
        " 2>/dev/null || log_warning "Não foi possível consultar sessões ativas."
    fi
}

#==============================================================================
# 6. FUNÇÃO: DESINSTALAR POSTGRESQL (PURGE / LIMPEZA PROFUNDA)
#==============================================================================
desinstalar_postgresql() {
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}${BOLD} [AVISO CRÍTICO] DESINSTALADOR DO POSTGRESQL & TIMESCALEDB      ${NC}"
    echo -e "${RED}================================================================${NC}"
    log_warning "Este procedimento irá parar os serviços, purgar pacotes e remover"
    log_warning "definitivamente todos os bancos de dados, arquivos e configurações!"
    echo ""

    read -p "Tem certeza absoluta que deseja continuar? Digite 'CONFIRMAR' para prosseguir: " CONFIRMACAO

    if [ "$CONFIRMACAO" != "CONFIRMAR" ]; then
        log_info "Operação cancelada pelo usuário. Nenhuma alteração foi realizada."
        return 0
    fi

    log_step "[ETAPA 1/7] Verificação de Backup Prévio"
    if systemctl is-active --quiet postgresql 2>/dev/null || pgrep -x "postgres" > /dev/null; then
        read -p "Deseja realizar um backup de segurança (pg_dumpall) antes da remoção? (s/n): " DO_BACKUP
        if [ "$DO_BACKUP" = "s" ] || [ "$DO_BACKUP" = "S" ]; then
            BACKUP_DIR="/root/backups_postgres"
            mkdir -p "$BACKUP_DIR"
            BACKUP_FILE="$BACKUP_DIR/backup_all_$(date +%Y%m%d_%H%M%S).sql.gz"
            
            log_info "Gerando dump de todos os bancos em $BACKUP_FILE..."
            if sudo -u postgres pg_dumpall | gzip > "$BACKUP_FILE"; then
                log_success "Backup concluído com sucesso: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
            else
                log_error "Falha ao criar backup!"
                read -p "Deseja continuar mesmo sem o backup bem-sucedido? (s/n): " PROCEED_NO_BACKUP
                if [ "$PROCEED_NO_BACKUP" != "s" ] && [ "$PROCEED_NO_BACKUP" != "S" ]; then
                    log_info "Operação abortada para segurança dos dados."
                    return 1
                fi
            fi
        else
            log_warning "Backup ignorado pelo usuário."
        fi
    else
        log_warning "Serviço PostgreSQL não está em execução. Pulando etapa de backup."
    fi

    log_step "[ETAPA 2/7] Parando serviços e processos do PostgreSQL"
    if command -v systemctl >/dev/null 2>&1; then
        log_info "Parando e desabilitando serviço postgresql..."
        timeout 10s systemctl stop postgresql 2>/dev/null || true
        systemctl disable postgresql 2>/dev/null || true
    fi

    if pgrep -u postgres > /dev/null 2>&1; then
        log_info "Encerrando processos residuais do usuário postgres..."
        pkill -9 -u postgres 2>/dev/null || true
        sleep 2
    fi
    log_success "Serviços e processos finalizados."

    log_step "[ETAPA 3/7] Removendo clusters do PostgreSQL"
    if command -v pg_lsclusters >/dev/null 2>&1 && command -v pg_dropcluster >/dev/null 2>&1; then
        log_info "Destruindo clusters gerenciados pelo postgresql-common..."
        pg_lsclusters --no-header 2>/dev/null | while read -r version cluster port status owner datadir log; do
            if [ -n "$version" ] && [ -n "$cluster" ]; then
                log_info "Removendo cluster: versão $version / nome $cluster..."
                pg_dropcluster --stop "$version" "$cluster" 2>/dev/null || true
            fi
        done
        log_success "Clusters removidos."
    else
        log_info "Nenhum cluster ativo encontrado."
    fi

    log_step "[ETAPA 4/7] Purgando pacotes do PostgreSQL e TimescaleDB"
    export DEBIAN_FRONTEND=noninteractive

    log_info "Executando remoção completa (apt purge)..."
    apt-get purge -y \
        "postgresql*" \
        "timescaledb*" \
        "libpq*" \
        "pgdg-keyring" \
        "timescaledb-tools" 2>/dev/null || true

    log_info "Removendo dependências órfãs..."
    apt-get autoremove --purge -y
    apt-get autoclean -y

    log_info "Limpando configurações residuais no DPKG..."
    REMAINING_RC=$(dpkg -l | grep -E '^rc\s+.*(postgres|timescale|libpq)' | awk '{print $2}' || true)
    if [ -n "$REMAINING_RC" ]; then
        echo "$REMAINING_RC" | xargs -r dpkg --purge
    fi
    log_success "Pacotes desinstalados e limpos com sucesso."

    log_step "[ETAPA 5/7] Limpando diretórios de dados, logs e configurações"
    DIRECTORIES_TO_REMOVE=(
        "/etc/postgresql"
        "/etc/postgresql-common"
        "/var/lib/postgresql"
        "/var/log/postgresql"
        "/var/run/postgresql"
        "/var/cache/postgresql"
    )

    for DIR in "${DIRECTORIES_TO_REMOVE[@]}"; do
        if [ -d "$DIR" ] || [ -f "$DIR" ]; then
            log_info "Removendo diretório residual: $DIR"
            rm -rf "$DIR"
        fi
    done

    log_info "Removendo sockets e locks no /tmp..."
    rm -rf /tmp/.s.PGSQL.* 2>/dev/null || true
    log_success "Dados, configurações e sockets do PostgreSQL foram excluídos."

    log_step "[ETAPA 6/7] Removendo repositórios APT e chaves GPG adicionadas"
    REPO_FILES=(
        "/etc/apt/sources.list.d/timescaledb.list"
        "/etc/apt/sources.list.d/pgdg.list"
        "/etc/apt/sources.list.d/pgdg.sources"
        "/etc/apt/trusted.gpg.d/timescaledb.gpg"
        "/etc/apt/trusted.gpg.d/apt.postgresql.org.gpg"
        "/etc/apt/trusted.gpg.d/apt.postgresql.org.asc"
    )

    for FILE in "${REPO_FILES[@]}"; do
        if [ -f "$FILE" ]; then
            log_info "Removendo repositório/chave: $FILE"
            rm -f "$FILE"
        fi
    done

    log_info "Atualizando lista de pacotes APT..."
    apt-get update -o Acquire::ForceIPv4=true -o Acquire::http::Timeout=15 || apt-get update || true
    log_success "Repositórios limpos e lista do APT sincronizada com sucesso."

    log_step "[ETAPA 7/7] Limpeza do usuário de sistema 'postgres'"
    if id "postgres" >/dev/null 2>&1; then
        log_info "Removendo o usuário do sistema 'postgres'..."
        deluser --remove-home postgres 2>/dev/null || userdel -r postgres 2>/dev/null || true
    fi

    if getent group "postgres" >/dev/null 2>&1; then
        log_info "Removendo o grupo 'postgres'..."
        delgroup postgres 2>/dev/null || groupdel postgres 2>/dev/null || true
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload 2>/dev/null || true
        systemctl reset-failed 2>/dev/null || true
    fi

    log_success "Usuário e grupo 'postgres' removidos."

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}${BOLD} [OK] DESINSTALAÇÃO DO POSTGRESQL CONCLUÍDA COM SUCESSO!        ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    log_info "O servidor está totalmente limpo de resíduos do PostgreSQL."
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        log_warning "Lembrete: O arquivo de backup foi preservado em: $BACKUP_FILE"
    fi
    echo ""
}

#==============================================================================
# MENU PRINCIPAL ITERATIVO
#==============================================================================
while true; do
    echo ""
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${BLUE}${BOLD}   [+] PAINEL DE CONTROLE POSTGRESQL (PROXMOX VE)       ${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "  ${BOLD}1)${NC} Instalar PostgreSQL 16 (+ TimescaleDB Opcional)"
    echo -e "  ${BOLD}2)${NC} Criar Banco de Dados e Usuário"
    echo -e "  ${BOLD}3)${NC} Gerenciar Redes e Acessos Externos (pg_hba.conf)"
    echo -e "  ${BOLD}4)${NC} Excluir Banco de Dados"
    echo -e "  ${BOLD}5)${NC} Status do Serviço e Conexões Ativas"
    echo -e "  ${BOLD}6)${NC} Desinstalar PostgreSQL (Limpeza Completa)"
    echo -e "  ${BOLD}0)${NC} Sair do Painel"
    echo -e "${BLUE}========================================================${NC}"
    read -p "Selecione uma opção [0-6]: " MENU_OPCAO

    case "$MENU_OPCAO" in
        1) instalar_postgresql ;;
        2) criar_banco ;;
        3) menu_redes ;;
        4) excluir_banco ;;
        5) status_servico ;;
        6) desinstalar_postgresql ;;
        0)
            log_info "Encerrando painel de gerenciamento. Até logo!"
            exit 0
            ;;
        *)
            log_error "Opção inválida! Escolha um número entre 0 e 6."
            ;;
    esac
done
