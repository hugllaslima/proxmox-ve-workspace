#!/bin/bash

#==============================================================================
# Script: install_pg.sh
# Descrição: Instalação e configuração do PostgreSQL 16 com TimescaleDB
# Autor: Hugllas Lima
# Data: 10/09/2026
# Versão: 1.3 (Cores por função e sem emojis para compatibilidade com nano)
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
if [ "$EUID" -ne 0 ]; then
    log_error "Este script deve ser executado como root ou com sudo!"
    echo "Exemplo: sudo ./install_pg.sh"
    exit 1
fi

echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}${BOLD} Instalador: PostgreSQL 16 + TimescaleDB (Ubuntu) ${NC}"
echo -e "${CYAN}==================================================${NC}"

log_step "[1/8] Atualizando pacotes do sistema..."
apt update && apt upgrade -y
apt install -y gnupg postgresql-common apt-transport-https lsb-release wget

log_step "[2/8] Adicionando repositório do PostgreSQL..."
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

log_step "[3/8] Adicionando repositório do TimescaleDB..."
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list

log_step "[4/8] Instalando PostgreSQL 16 e TimescaleDB..."
apt update
apt install -y postgresql-16 timescaledb-2-postgresql-16

log_step "[5/8] Definindo senha do usuário 'postgres'..."
read -s -p "Digite a SENHA para o usuário 'postgres': " PG_PASSWORD
echo ""
read -s -p "Confirme a SENHA: " PG_PASSWORD_CONFIRM
echo ""

if [ "$PG_PASSWORD" != "$PG_PASSWORD_CONFIRM" ]; then
    log_error "As senhas não conferem!"
    exit 1
fi

# Define a senha do usuário postgres
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';"
log_success "Senha do usuário 'postgres' definida com sucesso."

log_step "[6/8] Configurando acessos de rede..."
read -p "Deseja liberar acesso externo (ex: pgAdmin) para este servidor? (s/n): " ALLOW_EXT

if [ "$ALLOW_EXT" = "s" ] || [ "$ALLOW_EXT" = "S" ]; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf

    echo ""
    log_info "Configurando redes autorizadas para acesso..."
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  - 0.0.0.0/0 (Qualquer IP - Use com cuidado!)"
    echo "  - 10.10.0.0/16 (Rede 10.10.x.x)"
    echo "  - 192.168.1.0/24 (Rede 192.168.1.x)"
    echo "  - 10.10.1.160/32 (IP específico)"
    echo ""

    # Array para armazenar as redes
    declare -a NETWORKS
    NETWORK_COUNT=0

    while true; do
        read -p "Digite a rede/IP que deseja liberar (ou 'pronto' para finalizar): " NETWORK_INPUT

        if [ "$NETWORK_INPUT" = "pronto" ] || [ "$NETWORK_INPUT" = "PRONTO" ]; then
            if [ $NETWORK_COUNT -eq 0 ]; then
                log_error "Você precisa adicionar pelo menos uma rede!"
                continue
            fi
            break
        fi

        # Validação básica de CIDR
        if [[ $NETWORK_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
            NETWORKS+=("$NETWORK_INPUT")
            ((NETWORK_COUNT++))
            log_success "Rede adicionada: $NETWORK_INPUT"
        else
            log_error "Formato inválido! Use o formato CIDR (ex: 10.10.0.0/16 ou 10.10.1.160/32)"
        fi
    done

    # Adiciona as redes ao pg_hba.conf
    echo ""
    log_info "Adicionando redes ao pg_hba.conf..."
    for NETWORK in "${NETWORKS[@]}"; do
        echo "host    all             all             $NETWORK               scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf
        log_success "Rede liberada: $NETWORK"
    done

    log_success "Acesso externo LIBERADO para ${NETWORK_COUNT} rede(s)."
else
    log_warning "Acesso externo BLOQUEADO (Apenas localhost)."
fi

log_step "[7/8] Otimizando o banco de dados com timescaledb-tune..."
timescaledb-tune --quiet --yes

log_step "[8/8] Reiniciando serviço PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}${BOLD} [OK] Instalação concluída com sucesso! ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}Informações de Acesso:${NC}"
echo -e "   ${BOLD}Usuário:${NC}       ${GREEN}postgres${NC}"
echo -e "   ${BOLD}Porta:${NC}         ${YELLOW}5432${NC}"
echo -e "   ${BOLD}Acesso Local:${NC}  ${BLUE}psql -U postgres${NC}"
echo -e "   ${BOLD}Acesso Remoto:${NC} ${BLUE}psql -h <IP_DO_SERVIDOR> -U postgres${NC}"
echo ""