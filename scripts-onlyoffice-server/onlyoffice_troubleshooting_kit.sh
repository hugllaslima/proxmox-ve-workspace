#!/bin/bash

# -----------------------------------------------------------------------------
# Script: onlyoffice_troubleshooting_kit.sh
# Descrição: Oferece um conjunto de ferramentas interativas para diagnosticar e
#            tentar corrigir problemas comuns no OnlyOffice Document Server,
#            focando em erros de conexão com RabbitMQ, PostgreSQL e
#            configurações gerais.
# Autor: Hugllas Lima
# Data de Criação: 25/11/2025
# Versão: 2.0
# Licença: GPL-3.0
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./onlyoffice_troubleshooting_kit.sh
#
# Pré-requisitos:
#   - OnlyOffice Document Server deve estar instalado.
#   - Acesso root (sudo) é necessário para executar diagnósticos e correções.
#
# Notas Importantes:
#   - Este script é interativo e guiará você através de um menu de opções.
#   - Algumas ações, como reiniciar serviços ou recriar configurações, podem
#     causar uma breve indisponibilidade do serviço.
#   - Recomenda-se fazer backup de configurações críticas antes de aplicar
#     correções destrutivas.
#
# -----------------------------------------------------------------------------

#     de configurações existentes. Certifique-se de que estejam corretas.
#
################################################################################

set -e # Parar execução em caso de erro (exceto onde explicitamente tratado)

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis globais para configurações
ONLYOFFICE_IP=""
RABBITMQ_HOST=""
RABBITMQ_PORT="5672"
RABBITMQ_USER=""
RABBITMQ_PASS=""
RABBITMQ_VHOST="onlyoffice_vhost"
JWT_SECRET=""
POSTGRES_PASS=""
BACKUP_DIR=""

# Função para exibir cabeçalho
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}║        OnlyOffice Document Server - Troubleshooting        ║${NC}"
    echo -e "${BLUE}║                 Ubuntu Server 24.04 LTS                    ║${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

# Função para perguntar sim/não
ask_yes_no() {
    local prompt=$1
    local response
    while true; do
        read -p "$prompt (s/n): " response
        case $response in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Por favor, responda 's' ou 'n'.";;
        esac
    done
}

# Função para validar IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Função para gerar senha/token aleatório
generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# Função para coletar informações essenciais
collect_info() {
    echo -e "${YELLOW}═══ Coleta de Informações Essenciais ═══${NC}\n"

    while true; do
        read -p "Digite o IP deste servidor OnlyOffice (ex: 10.10.1.228): " ONLYOFFICE_IP
        if validate_ip "$ONLYOFFICE_IP"; then break; else echo -e "${RED}✗ IP inválido.${NC}"; fi
    done

    while true; do
        read -p "Digite o IP do servidor RabbitMQ (ex: 10.10.1.231): " RABBITMQ_HOST
        if validate_ip "$RABBITMQ_HOST"; then break; else echo -e "${RED}✗ IP inválido.${NC}"; fi
    done

    read -p "Porta do RabbitMQ [${RABBITMQ_PORT}]: " input_port
    RABBITMQ_PORT=${input_port:-$RABBITMQ_PORT}

    read -p "Usuário do RabbitMQ: " RABBITMQ_USER

    while true; do
        read -sp "Senha do RabbitMQ: " RABBITMQ_PASS
        echo
        if [ -n "$RABBITMQ_PASS" ]; then break; else echo -e "${RED}A senha não pode estar vazia.${NC}"; fi
    done

    read -p "VHost do RabbitMQ [${RABBITMQ_VHOST}]: " input_vhost
    RABBITMQ_VHOST=${input_vhost:-$RABBITMQ_VHOST}

    # Tentar recuperar senha do PostgreSQL e JWT Secret
    echo -e "\n${CYAN}Tentando recuperar credenciais existentes...${NC}"
    JWT_SECRET=$(grep -r "string" /etc/onlyoffice/documentserver/*.json 2>/dev/null | grep -oP ':\s*"\K[^"]+' | head -1)
    POSTGRES_PASS=$(grep -r "dbPass" /etc/onlyoffice/documentserver/*.json 2>/dev/null | grep -oP ':\s*"\K[^"]+' | head -1)

    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(generate_password)
        echo -e "${YELLOW}⚠ JWT_SECRET não encontrado em configs, gerando novo.${NC}"
    else
        echo -e "${GREEN}✓ JWT_SECRET recuperado${NC}"
    fi

    if [ -z "$POSTGRES_PASS" ]; then
        echo -e "${RED}✗ Senha PostgreSQL não encontrada em configs! Por favor, insira manualmente.${NC}"
        read -sp "Digite a senha do PostgreSQL: " POSTGRES_PASS
        echo
        if [ -z "$POSTGRES_PASS" ]; then
            echo -e "${RED}✗ Senha PostgreSQL não pode ser vazia. Saindo.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Senha PostgreSQL recuperada${NC}"
    fi

    echo -e "\n${YELLOW}Configurações Coletadas:${NC}"
    echo -e "  OnlyOffice IP: ${CYAN}${ONLYOFFICE_IP}${NC}"
    echo -e "  RabbitMQ Host: ${CYAN}${RABBITMQ_HOST}:${RABBITMQ_PORT}${NC}"
    echo -e "  RabbitMQ User: ${CYAN}${RABBITMQ_USER}${NC}"
    echo -e "  RabbitMQ VHost: ${CYAN}${RABBITMQ_VHOST}${NC}"
    echo -e "  PostgreSQL Pass: ${CYAN}********${NC}"
    echo -e "  JWT Secret: ${CYAN}${JWT_SECRET:0:10}...${NC}\n"

    if ! ask_yes_no "As informações acima estão corretas?"; then
        echo -e "${YELLOW}Por favor, execute o script novamente com as informações corretas.${NC}"
        exit 0
    fi
}

# Função para fazer backup
do_backup() {
    echo -e "\n${CYAN}Fazendo backup completo das configurações...${NC}"
    BACKUP_DIR="/root/onlyoffice_troubleshoot_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r /etc/onlyoffice "$BACKUP_DIR/etc_onlyoffice" 2>/dev/null || true
    cp -r /var/www/onlyoffice/documentserver "$BACKUP_DIR/www_onlyoffice" 2>/dev/null || true
    echo -e "${GREEN}✓ Backup salvo em: $BACKUP_DIR${NC}"
}

# Função para parar serviços
stop_services() {
    echo -e "${CYAN}Parando TODOS os serviços OnlyOffice...${NC}"
    systemctl stop supervisor 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    pkill -9 -f "node.*documentserver" 2>/dev/null || true
    pkill -9 -f "docservice" 2>/dev/null || true
    pkill -9 -f "converter" 2>/dev/null || true
    sleep 5
    echo -e "${GREEN}✓ Serviços parados${NC}"
}

# Função para reiniciar serviços
restart_services() {
    echo -e "\n${CYAN}Recarregando e reiniciando serviços...${NC}"
    systemctl daemon-reload
    systemctl start postgresql
    sleep 3
    systemctl start supervisor
    sleep 10
    supervisorctl reread # Força o supervisor a reler suas configurações
    supervisorctl update # Aplica as mudanças
    supervisorctl restart all # Reinicia todos os processos gerenciados
    sleep 20
    systemctl start nginx
    echo -e "${GREEN}✓ Serviços reiniciados${NC}"
}

# Função para verificação final
final_verification() {
    echo -e "\n${YELLOW}═══ Verificação Final Pós-Correção ═══${NC}\n"

    echo -e "${CYAN}Status dos processos do Supervisor:${NC}"
    supervisorctl status

    echo -e "\n${CYAN}Últimas 30 linhas do log do DocService:${NC}"
    tail -30 /var/log/onlyoffice/documentserver/docservice/out.log || echo -e "${YELLOW}Log não encontrado ou vazio.${NC}"

    echo -e "\n${CYAN}Verificando se ainda tenta conectar em 127.0.0.1:${NC}"
    if tail -50 /var/log/onlyoffice/documentserver/docservice/out.log | grep -q "127.0.0.1:5672"; then
        echo -e "${RED}✗ ERRO CRÍTICO: AINDA tentando 127.0.0.1! Isso é extremamente inesperado.${NC}"
        echo -e "${YELLOW}Linhas problemáticas:${NC}"
        tail -50 /var/log/onlyoffice/documentserver/docservice/out.log | grep "127.0.0.1:5672"
    else
        echo -e "${GREEN}✓ Não há mais tentativas de conexão em 127.0.0.1!${NC}"
    fi

    echo -e "\n${CYAN}Verificando conexões com ${RABBITMQ_HOST}:${NC}"
    if tail -50 /var/log/onlyoffice/documentserver/docservice/out.log | grep -q "${RABBITMQ_HOST}"; then
        echo -e "${GREEN}✓ Encontradas tentativas de conexão em ${RABBITMQ_HOST}!${NC}"
        tail -50 /var/log/onlyoffice/documentserver/docservice/out.log | grep "${RABBITMQ_HOST}"
    else
        echo -e "${YELLOW}⚠ Nenhuma menção a ${RABBITMQ_HOST} nos logs. Isso pode indicar que o serviço não está tentando conectar ou está falhando silenciosamente.${NC}"
    fi

    echo -e "\n${CYAN}Healthcheck do OnlyOffice:${NC}"
    HEALTH=$(curl -s http://${ONLYOFFICE_IP}/healthcheck 2>/dev/null)
    if [ "$HEALTH" == "true" ]; then
        echo -e "${GREEN}✓✓✓ SUCESSO! OnlyOffice está funcionando! ✓✓✓${NC}"
        echo -e "\n${GREEN}Acesse: http://${ONLYOFFICE_IP}/welcome/${NC}"
    else
        echo -e "${RED}✗ Healthcheck falhou: $HEALTH${NC}"
        echo -e "${YELLOW}Pode ser necessário aguardar mais um pouco ou verificar os logs novamente.${NC}"
    fi

    echo -e "\n${CYAN}Configuração RabbitMQ no local.json:${NC}"
    cat /etc/onlyoffice/documentserver/local.json 2>/dev/null | grep -A 8 "rabbitmq" || echo -e "${YELLOW}Arquivo local.json não encontrado ou vazio.${NC}"

    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Processo de Troubleshooting Concluído         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}Backup completo salvo em:${NC} $BACKUP_DIR"
    echo -e "${CYAN}Monitore os logs para mais detalhes:${NC} sudo tail -f /var/log/onlyoffice/documentserver/docservice/out.log"
    echo -e "${CYAN}Verifique o status dos serviços:${NC} sudo supervisorctl status"

    echo -e "\n${YELLOW}Se o problema persistir, a REINSTALAÇÃO COMPLETA do OnlyOffice é a próxima etapa recomendada.${NC}"
    echo -e "${YELLOW}Considere também a alternativa do Collabora Online via Docker.${NC}\n"
}

# ============================================================================
# OPÇÕES DE CORREÇÃO
# ============================================================================

# Opção 1: Diagnóstico Completo
run_full_diagnosis() {
    echo -e "\n${YELLOW}═══ Executando Diagnóstico Completo ═══${NC}\n"

    echo -e "${CYAN}→ Status dos serviços OnlyOffice (Supervisor):${NC}"
    if command -v supervisorctl &> /dev/null; then
        sudo supervisorctl status || echo -e "${YELLOW}Supervisor pode não estar totalmente inicializado ou configurado.${NC}"
    else
        echo -e "${YELLOW}Supervisor não encontrado. Pode ser necessário instalá-lo.${NC}"
    fi

    echo -e "\n${CYAN}→ Status do Nginx:${NC}"
    sudo systemctl status nginx --no-pager | grep Active || echo -e "${RED}✗ Nginx não está ativo!${NC}"

    echo -e "\n${CYAN}→ Status do PostgreSQL:${NC}"
    sudo systemctl status postgresql --no-pager | grep Active || echo -e "${RED}✗ PostgreSQL não está ativo!${NC}"

    echo -e "\n${CYAN}→ Teste de conexão com RabbitMQ (${RABBITMQ_HOST}:${RABBITMQ_PORT}):${NC}"
    if nc -zv "$RABBITMQ_HOST" "$RABBITMQ_PORT" 2>&1 | grep -q succeeded; then
        echo -e "${GREEN}✓ Conexão com RabbitMQ OK${NC}"
    else
        echo -e "${RED}✗ ERRO: Não foi possível conectar ao RabbitMQ!${NC}"
        echo -e "${YELLOW}Verifique o IP, porta, firewall e se o RabbitMQ está rodando no servidor remoto.${NC}"
    fi

    echo -e "\n${CYAN}→ Teste de conexão com PostgreSQL (local):${NC}"
    if sudo -u postgres psql -d onlyoffice -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Conexão com PostgreSQL OK${NC}"
    else
        echo -e "${RED}✗ ERRO: Não foi possível conectar ao PostgreSQL local!${NC}"
        echo -e "${YELLOW}Verifique se o PostgreSQL está rodando e se o banco 'onlyoffice' e o usuário 'onlyoffice' existem.${NC}"
    fi

    echo -e "\n${CYAN}→ Últimas 30 linhas do log do DocService:${NC}"
    sudo tail -30 /var/log/onlyoffice/documentserver/docservice/out.log || echo -e "${YELLOW}Log não encontrado ou vazio.${NC}"

    echo -e "\n${CYAN}→ Healthcheck do OnlyOffice (http://${ONLYOFFICE_IP}/healthcheck):${NC}"
    HEALTH=$(curl -s http://${ONLYOFFICE_IP}/healthcheck 2>/dev/null)
    if [ "$HEALTH" == "true" ]; then
        echo -e "${GREEN}✓ Healthcheck OK: $HEALTH${NC}"
    else
        echo -e "${YELLOW}⚠ Healthcheck: $HEALTH${NC}"
        echo -e "${YELLOW}Isso pode indicar que os serviços do OnlyOffice não estão totalmente funcionais.${NC}"
    fi

    echo -e "\n${CYAN}→ Procurando por '127.0.0.1' ou 'localhost' nos logs do DocService:${NC}"
    if sudo tail -100 /var/log/onlyoffice/documentserver/docservice/out.log | grep -q "127.0.0.1:5672\|localhost:5672"; then
        echo -e "${RED}✗ Conexões indesejadas a 127.0.0.1/localhost encontradas nos logs!${NC}"
        sudo tail -100 /var/log/onlyoffice/documentserver/docservice/out.log | grep "127.0.0.1:5672\|localhost:5672"
    else
        echo -e "${GREEN}✓ Nenhuma conexão a 127.0.0.1/localhost encontrada nos logs recentes.${NC}"
    fi

    echo -e "\n${CYAN}→ Verificando arquivos de configuração JSON para RabbitMQ:${NC}"
    find /etc/onlyoffice/documentserver -name "*.json" -exec sh -c 'echo "--- {} ---"; cat {} | grep -A 8 "rabbitmq"' \; 2>/dev/null || echo -e "${YELLOW}Nenhum arquivo JSON de configuração encontrado.${NC}"

    echo -e "\n${CYAN}→ Verificando variáveis de ambiente do Supervisor:${NC}"
    for conf in /etc/supervisor/conf.d/ds-*.conf; do
        if [ -f "$conf" ]; then
            echo "--- $conf ---"
            grep "environment=" "$conf" || echo "  Nenhuma variável de ambiente definida."
        fi
    done
    echo -e "\n${GREEN}Diagnóstico completo concluído.${NC}"
}

# Opção 2: Corrigir Conexão RabbitMQ (127.0.0.1)
fix_rabbitmq_connection() {
    echo -e "\n${YELLOW}═══ Corrigindo Conexão RabbitMQ (127.0.0.1) ═══${NC}\n"
    stop_services
    do_backup

    echo -e "\n${CYAN}[1/5] Patching de código JavaScript (removendo 127.0.0.1/localhost da lista de IPs locais)...${NC}"
    JS_FILE="/var/www/onlyoffice/documentserver/server/AdminPanel/client/build/ai/scripts/engine/storage.js"
    if [ -f "$JS_FILE" ]; then
        cp "$JS_FILE" "${JS_FILE}.bak"
        sed -i "s/\"localhost\",\"127.0.0.1\"/\"\"/g" "$JS_FILE"
        echo -e "${GREEN}✓ Arquivo ${JS_FILE} corrigido${NC}"
    else
        echo -e "${YELLOW}⚠ Arquivo ${JS_FILE} não encontrado. O patch pode não ser necessário ou o caminho mudou.${NC}"
    fi

    echo -e "\n${CYAN}[2/5] Recriando arquivos de configuração JSON (local.json e default.json)...${NC}"
    rm -f /etc/onlyoffice/documentserver/*.json
    rm -f /etc/onlyoffice/documentserver/*.json.bak
    cat > /etc/onlyoffice/documentserver/local.json <<EOF
{
  "services": {
    "CoAuthoring": {
      "sql": {
        "type": "postgres",
        "dbHost": "localhost",
        "dbPort": "5432",
        "dbName": "onlyoffice",
        "dbUser": "onlyoffice",
        "dbPass": "${POSTGRES_PASS}"
      },
      "secret": {
        "inbox": {"string": "${JWT_SECRET}"},
        "outbox": {"string": "${JWT_SECRET}"},
        "session": {"string": "${JWT_SECRET}"}
      },
      "token": {
        "enable": {
          "request": {"inbox": true, "outbox": true},
          "browser": true
        }
      }
    }
  },
  "rabbitmq": {
    "url": "amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}",
    "host": "${RABBITMQ_HOST}",
    "port": ${RABBITMQ_PORT},
    "login": "${RABBITMQ_USER}",
    "password": "${RABBITMQ_PASS}",
    "vhost": "${RABBITMQ_VHOST}"
  },
  "storage": {
    "fs": {"secretString": "${JWT_SECRET}"}
  }
}
EOF
    cat > /etc/onlyoffice/documentserver/default.json <<EOF
{
  "rabbitmq": {
    "url": "amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}",
    "host": "${RABBITMQ_HOST}",
    "port": ${RABBITMQ_PORT},
    "login": "${RABBITMQ_USER}",
    "password": "${RABBITMQ_PASS}",
    "vhost": "${RABBITMQ_VHOST}"
  }
}
EOF
    chown ds:ds /etc/onlyoffice/documentserver/*.json 2>/dev/null || true
    chmod 600 /etc/onlyoffice/documentserver/*.json
    echo -e "${GREEN}✓ Arquivos de configuração JSON criados/atualizados${NC}"

    echo -e "\n${CYAN}[3/5] Configurando variáveis de ambiente GLOBAIS para Supervisor e Systemd...${NC}"
    mkdir -p /etc/systemd/system/supervisor.service.d
    cat > /etc/systemd/system/supervisor.service.d/rabbitmq.conf <<EOF
[Service]
Environment="DS_RABBITMQ_HOST=${RABBITMQ_HOST}"
Environment="DS_RABBITMQ_PORT=${RABBITMQ_PORT}"
Environment="DS_RABBITMQ_USER=${RABBITMQ_USER}"
Environment="DS_RABBITMQ_PWD=${RABBITMQ_PASS}"
Environment="DS_RABBITMQ_VHOST=${RABBITMQ_VHOST}"
EOF
    if ! grep -q "DS_RABBITMQ_HOST" /etc/environment; then
        cat >> /etc/environment <<EOF
DS_RABBITMQ_HOST="${RABBITMQ_HOST}"
DS_RABBITMQ_PORT="${RABBITMQ_PORT}"
DS_RABBITMQ_USER="${RABBITMQ_USER}"
DS_RABBITMQ_PWD="${RABBITMQ_PASS}"
DS_RABBITMQ_VHOST="${RABBITMQ_VHOST}"
EOF
    fi
    export DS_RABBITMQ_HOST="${RABBITMQ_HOST}"
    export DS_RABBITMQ_PORT="${RABBITMQ_PORT}"
    export DS_RABBITMQ_USER="${RABBITMQ_USER}"
    export DS_RABBITMQ_PWD="${RABBITMQ_PASS}"
    export DS_RABBITMQ_VHOST="${RABBITMQ_VHOST}"
    echo -e "${GREEN}✓ Variáveis de ambiente configuradas${NC}"

    echo -e "\n${CYAN}[4/5] Atualizando configurações dos programas do Supervisor...${NC}"
    for conf in /etc/supervisor/conf.d/ds-*.conf; do
        if [ -f "$conf" ]; then
            sed -i '/^environment=/d' "$conf"
            sed -i "/|$program:/a environment=DS_RABBITMQ_HOST=\"${RABBITMQ_HOST}\",DS_RABBITMQ_PORT=\"${RABBITMQ_PORT}\",DS_RABBITMQ_USER=\"${RABBITMQ_USER}\",DS_RABBITMQ_PWD=\"${RABBITMQ_PASS}\",DS_RABBITMQ_VHOST=\"${RABBITMQ_VHOST}\"" "$conf"
            echo -e "  ${GREEN}✓${NC} Supervisor config: $conf atualizado"
        fi
    done
    echo -e "${GREEN}✓ Configurações do Supervisor atualizadas${NC}"

    echo -e "\n${CYAN}[5/5] Reiniciando serviços e aguardando...${NC}"
    restart_services
    sleep 40 # Espera extra para inicialização completa
    echo -e "${GREEN}Correção de conexão RabbitMQ concluída.${NC}"
}

# Opção 3: Corrigir Problemas de PostgreSQL
fix_postgresql_issues() {
    echo -e "\n${YELLOW}═══ Corrigindo Problemas de PostgreSQL ═══${NC}\n"
    stop_services
    do_backup

    echo -e "\n${CYAN}[1/3] Verificando e reiniciando PostgreSQL...${NC}"
    sudo systemctl start postgresql
    sleep 10
    if sudo systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}✓ PostgreSQL está rodando.${NC}"
    else
        echo -e "${RED}✗ ERRO: PostgreSQL não está rodando! Verifique os logs do PostgreSQL.${NC}"
        exit 1
    fi

    echo -e "\n${CYAN}[2/3] Verificando e corrigindo banco de dados e usuário 'onlyoffice'...${NC}"
    # Tentar criar banco e usuário se não existirem
    sudo -u postgres psql -c "CREATE DATABASE onlyoffice;" 2>/dev/null && echo -e "${GREEN}✓ Database 'onlyoffice' criado.${NC}" || echo -e "${YELLOW}⊘ Database 'onlyoffice' já existe.${NC}"
    sudo -u postgres psql -c "CREATE USER onlyoffice WITH PASSWORD '${POSTGRES_PASS}';" 2>/dev/null && echo -e "${GREEN}✓ Usuário 'onlyoffice' criado.${NC}" || echo -e "${YELLOW}⊘ Usuário 'onlyoffice' já existe.${NC}"

    # Garantir permissões
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE onlyoffice TO onlyoffice;" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER DATABASE onlyoffice OWNER TO onlyoffice;" 2>/dev/null || true
    sudo -u postgres psql -d onlyoffice -c "GRANT ALL ON SCHEMA public TO onlyoffice;" 2>/dev/null || true
    sudo -u postgres psql -d onlyoffice -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO onlyoffice;" 2>/dev/null || true
    sudo -u postgres psql -d onlyoffice -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO onlyoffice;" 2>/dev/null || true
    echo -e "${GREEN}✓ Banco de dados e usuário 'onlyoffice' verificados/corrigidos.${NC}"

    echo -e "\n${CYAN}[3/3] Aplicando schema do banco de dados...${NC}"
    if [ -f "/var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql" ]; then
        sudo -u postgres psql -d onlyoffice -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql 2>/dev/null && echo -e "${GREEN}✓ Schema aplicado.${NC}" || echo -e "${YELLOW}⊘ Schema já aplicado ou erro ao aplicar.${NC}"
    else
        echo -e "${YELLOW}⚠ Arquivo de schema não encontrado. Pode ser normal em algumas versões.${NC}"
    fi
    echo -e "${GREEN}Correção de PostgreSQL concluída.${NC}"
    restart_services
    sleep 40
}

# Opção 4: Reinstalar Supervisor
reinstall_supervisor() {
    echo -e "\n${YELLOW}═══ Reinstalando Supervisor ═══${NC}\n"
    stop_services
    do_backup

    echo -e "${CYAN}[1/3] Removendo Supervisor existente...${NC}"
    apt purge -y supervisor 2>/dev/null || true
    rm -rf /etc/supervisor /var/log/supervisor 2>/dev/null || true
    echo -e "${GREEN}✓ Supervisor removido.${NC}"

    echo -e "\n${CYAN}[2/3] Instalando Supervisor...${NC}"
    apt update
    apt install -y supervisor
    systemctl enable supervisor
    systemctl start supervisor
    sleep 5
    echo -e "${GREEN}✓ Supervisor instalado e iniciado.${NC}"

    echo -e "\n${CYAN}[3/3] Recarregando configurações do Supervisor e reiniciando serviços...${NC}"
    # Reaplicar variáveis de ambiente no supervisor configs
    for conf in /etc/supervisor/conf.d/ds-*.conf; do
        if [ -f "$conf" ]; then
            sed -i '/^environment=/d' "$conf"
            sed -i "/|$program:/a environment=DS_RABBITMQ_HOST=\"${RABBITMQ_HOST}\",DS_RABBITMQ_PORT=\"${RABBITMQ_PORT}\",DS_RABBITMQ_USER=\"${RABBITMQ_USER}\",DS_RABBITMQ_PWD=\"${RABBITMQ_PASS}\",DS_RABBITMQ_VHOST=\"${RABBITMQ_VHOST}\"" "$conf"
        fi
    done
    systemctl daemon-reload
    systemctl start postgresql
    sleep 3
    systemctl start supervisor
    sleep 10
    supervisorctl reread
    supervisorctl update
    supervisorctl restart all
    sleep 20
    systemctl start nginx
    echo -e "${GREEN}Reinstalação do Supervisor concluída.${NC}"
    sleep 40
}

# Opção 5: Limpeza Completa e Reinstalação (Recomendado como último recurso)
full_cleanup_and_reinstall() {
    echo -e "\n${RED}═══ Limpeza Completa e Reinstalação do OnlyOffice ═══${NC}\n"
    echo -e "${YELLOW}Esta opção irá remover COMPLETAMENTE o OnlyOffice Document Server e suas dependências.${NC}"
    echo -e "${YELLOW}Você precisará executar o script de instalação original novamente após esta limpeza.${NC}\n"
    if ! ask_yes_no "Tem certeza que deseja continuar com a limpeza completa e reinstalação?"; then
        echo -e "${YELLOW}Operação cancelada.${NC}"
        return
    fi

    echo -e "${CYAN}[1/5] Parando todos os serviços OnlyOffice...${NC}"
    systemctl stop supervisor 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    pkill -9 -f "node.*documentserver" 2>/dev/null || true
    pkill -9 -f "docservice" 2>/dev/null || true
    pkill -9 -f "converter" 2>/dev/null || true
    sleep 5
    echo -e "${GREEN}✓ Serviços parados.${NC}"

    echo -e "\n${CYAN}[2/5] Removendo pacotes OnlyOffice e dependências...${NC}"
    apt purge -y onlyoffice-documentserver 2>/dev/null || true
    apt autoremove -y
    echo -e "${GREEN}✓ Pacotes OnlyOffice removidos.${NC}"

    echo -e "\n${CYAN}[3/5] Removendo arquivos de configuração e dados...${NC}"
    rm -rf /etc/onlyoffice /var/www/onlyoffice /var/log/onlyoffice /var/lib/onlyoffice 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/onlyoffice.list 2>/dev/null || true
    rm -f /usr/share/keyrings/onlyoffice.gpg 2>/dev/null || true
    rm -f /etc/systemd/system/supervisor.service.d/rabbitmq.conf 2>/dev/null || true
    sed -i '/DS_RABBITMQ_HOST/d' /etc/environment 2>/dev/null || true
    echo -e "${GREEN}✓ Arquivos de configuração e dados removidos.${NC}"

    echo -e "\n${CYAN}[4/5] Removendo banco de dados e usuário PostgreSQL 'onlyoffice'...${NC}"
    if sudo systemctl is-active --quiet postgresql; then
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS onlyoffice;" 2>/dev/null && echo -e "${GREEN}✓ Database 'onlyoffice' removido.${NC}" || echo -e "${YELLOW}⊘ Database 'onlyoffice' não existe ou já removido.${NC}"
        sudo -u postgres psql -c "DROP USER IF EXISTS onlyoffice;" 2>/dev/null && echo -e "${GREEN}✓ Usuário 'onlyoffice' removido.${NC}" || echo -e "${YELLOW}⊘ Usuário 'onlyoffice' não existe ou já removido.${NC}"
    else
        echo -e "${YELLOW}⚠ PostgreSQL não está rodando, não foi possível remover banco/usuário.${NC}"
    fi
    echo -e "${GREEN}✓ Banco de dados e usuário PostgreSQL limpos.${NC}"

    echo -e "\n${CYAN}[5/5] Reiniciando Nginx e Supervisor (se existirem)...${NC}"
    systemctl restart nginx 2>/dev/null || true
    systemctl restart supervisor 2>/dev/null || true
    echo -e "${GREEN}✓ Nginx e Supervisor reiniciados.${NC}"

    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Limpeza Completa Concluída!                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "${YELLOW}Agora você pode executar o script de instalação original do OnlyOffice novamente.${NC}\n"
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

main_menu() {
    while true; do
        echo -e "\n${BLUE}═══ Menu Principal de Troubleshooting ═══${NC}"
        echo -e "1. ${CYAN}Diagnóstico Completo${NC} (Verifica status, logs e configurações)"
        echo -e "2. ${CYAN}Corrigir Conexão RabbitMQ (127.0.0.1)${NC} (Tenta forçar o IP externo)"
        echo -e "3. ${CYAN}Corrigir Problemas de PostgreSQL${NC} (Verifica e corrige banco/usuário/permissões)"
        echo -e "4. ${CYAN}Reinstalar Supervisor${NC} (Pode resolver problemas de gerenciamento de serviços)"
        echo -e "5. ${RED}Limpeza Completa e Reinstalação do OnlyOffice${NC} (Último recurso)"
        echo -e "0. ${YELLOW}Sair${NC}"
        read -p "Escolha uma opção: " choice

        case $choice in
            1) run_full_diagnosis ;;
            2) fix_rabbitmq_connection ;;
            3) fix_postgresql_issues ;;
            4) reinstall_supervisor ;;
            5) full_cleanup_and_reinstall ;;
            0) echo -e "${YELLOW}Saindo do kit de ferramentas. Boa sorte!${NC}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida. Por favor, tente novamente.${NC}" ;;
        esac

        if [ "$choice" -ne 0 ]; then
            if ask_yes_no "\nDeseja retornar ao menu principal?"; then
                continue
            else
                echo -e "${YELLOW}Saindo do kit de ferramentas. Boa sorte!${NC}"; exit 0
            fi
        fi
    done
}

# ============================================================================
# INÍCIO DA EXECUÇÃO
# ============================================================================

print_header
collect_info # Coleta as informações essenciais no início
main_menu
