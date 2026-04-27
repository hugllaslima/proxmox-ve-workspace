#!/bin/bash

# -----------------------------------------------------------------------------
# Script: cleanup_onlyoffice.sh
# Descrição: Remove completamente o OnlyOffice Document Server e suas dependências.
# Autor: Hugllas Lima
# Data de Criação: 20/10/2023
# Versão: 4.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./cleanup_onlyoffice.sh
#
# Pré-requisitos:
#   - Permissões de root ou sudo.
#
# Notas Importantes:
#   - Este script é DESTRUTIVO e removerá todos os dados do OnlyOffice,
#     incluindo documentos, configurações e bancos de dados.
#   - Use com extrema cautela e apenas quando tiver certeza de que deseja
#     apagar completamente a instalação.
#   - Recomenda-se fazer um backup completo antes de executar.
#
# -----------------------------------------------------------------------------


# Desabilitar exit on error
set +e

# Proteger este script
SCRIPT_PID=$$
trap '' SIGTERM SIGINT

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Contadores
ITEMS_REMOVED=0
ITEMS_NOT_FOUND=0
ITEMS_FAILED=0

# Função para exibir cabeçalho
print_header() {
    clear
    echo -e "\n${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                            ║${NC}"
    echo -e "${RED}║        Script de Limpeza - OnlyOffice Server              ║${NC}"
    echo -e "${RED}║        Versão 4.0 - Limpeza Completa e Forçada            ║${NC}"
    echo -e "${RED}║                                                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"
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

# Função para log de ação
log_action() {
    local status=$1
    local message=$2

    case $status in
        "success")
            echo -e "${GREEN}✓${NC} $message"
            ITEMS_REMOVED=$((ITEMS_REMOVED + 1))
            ;;
        "not_found")
            echo -e "${GRAY}⊘${NC} $message"
            ITEMS_NOT_FOUND=$((ITEMS_NOT_FOUND + 1))
            ;;
        "failed")
            echo -e "${YELLOW}⚠${NC} $message"
            ITEMS_FAILED=$((ITEMS_FAILED + 1))
            ;;
        "info")
            echo -e "${CYAN}→${NC} $message"
            ;;
    esac
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser executado como root (use sudo)${NC}" 
   exit 1
fi

print_header

echo -e "${YELLOW}Este script irá remover COMPLETAMENTE:${NC}"
echo -e "  ${CYAN}•${NC} OnlyOffice Document Server (forçado)"
echo -e "  ${CYAN}•${NC} PostgreSQL e banco de dados 'onlyoffice'"
echo -e "  ${CYAN}•${NC} Nginx (configurações do OnlyOffice)"
echo -e "  ${CYAN}•${NC} Supervisor e processos relacionados"
echo -e "  ${CYAN}•${NC} Todos os arquivos e diretórios"
echo -e "  ${CYAN}•${NC} Usuários, grupos e configurações"
echo -e "  ${CYAN}•${NC} Erlang (opcional)"
echo

echo -e "${BLUE}O script verifica a existência de cada item antes de remover.${NC}"
echo -e "${BLUE}Itens não encontrados serão apenas reportados.${NC}\n"

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ATENÇÃO: Esta ação NÃO pode ser desfeita!                ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Confirmação
read -p "Digite 'LIMPAR' (em maiúsculas) para confirmar: " CONFIRM

if [ "$CONFIRM" != "LIMPAR" ]; then
    echo -e "${YELLOW}Limpeza cancelada. Nenhuma alteração foi feita.${NC}"
    exit 0
fi

echo
if ! ask_yes_no "Tem certeza absoluta que deseja continuar?"; then
    echo -e "${YELLOW}Limpeza cancelada. Nenhuma alteração foi feita.${NC}"
    exit 0
fi

echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}         Iniciando Limpeza Completa do Sistema${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"

# ============================================================================
# BACKUP OPCIONAL
# ============================================================================

BACKUP_DIR=""
if ask_yes_no "Deseja fazer backup das configurações antes de remover?"; then
    BACKUP_DIR="/root/onlyoffice_backup_$(date +%Y%m%d_%H%M%S)"
    log_action "info" "Criando backup em: ${BACKUP_DIR}"

    mkdir -p "$BACKUP_DIR" 2>/dev/null

    if [ -d "/etc/onlyoffice" ]; then
        cp -r /etc/onlyoffice "$BACKUP_DIR/" 2>/dev/null && log_action "success" "Backup de /etc/onlyoffice"
    fi

    if [ -d "/var/log/onlyoffice" ]; then
        mkdir -p "$BACKUP_DIR/logs" 2>/dev/null
        find /var/log/onlyoffice -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/logs/" \; 2>/dev/null
        log_action "success" "Backup de logs recentes"
    fi

    find /root -name "onlyoffice_config_*.txt" -exec cp {} "$BACKUP_DIR/" \; 2>/dev/null

    chmod 600 -R "$BACKUP_DIR" 2>/dev/null
    echo
fi

# ============================================================================
# ETAPA 1: PARAR SERVIÇOS
# ============================================================================

echo -e "${BLUE}[1/16] Parando serviços OnlyOffice...${NC}"

# Supervisor
if command -v supervisorctl &> /dev/null; then
    log_action "info" "Parando processos via Supervisor..."
    timeout 10 supervisorctl stop all 2>/dev/null && log_action "success" "Supervisor parado" || log_action "not_found" "Supervisor não respondeu"
    timeout 5 systemctl stop supervisor 2>/dev/null
else
    log_action "not_found" "Supervisor não instalado"
fi

# Nginx
if systemctl is-active --quiet nginx 2>/dev/null; then
    systemctl stop nginx 2>/dev/null && log_action "success" "Nginx parado" || log_action "failed" "Falha ao parar Nginx"
else
    log_action "not_found" "Nginx não está rodando"
fi

# Processos OnlyOffice
log_action "info" "Finalizando processos OnlyOffice..."
KILLED=0
for process in "documentserver" "ds-converter" "ds-docservice" "ds-metrics"; do
    PIDS=$(ps aux | grep -E "$process" | grep -v grep | awk '{print $2}')
    if [ -n "$PIDS" ]; then
        for pid in $PIDS; do
            if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
                kill -9 $pid 2>/dev/null && KILLED=$((KILLED + 1))
            fi
        done
    fi
done

if [ $KILLED -gt 0 ]; then
    log_action "success" "$KILLED processo(s) finalizado(s)"
else
    log_action "not_found" "Nenhum processo OnlyOffice em execução"
fi

sleep 2
echo

# ============================================================================
# ETAPA 2: REMOVER PACOTE ONLYOFFICE (FORÇADO)
# ============================================================================

echo -e "${BLUE}[2/16] Removendo pacote OnlyOffice...${NC}"

if dpkg -l | grep -q "onlyoffice-documentserver"; then
    log_action "info" "Pacote encontrado, removendo..."

    # Tentativa 1: Remoção normal
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y onlyoffice-documentserver 2>/dev/null

    # Tentativa 2: Forçar remoção
    if dpkg -l | grep -q "onlyoffice-documentserver"; then
        log_action "info" "Forçando remoção..."
        dpkg --remove --force-all onlyoffice-documentserver 2>/dev/null
        dpkg --purge --force-all onlyoffice-documentserver 2>/dev/null
    fi

    # Tentativa 3: Remover arquivos de controle do dpkg
    if dpkg -l | grep -q "onlyoffice-documentserver"; then
        log_action "info" "Removendo registros do dpkg..."
        rm -f /var/lib/dpkg/info/onlyoffice-documentserver.* 2>/dev/null
        dpkg --configure -a 2>/dev/null
    fi

    # Verificar resultado
    if dpkg -l | grep -q "onlyoffice-documentserver"; then
        log_action "failed" "Pacote ainda registrado (será limpo manualmente)"
    else
        log_action "success" "Pacote removido completamente"
    fi
else
    log_action "not_found" "Pacote OnlyOffice não instalado"
fi

apt-get autoremove -y 2>/dev/null
echo

# ============================================================================
# ETAPA 3: POSTGRESQL
# ============================================================================

echo -e "${BLUE}[3/16] Removendo banco de dados PostgreSQL...${NC}"

if command -v psql &> /dev/null; then
    log_action "info" "PostgreSQL encontrado"

    # Parar conexões
    sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'onlyoffice';" 2>/dev/null
    sleep 2

    # Remover banco
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw onlyoffice; then
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS onlyoffice;" 2>/dev/null && log_action "success" "Banco 'onlyoffice' removido" || log_action "failed" "Falha ao remover banco"
    else
        log_action "not_found" "Banco 'onlyoffice' não existe"
    fi

    # Remover usuário
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='onlyoffice'" | grep -q 1; then
        sudo -u postgres psql -c "DROP USER IF EXISTS onlyoffice;" 2>/dev/null && log_action "success" "Usuário 'onlyoffice' removido" || log_action "failed" "Falha ao remover usuário"
    else
        log_action "not_found" "Usuário 'onlyoffice' não existe"
    fi

    # Remover PostgreSQL completo
    if ask_yes_no "Deseja remover o PostgreSQL completamente? (Cuidado: pode afetar outros serviços)"; then
        systemctl stop postgresql 2>/dev/null
        apt-get remove --purge -y postgresql postgresql-* 2>/dev/null
        rm -rf /var/lib/postgresql 2>/dev/null
        rm -rf /etc/postgresql 2>/dev/null
        log_action "success" "PostgreSQL removido completamente"
    else
        log_action "not_found" "PostgreSQL mantido no sistema"
    fi
else
    log_action "not_found" "PostgreSQL não instalado"
fi
echo

# ============================================================================
# ETAPA 4: NGINX
# ============================================================================

echo -e "${BLUE}[4/16] Removendo configurações Nginx...${NC}"

NGINX_CONFIGS_REMOVED=0
for config in "/etc/nginx/conf.d/ds.conf" "/etc/nginx/conf.d/onlyoffice*" "/etc/nginx/sites-enabled/ds" "/etc/nginx/sites-available/ds"; do
    if [ -f "$config" ] || [ -d "$config" ]; then
        rm -rf "$config" 2>/dev/null && NGINX_CONFIGS_REMOVED=$((NGINX_CONFIGS_REMOVED + 1))
    fi
done

if [ -d "/etc/nginx/includes/onlyoffice" ]; then
    rm -rf /etc/nginx/includes/onlyoffice* 2>/dev/null && NGINX_CONFIGS_REMOVED=$((NGINX_CONFIGS_REMOVED + 1))
fi

if [ $NGINX_CONFIGS_REMOVED -gt 0 ]; then
    log_action "success" "$NGINX_CONFIGS_REMOVED configuração(ões) Nginx removida(s)"
else
    log_action "not_found" "Nenhuma configuração Nginx do OnlyOffice encontrada"
fi

if command -v nginx &> /dev/null; then
    if ask_yes_no "Deseja remover o Nginx completamente? (Cuidado: pode afetar outros serviços)"; then
        systemctl stop nginx 2>/dev/null
        apt-get remove --purge -y nginx nginx-* 2>/dev/null
        rm -rf /etc/nginx 2>/dev/null
        rm -rf /var/log/nginx 2>/dev/null
        log_action "success" "Nginx removido completamente"
    else
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null
        log_action "not_found" "Nginx mantido (apenas configs OnlyOffice removidas)"
    fi
else
    log_action "not_found" "Nginx não instalado"
fi
echo

# ============================================================================
# ETAPA 5: SUPERVISOR
# ============================================================================

echo -e "${BLUE}[5/16] Removendo Supervisor...${NC}"

if command -v supervisorctl &> /dev/null; then
    systemctl stop supervisor 2>/dev/null
    systemctl disable supervisor 2>/dev/null

    if ask_yes_no "Deseja remover o Supervisor completamente? (Cuidado: pode afetar outros serviços)"; then
        apt-get remove --purge -y supervisor 2>/dev/null
        rm -rf /etc/supervisor 2>/dev/null
        rm -rf /var/log/supervisor 2>/dev/null
        log_action "success" "Supervisor removido completamente"
    else
        rm -f /etc/supervisor/conf.d/ds* 2>/dev/null
        rm -f /etc/supervisor/conf.d/onlyoffice* 2>/dev/null
        supervisorctl reread 2>/dev/null
        supervisorctl update 2>/dev/null
        log_action "not_found" "Supervisor mantido (apenas configs OnlyOffice removidas)"
    fi
else
    log_action "not_found" "Supervisor não instalado"
fi
echo

# ============================================================================
# ETAPA 6: DIRETÓRIOS DE INSTALAÇÃO
# ============================================================================

echo -e "${BLUE}[6/16] Removendo diretórios de instalação...${NC}"

DIRS_REMOVED=0
for dir in "/var/www/onlyoffice" "/var/lib/onlyoffice" "/usr/share/onlyoffice" "/opt/onlyoffice"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir" 2>/dev/null && DIRS_REMOVED=$((DIRS_REMOVED + 1)) && log_action "success" "Removido: $dir"
    fi
done

if [ $DIRS_REMOVED -eq 0 ]; then
    log_action "not_found" "Nenhum diretório de instalação encontrado"
fi
echo

# ============================================================================
# ETAPA 7: CONFIGURAÇÕES
# ============================================================================

echo -e "${BLUE}[7/16] Removendo diretórios de configuração...${NC}"

if [ -d "/etc/onlyoffice" ]; then
    rm -rf /etc/onlyoffice 2>/dev/null && log_action "success" "Removido: /etc/onlyoffice"
else
    log_action "not_found" "Diretório /etc/onlyoffice não existe"
fi
echo

# ============================================================================
# ETAPA 8: LOGS
# ============================================================================

echo -e "${BLUE}[8/16] Removendo logs...${NC}"

if [ -d "/var/log/onlyoffice" ]; then
    rm -rf /var/log/onlyoffice 2>/dev/null && log_action "success" "Removido: /var/log/onlyoffice"
else
    log_action "not_found" "Diretório /var/log/onlyoffice não existe"
fi
echo

# ============================================================================
# ETAPA 9: CACHE E TEMPORÁRIOS
# ============================================================================

echo -e "${BLUE}[9/16] Removendo cache e arquivos temporários...${NC}"

TEMP_REMOVED=0
for pattern in "/var/cache/onlyoffice" "/tmp/onlyoffice*" "/tmp/ds*" "/run/onlyoffice*"; do
    if ls $pattern 2>/dev/null | grep -q .; then
        rm -rf $pattern 2>/dev/null && TEMP_REMOVED=$((TEMP_REMOVED + 1))
    fi
done

if [ $TEMP_REMOVED -gt 0 ]; then
    log_action "success" "$TEMP_REMOVED item(ns) de cache removido(s)"
else
    log_action "not_found" "Nenhum arquivo temporário encontrado"
fi
echo

# ============================================================================
# ETAPA 10: USUÁRIOS E GRUPOS
# ============================================================================

echo -e "${BLUE}[10/16] Removendo usuários e grupos...${NC}"

# Usuário ds
if id "ds" &>/dev/null; then
    DS_PIDS=$(ps -u ds -o pid= 2>/dev/null)
    if [ -n "$DS_PIDS" ]; then
        for pid in $DS_PIDS; do
            [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] && kill -9 $pid 2>/dev/null
        done
        sleep 1
    fi
    userdel -r ds 2>/dev/null || userdel ds 2>/dev/null
    log_action "success" "Usuário 'ds' removido"
else
    log_action "not_found" "Usuário 'ds' não existe"
fi

# Grupo ds
if getent group ds &>/dev/null; then
    groupdel ds 2>/dev/null && log_action "success" "Grupo 'ds' removido"
else
    log_action "not_found" "Grupo 'ds' não existe"
fi
echo

# ============================================================================
# ETAPA 11: REPOSITÓRIOS
# ============================================================================

echo -e "${BLUE}[11/16] Removendo repositórios...${NC}"

if [ -f "/etc/apt/sources.list.d/onlyoffice.list" ]; then
    rm -f /etc/apt/sources.list.d/onlyoffice.list 2>/dev/null && log_action "success" "Repositório OnlyOffice removido"
else
    log_action "not_found" "Repositório OnlyOffice não existe"
fi
echo

# ============================================================================
# ETAPA 12: CHAVES GPG
# ============================================================================

echo -e "${BLUE}[12/16] Removendo chaves GPG...${NC}"

if [ -f "/usr/share/keyrings/onlyoffice.gpg" ]; then
    rm -f /usr/share/keyrings/onlyoffice.gpg 2>/dev/null && log_action "success" "Chave GPG OnlyOffice removida"
else
    log_action "not_found" "Chave GPG OnlyOffice não existe"
fi
echo

# ============================================================================
# ETAPA 13: ERLANG
# ============================================================================

echo -e "${BLUE}[13/16] Verificando Erlang...${NC}"

if dpkg -l | grep -q "^ii.*erlang"; then
    if ask_yes_no "Deseja remover o Erlang? (Necessário apenas se não usar RabbitMQ local)"; then
        apt-get remove --purge -y erlang* 2>/dev/null
        rm -f /etc/apt/sources.list.d/erlang.list 2>/dev/null
        rm -f /usr/share/keyrings/erlang-solutions-archive-keyring.gpg 2>/dev/null
        log_action "success" "Erlang removido"
    else
        log_action "not_found" "Erlang mantido no sistema"
    fi
else
    log_action "not_found" "Erlang não instalado"
fi
echo

# ============================================================================
# ETAPA 14: SYSTEMD
# ============================================================================

echo -e "${BLUE}[14/16] Limpando serviços systemd...${NC}"

SYSTEMD_REMOVED=0
for pattern in "/etc/systemd/system/multi-user.target.wants/ds*" "/lib/systemd/system/ds*" "/usr/lib/systemd/system/ds*" "/etc/systemd/system/ds*"; do
    if ls $pattern 2>/dev/null | grep -q .; then
        rm -f $pattern 2>/dev/null && SYSTEMD_REMOVED=$((SYSTEMD_REMOVED + 1))
    fi
done

systemctl daemon-reload 2>/dev/null

if [ $SYSTEMD_REMOVED -gt 0 ]; then
    log_action "success" "$SYSTEMD_REMOVED serviço(s) systemd removido(s)"
else
    log_action "not_found" "Nenhum serviço systemd do OnlyOffice encontrado"
fi
echo

# ============================================================================
# ETAPA 15: LIMPAR APT
# ============================================================================

echo -e "${BLUE}[15/16] Limpando cache do sistema...${NC}"

apt-get clean 2>/dev/null && log_action "success" "Cache APT limpo"
apt-get autoclean 2>/dev/null && log_action "success" "Cache antigo removido"
apt-get autoremove -y 2>/dev/null && log_action "success" "Pacotes órfãos removidos"
apt-get update 2>/dev/null && log_action "success" "Lista de pacotes atualizada"
echo

# ============================================================================
# ETAPA 16: VERIFICAÇÃO FINAL
# ============================================================================

echo -e "${BLUE}[16/16] Verificação final...${NC}\n"

echo -e "${CYAN}═══ Relatório de Verificação ═══${NC}\n"

# Processos
PROCESSES=$(ps aux | grep -E "(documentserver|ds-converter|ds-docservice)" | grep -v grep | wc -l)
if [ $PROCESSES -eq 0 ]; then
    log_action "success" "Nenhum processo OnlyOffice em execução"
else
    log_action "failed" "Ainda existem $PROCESSES processo(s) em execução"
fi

# Diretórios
DIRS_REMAINING=0
for dir in "/var/www/onlyoffice" "/var/lib/onlyoffice" "/etc/onlyoffice" "/var/log/onlyoffice" "/opt/onlyoffice"; do
    [ -d "$dir" ] && DIRS_REMAINING=$((DIRS_REMAINING + 1)) && log_action "failed" "Diretório ainda existe: $dir"
done
[ $DIRS_REMAINING -eq 0 ] && log_action "success" "Todos os diretórios removidos"

# Usuários
if id "ds" &>/dev/null; then
    log_action "failed" "Usuário 'ds' ainda existe"
else
    log_action "success" "Usuário 'ds' removido"
fi

# Pacotes
if dpkg -l | grep -q "onlyoffice"; then
    log_action "failed" "Pacote OnlyOffice ainda registrado no dpkg"
    dpkg -l | grep onlyoffice
else
    log_action "success" "Nenhum pacote OnlyOffice instalado"
fi

# ============================================================================
# RELATÓRIO FINAL
# ============================================================================

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║        Limpeza Concluída! ✓                                ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}═══ Estatísticas da Limpeza ═══${NC}"
echo -e "  ${GREEN}✓${NC} Itens removidos: ${GREEN}$ITEMS_REMOVED${NC}"
echo -e "  ${GRAY}⊘${NC} Itens não encontrados: ${GRAY}$ITEMS_NOT_FOUND${NC}"
echo -e "  ${YELLOW}⚠${NC} Itens com problemas: ${YELLOW}$ITEMS_FAILED${NC}"

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo -e "\n${BLUE}Backup salvo em:${NC} ${BACKUP_DIR}"
fi

echo -e "\n${YELLOW}═══ PRÓXIMOS PASSOS ═══${NC}"
echo -e "1. ${CYAN}O sistema está pronto para nova instalação${NC}"

if [ $ITEMS_FAILED -gt 0 ]; then
    echo -e "2. ${YELLOW}Alguns itens não foram removidos completamente${NC}"
    echo -e "3. ${YELLOW}Recomendado: Reinicie o servidor para limpeza final${NC}"
    echo -e "   ${BLUE}sudo reboot${NC}"
else
    echo -e "2. ${GREEN}Limpeza 100% completa!${NC}"
    echo -e "3. ${CYAN}Recomendado: Reinicie antes de instalar novamente${NC}"
    echo -e "   ${BLUE}sudo reboot${NC}"
fi

echo -e "\n${GREEN}Limpeza finalizada!${NC}\n"

# Perguntar se deseja reiniciar
if ask_yes_no "Deseja reiniciar o servidor agora? (Recomendado)"; then
    echo -e "${YELLOW}Reiniciando em 5 segundos... (Ctrl+C para cancelar)${NC}"
    sleep 5
    reboot
fi
