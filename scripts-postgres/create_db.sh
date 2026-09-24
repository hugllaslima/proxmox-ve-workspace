#!/bin/bash

#==============================================================================
# Script: create_db.sh
# Descrição: Assistente de criação de banco de dados, usuário e extensão TimescaleDB
# Autor: Hugllas Lima
# Data: 10/09/2026
# Versão: 1.1 (Cores por função e sem emojis para compatibilidade com nano)
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

# Verificação de privilégios de execução
if [ "$EUID" -ne 0 ] && [ "$(whoami)" != "postgres" ]; then
    log_error "Este script deve ser executado como root, com sudo ou com o usuário 'postgres'!"
    echo "Exemplo: sudo ./create_db.sh"
    exit 1
fi

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}${BOLD} Assistente de Criação de Banco de Dados e Usuário  ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

read -p "Digite o nome do NOVO BANCO DE DADOS (ex: zabbix): " DBNAME
if [ -z "$DBNAME" ]; then
    log_error "O nome do banco de dados não pode ficar vazio!"
    exit 1
fi

read -p "Digite o nome do NOVO USUÁRIO (ex: zabbix): " DBUSER
if [ -z "$DBUSER" ]; then
    log_error "O nome do usuário não pode ficar vazio!"
    exit 1
fi

read -s -p "Digite a SENHA para este usuário: " DBPASS
echo ""
read -s -p "Confirme a SENHA: " DBPASS_CONFIRM
echo ""

if [ "$DBPASS" != "$DBPASS_CONFIRM" ]; then
    log_error "As senhas não conferem!"
    exit 1
fi

if [ -z "$DBPASS" ]; then
    log_error "A senha não pode ficar vazia!"
    exit 1
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

# Captura o IP principal do servidor/container automaticamente
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="<IP_DO_SERVIDOR>"
fi

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