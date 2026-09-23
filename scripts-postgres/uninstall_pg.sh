#!/bin/bash

#==============================================================================
# Script: uninstall_pg.sh
# Descrição: Desinstalação completa e remoção do PostgreSQL e TimescaleDB
# Autor: Hugllas Lima
# Data: 22/09/2026
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

# Interrompe o script se houver erro crítico não tratado
set -e

# Cores para feedback no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificação de privilégios de superusuário (root)
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ ERRO: Este script deve ser executado como root ou com sudo!${NC}"
    echo "Exemplo: sudo ./uninstall_pg.sh"
    exit 1
fi

echo -e "${RED}================================================================${NC}"
echo -e "${RED} ⚠️  AVISO CRÍTICO: DESINSTALADOR DO POSTGRESQL & TIMESCALEDB     ${NC}"
echo -e "${RED}================================================================${NC}"
echo -e "${YELLOW}Este script irá parar os serviços, desinstalar os pacotes e pode${NC}"
echo -e "${YELLOW}remover definitivamente todas as bases de dados e configurações!${NC}"
echo -e "${YELLOW}Ambiente detectado: $(hostname) (Kernel: $(uname -r))${NC}"
echo ""

# Confirmação de segurança explícita
read -p "Tem certeza absoluta que deseja continuar? Digite 'CONFIRMAR' para prosseguir: " CONFIRMACAO

if [ "$CONFIRMACAO" != "CONFIRMAR" ]; then
    echo -e "${BLUE}Operação cancelada pelo usuário. Nenhuma alteração foi realizada.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 1/7] Verificação de Backup Prévio${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

# Oferece a oportunidade de gerar um dump se o PostgreSQL estiver ativo
if systemctl is-active --quiet postgresql 2>/dev/null || pgrep -x "postgres" > /dev/null; then
    read -p "Deseja realizar um backup de segurança (pg_dumpall) antes da remoção? (s/n): " DO_BACKUP
    if [ "$DO_BACKUP" = "s" ] || [ "$DO_BACKUP" = "S" ]; then
        BACKUP_DIR="/root/backups_postgres"
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/backup_all_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        echo "Gerando dump de todos os bancos de dados em $BACKUP_FILE..."
        if sudo -u postgres pg_dumpall | gzip > "$BACKUP_FILE"; then
            echo -e "${GREEN}✓ Backup concluído com sucesso: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))${NC}"
        else
            echo -e "${RED}❌ Falha ao criar backup! Verifique antes de continuar.${NC}"
            read -p "Deseja continuar mesmo sem o backup bem-sucedido? (s/n): " PROCEED_NO_BACKUP
            if [ "$PROCEED_NO_BACKUP" != "s" ] && [ "$PROCEED_NO_BACKUP" != "S" ]; then
                echo "Operação abortada para segurança dos dados."
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}✓ Backup ignorado pelo usuário.${NC}"
    fi
else
    echo -e "${YELLOW}Serviço PostgreSQL não está em execução. Pulando etapa de backup automático.${NC}"
fi

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 2/7] Parando serviços e processos do PostgreSQL${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

# Desabilita e para serviços systemd
if command -v systemctl >/dev/null 2>&1; then
    echo "Parando e desabilitando serviço postgresql..."
    systemctl stop postgresql 2>/dev/null || true
    systemctl disable postgresql 2>/dev/null || true
fi

# Finaliza qualquer processo residual do postgres (comum em LXC/VMs com conexões presas)
if pgrep -u postgres > /dev/null 2>&1; then
    echo "Encerrando processos residuais do usuário postgres..."
    pkill -9 -u postgres 2>/dev/null || true
    sleep 2
fi
echo -e "${GREEN}✓ Serviços e processos finalizados.${NC}"

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 3/7] Removendo clusters do PostgreSQL${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

if command -v pg_lsclusters >/dev/null 2>&1 && command -v pg_dropcluster >/dev/null 2>&1; then
    echo "Destruindo clusters gerenciados pelo postgresql-common..."
    pg_lsclusters --no-header 2>/dev/null | while read -r version cluster port status owner datadir log; do
        if [ -n "$version" ] && [ -n "$cluster" ]; then
            echo "Removendo cluster: versão $version / nome $cluster..."
            pg_dropcluster --stop "$version" "$cluster" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}✓ Clusters removidos.${NC}"
else
    echo "pg_dropcluster não encontrado ou nenhum cluster ativo."
fi

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 4/7] Purgando pacotes do PostgreSQL e TimescaleDB${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

export DEBIAN_FRONTEND=noninteractive

echo "Executando remoção completa (apt purge)..."
apt-get purge -y \
    "postgresql*" \
    "timescaledb*" \
    "libpq*" \
    "pgdg-keyring" \
    "timescaledb-tools" 2>/dev/null || true

echo "Removendo dependências órfãs..."
apt-get autoremove --purge -y
apt-get autoclean -y

# Remove pacotes que ficaram em estado 'rc' (residual-config) no dpkg
echo "Limpando configurações residuais no DPKG..."
REMAINING_RC=$(dpkg -l | grep -E '^rc\s+.*(postgres|timescale|libpq)' | awk '{print $2}' || true)
if [ -n "$REMAINING_RC" ]; then
    echo "$REMAINING_RC" | xargs -r dpkg --purge
fi
echo -e "${GREEN}✓ Pacotes desinstalados e limpos com sucesso.${NC}"

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 5/7] Limpando diretórios de dados, logs e configurações${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

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
        echo "Removendo diretório residual: $DIR"
        rm -rf "$DIR"
    fi
done

# Limpeza de sockets e locks no /tmp
echo "Removendo sockets e locks no /tmp..."
rm -rf /tmp/.s.PGSQL.* 2>/dev/null || true

echo -e "${GREEN}✓ Dados, configurações e sockets do PostgreSQL foram excluídos.${NC}"

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 6/7] Removendo repositórios APT e chaves GPG adicionadas${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

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
        echo "Removendo repositório/chave: $FILE"
        rm -f "$FILE"
    fi
done

echo "Atualizando lista de pacotes APT após remoção dos repositórios..."
apt-get update -qq || true
echo -e "${GREEN}✓ Repositórios de terceiros limpos com sucesso.${NC}"

echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "${BLUE}[ETAPA 7/7] Limpeza do usuário de sistema 'postgres'${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

if id "postgres" >/dev/null 2>&1; then
    echo "Removendo o usuário do sistema 'postgres'..."
    deluser --remove-home postgres 2>/dev/null || userdel -r postgres 2>/dev/null || true
fi

if getent group "postgres" >/dev/null 2>&1; then
    echo "Removendo o grupo 'postgres'..."
    delgroup postgres 2>/dev/null || groupdel postgres 2>/dev/null || true
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true
fi

echo -e "${GREEN}✓ Usuário e grupo 'postgres' removidos.${NC}"

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} ✓ DESINSTALAÇÃO DO POSTGRESQL CONCLUÍDA COM SUCESSO!            ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo "O servidor (VM ou Contêiner LXC) está totalmente limpo de resíduos"
echo "do PostgreSQL e TimescaleDB."
if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}Lembrete: O arquivo de backup foi preservado em: $BACKUP_FILE${NC}"
fi
echo ""
