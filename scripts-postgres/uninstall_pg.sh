#!/bin/bash

#==============================================================================
# Script: uninstall_pg.sh
# Descrição: Desinstalação completa e remoção do PostgreSQL e TimescaleDB
# Autor: Hugllas Lima
# Data: 22/09/2026
# Versão: 1.1 (Cores por função e sem emojis para compatibilidade com nano)
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

# Interrompe o script se houver erro crítico não tratado
set -e

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
    echo "Exemplo: sudo ./uninstall_pg.sh"
    exit 1
fi

echo -e "${RED}================================================================${NC}"
echo -e "${RED}${BOLD} [AVISO CRÍTICO] DESINSTALADOR DO POSTGRESQL & TIMESCALEDB      ${NC}"
echo -e "${RED}================================================================${NC}"
log_warning "Este script irá parar os serviços, desinstalar os pacotes e remover"
log_warning "definitivamente todas as bases de dados e configurações do servidor!"
log_info "Ambiente detectado: $(hostname) (Kernel: $(uname -r))"
echo ""

# Confirmação de segurança explícita
read -p "Tem certeza absoluta que deseja continuar? Digite 'CONFIRMAR' para prosseguir: " CONFIRMACAO

if [ "$CONFIRMACAO" != "CONFIRMAR" ]; then
    log_info "Operação cancelada pelo usuário. Nenhuma alteração foi realizada."
    exit 0
fi

log_step "[ETAPA 1/7] Verificação de Backup Prévio"

# Oferece a oportunidade de gerar um dump se o PostgreSQL estiver ativo
if systemctl is-active --quiet postgresql 2>/dev/null || pgrep -x "postgres" > /dev/null; then
    read -p "Deseja realizar um backup de segurança (pg_dumpall) antes da remoção? (s/n): " DO_BACKUP
    if [ "$DO_BACKUP" = "s" ] || [ "$DO_BACKUP" = "S" ]; then
        BACKUP_DIR="/root/backups_postgres"
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/backup_all_$(date +%Y%m%d_%H%M%S).sql.gz"
        
        log_info "Gerando dump de todos os bancos de dados em $BACKUP_FILE..."
        if sudo -u postgres pg_dumpall | gzip > "$BACKUP_FILE"; then
            log_success "Backup concluído com sucesso: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
        else
            log_error "Falha ao criar backup! Verifique antes de continuar."
            read -p "Deseja continuar mesmo sem o backup bem-sucedido? (s/n): " PROCEED_NO_BACKUP
            if [ "$PROCEED_NO_BACKUP" != "s" ] && [ "$PROCEED_NO_BACKUP" != "S" ]; then
                log_info "Operação abortada para segurança dos dados."
                exit 1
            fi
        fi
    else
        log_warning "Backup ignorado pelo usuário."
    fi
else
    log_warning "Serviço PostgreSQL não está em execução. Pulando etapa de backup automático."
fi

log_step "[ETAPA 2/7] Parando serviços e processos do PostgreSQL"

# Desabilita e para serviços systemd
if command -v systemctl >/dev/null 2>&1; then
    log_info "Parando e desabilitando serviço postgresql..."
    timeout 10s systemctl stop postgresql 2>/dev/null || true
    systemctl disable postgresql 2>/dev/null || true
fi

# Finaliza qualquer processo residual do postgres (comum em LXC/VMs com conexões presas)
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
    log_info "pg_dropcluster não encontrado ou nenhum cluster ativo."
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

# Remove pacotes que ficaram em estado 'rc' (residual-config) no dpkg
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

# Limpeza de sockets e locks no /tmp
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

log_info "Atualizando lista de pacotes APT"
# Executa com IPv4 forçado e timeout para evitar espera infinita em espelhos lentos
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
log_info "O servidor (VM ou Contêiner LXC) está totalmente limpo de resíduos"
log_info "do PostgreSQL e TimescaleDB."
if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
    log_warning "Lembrete: O arquivo de backup foi preservado em: $BACKUP_FILE"
fi
echo ""
