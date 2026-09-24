#!/bin/bash

#==============================================================================
# Script: destroy_db.sh
# Descrição: Assistente de exclusão segura de banco de dados e usuário no PostgreSQL
# Autor: Hugllas Lima
# Data: 22/09/2026
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
    echo "Exemplo: sudo ./destroy_db.sh"
    exit 1
fi

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}${BOLD} Assistente de Exclusão de Banco de Dados PostgreSQL${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

# Lista os bancos de dados não pertencentes ao sistema
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

# Validação do nome informado
if [ -z "$TARGET_DB" ]; then
    log_error "O nome do banco de dados não pode ficar vazio!"
    exit 1
fi

# Proteção de bancos do sistema
if [ "$TARGET_DB" = "postgres" ] || [ "$TARGET_DB" = "template0" ] || [ "$TARGET_DB" = "template1" ]; then
    log_error "Por segurança, bancos internos do sistema ('$TARGET_DB') não podem ser removidos!"
    exit 1
fi

# Verifica se o banco de dados realmente existe
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$TARGET_DB';")
if [ "$DB_EXISTS" != "1" ]; then
    log_error "O banco de dados '$TARGET_DB' não foi encontrado no servidor!"
    exit 1
fi

# Descobre o proprietário (owner) atual do banco de dados
DB_OWNER=$(sudo -u postgres psql -tAc "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='$TARGET_DB';")

echo ""
log_warning "Atenção: Todos os dados, tabelas e registros contidos em '${TARGET_DB}' serão PERDIDOS!"

# Opção de backup preventivo antes de dropar
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
            exit 1
        fi
    fi
fi

# Confirmação explícita
echo ""
read -p "Para confirmar a EXCLUSÃO PERMANENTE, digite exatamente '$TARGET_DB': " CONFIRM_NAME

if [ "$CONFIRM_NAME" != "$TARGET_DB" ]; then
    log_info "Confirmação incorreta. Operação cancelada. Nenhuma exclusão foi realizada."
    exit 0
fi

echo ""
log_info "Encerrando conexões ativas com o banco '$TARGET_DB'..."
# Encerra qualquer sessão ativa no banco para não bloquear o DROP
sudo -u postgres psql -c "
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname = '$TARGET_DB' AND pid <> pg_backend_pid();
" >/dev/null 2>&1 || true

log_info "Excluindo banco de dados '$TARGET_DB'..."
# Tenta dropar com FORCE (suportado no PG 13+) ou DROP DATABASE comum
if sudo -u postgres psql -c "DROP DATABASE \"$TARGET_DB\" WITH (FORCE);" 2>/dev/null; then
    log_success "Banco de dados '$TARGET_DB' excluído com sucesso!"
elif sudo -u postgres psql -c "DROP DATABASE \"$TARGET_DB\";"; then
    log_success "Banco de dados '$TARGET_DB' excluído com sucesso!"
else
    log_error "Falha ao tentar excluir o banco de dados '$TARGET_DB'."
    exit 1
fi

# Pergunta se também deseja remover o usuário associado (se não for postgres)
if [ -n "$DB_OWNER" ] && [ "$DB_OWNER" != "postgres" ]; then
    echo ""
    read -p "O banco pertencia ao usuário '$DB_OWNER'. Deseja EXCLUIR também este usuário? (s/n): " DROP_USER
    if [ "$DROP_USER" = "s" ] || [ "$DROP_USER" = "S" ]; then
        # Verifica se o usuário é dono de outros bancos
        OTHER_DBS=$(sudo -u postgres psql -tAc "SELECT datname FROM pg_database WHERE pg_catalog.pg_get_userbyid(datdba) = '$DB_OWNER' AND datname != '$TARGET_DB';")
        if [ -n "$OTHER_DBS" ]; then
            log_warning "O usuário '$DB_OWNER' ainda é proprietário de outro(s) banco(s): $(echo $OTHER_DBS | tr '\n' ' ')"
            log_warning "O usuário '$DB_OWNER' NÃO foi excluído para evitar quebras em outros serviços."
        else
            log_info "Excluindo o usuário '$DB_OWNER'..."
            if sudo -u postgres psql -c "DROP USER \"$DB_OWNER\";"; then
                log_success "Usuário '$DB_OWNER' excluído com sucesso!"
            else
                log_error "Não foi possível excluir o usuário '$DB_OWNER'. Pode haver outros privilégios ou objetos vinculados."
            fi
        fi
    fi
fi

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}${BOLD} [OK] Operação finalizada com sucesso!              ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo ""
