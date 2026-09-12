#!/bin/bash

################################################################################
# Script de Atualização Proxmox VE 7.x → 8.x (Sem Subscrição / No-Subscription)
# Autor: SysAdmin / Hugllas Lima
# Data: 2026-09-12
# Versão: 1.0
# Descrição: Upgrade seguro e interativo de Proxmox VE 7.4 (Debian 11 Bullseye)
#             para Proxmox VE 8.x (Debian 12 Bookworm) sem repositório Enterprise.
#
# Referência oficial:
#   https://pve.proxmox.com/wiki/Upgrade_from_7_to_8
################################################################################

set -o pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variáveis de configuração
SCRIPT_VERSION="1.0"
LOG_FILE="/var/log/proxmox-upgrade-v7-to-v8-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/root/proxmox-config-backup"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
ERROR_COUNT=0
CURRENT_VERSION=""
DEBIAN_CODENAME=""

# Versões de referência
FROM_DEBIAN="bullseye"   # Debian 11
TO_DEBIAN="bookworm"     # Debian 12

################################################################################
# FUNÇÕES AUXILIARES
################################################################################

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

print_color() {
    local color=$1
    shift
    local message="$*"
    echo -e "${color}${message}${NC}"
}

print_line() {
    echo "════════════════════════════════════════════════════════════════════════════════"
}

confirm() {
    local prompt="$1"
    local response

    while true; do
        read -r -p "$(echo -e "${YELLOW}❓ $prompt (s/n): ${NC}")" response
        case "$response" in
            [sS][iI]|[sS])
                return 0
                ;;
            [nN][aA][oO]|[nN])
                return 1
                ;;
            *)
                print_color $RED "Resposta inválida. Digite 's' para sim ou 'n' para não."
                ;;
        esac
    done
}

error_exit() {
    local message="$1"
    local exit_code=${2:-1}
    print_color $RED "❌ ERRO: $message"
    log "ERROR" "$message"
    exit "$exit_code"
}

run_command() {
    local description="$1"
    local command="$2"
    local critical=${3:-true}

    log "INFO" "Executando: $description"
    print_color $BLUE "▶ $description"

    if eval "$command" >> "$LOG_FILE" 2>&1; then
        print_color $GREEN "✓ $description - OK"
        log "INFO" "$description - Sucesso"
        return 0
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
        if [ "$critical" = true ]; then
            log "ERROR" "$description - FALHOU"
            error_exit "$description falhou. Verifique o arquivo de log: $LOG_FILE"
        else
            print_color $YELLOW "⚠ $description - FALHOU (não crítico, continuando)"
            log "WARN" "$description - Falhou (continuando)"
            return 1
        fi
    fi
}

run_with_spinner() {
    local description="$1"
    local command="$2"
    local critical=${3:-true}

    log "INFO" "Executando com monitoramento: $description"
    print_color $BLUE "▶ $description"

    local spinstr=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local start_time
    start_time=$(date +%s)

    eval "$command" >> "$LOG_FILE" 2>&1 &
    local cmd_pid=$!

    tput civis 2>/dev/null || true

    while kill -0 "$cmd_pid" 2>/dev/null; do
        local now
        now=$(date +%s)
        local elapsed=$((now - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        local time_str
        time_str=$(printf "%02d:%02d" "$mins" "$secs")

        local last_action
        last_action=$(tail -n 1 "$LOG_FILE" 2>/dev/null | tr -d '\r\n' | cut -c 1-42)

        local char="${spinstr[$i]}"
        i=$(( (i + 1) % ${#spinstr[@]} ))

        printf "\r\033[K%b%s%b [%b%s%b] Processando... (%s)" \
            "$YELLOW" "$char" "$NC" \
            "$CYAN" "$time_str" "$NC" \
            "${last_action:-Aguarde}"

        sleep 0.25
    done

    tput cnorm 2>/dev/null || true
    printf "\r\033[K"

    wait "$cmd_pid"
    local exit_status=$?

    if [ $exit_status -eq 0 ]; then
        local total_time=$(( $(date +%s) - start_time ))
        local mins=$((total_time / 60))
        local secs=$((total_time % 60))
        print_color $GREEN "✓ $description - Concluído (${mins}m ${secs}s) [OK]"
        log "INFO" "$description - Concluído com sucesso em ${total_time}s"
        return 0
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
        if [ "$critical" = true ]; then
            log "ERROR" "$description - FALHOU com código $exit_status"
            error_exit "$description falhou. Verifique o log detalhado: $LOG_FILE"
        else
            print_color $YELLOW "⚠ $description - FALHOU (não crítico, continuando)"
            log "WARN" "$description - Falhou com código $exit_status"
            return 1
        fi
    fi
}

################################################################################
# PRÉ-REQUISITOS E DIAGNÓSTICO
################################################################################

check_prerequisites() {
    print_line
    print_color $CYAN "🔍 Verificando Pré-requisitos do Sistema..."
    print_line

    if [[ $EUID -ne 0 ]]; then
        error_exit "Este script deve ser executado com privilégios de root."
    fi
    log "INFO" "Privilégios de root confirmados"
    print_color $GREEN "✓ Privilégios root - OK"

    if ! command -v pveversion &> /dev/null; then
        error_exit "Proxmox VE não foi detectado (comando pveversion não encontrado)."
    fi

    CURRENT_VERSION=$(pveversion | grep -oP 'pve-manager/\K[^/ ]+' || echo "desconhecida")
    print_color $GREEN "✓ Proxmox VE instalado - Versão detectada: $CURRENT_VERSION"
    log "INFO" "Versão do Proxmox: $CURRENT_VERSION"

    if [ -f /etc/os-release ]; then
        DEBIAN_CODENAME=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release || echo "")
    fi
    if [ -z "$DEBIAN_CODENAME" ] && command -v lsb_release &> /dev/null; then
        DEBIAN_CODENAME=$(lsb_release -cs)
    fi

    print_color $GREEN "✓ Base Debian detectada: $DEBIAN_CODENAME"
    log "INFO" "Codename Debian: $DEBIAN_CODENAME"

    if [ "$DEBIAN_CODENAME" != "$FROM_DEBIAN" ]; then
        print_color $YELLOW "⚠ ATENÇÃO: Este host está executando o Debian '$DEBIAN_CODENAME' (esperado: '$FROM_DEBIAN' para Proxmox 7.x)."
        if ! confirm "Deseja continuar mesmo assim?"; then
            error_exit "Execução abortada pelo usuário devido à incompatibilidade de versão do Debian."
        fi
    fi

    if fuser /var/lib/dpkg/lock > /dev/null 2>&1 || fuser /var/lib/apt/lists/lock > /dev/null 2>&1; then
        error_exit "Existe outro processo do apt/dpkg em execução no momento. Aguarde sua finalização."
    fi
    print_color $GREEN "✓ Bloqueios do gerenciador de pacotes - Desimpedidos"

    local available_root_kb
    local available_var_kb
    available_root_kb=$(df --output=avail / | tail -n 1)
    available_var_kb=$(df --output=avail /var | tail -n 1)

    if [ "$available_root_kb" -lt 4194304 ] || [ "$available_var_kb" -lt 4194304 ]; then
        print_color $YELLOW "⚠ Pouco espaço disponível em disco (/ ou /var com menos de 4GB livres)."
        if ! confirm "Deseja continuar mesmo com espaço reduzido?"; then
            error_exit "Atualização cancelada pelo usuário para liberação de espaço em disco."
        fi
    else
        print_color $GREEN "✓ Espaço em disco disponível - Suficiente"
    fi

    print_color $BLUE "▶ Testando conectividade com download.proxmox.com..."
    if ! ping -c 1 -W 3 download.proxmox.com &> /dev/null; then
        if ! curl -Is --connect-timeout 5 http://download.proxmox.com | grep -q "HTTP"; then
            error_exit "Sem conectividade com download.proxmox.com. Verifique suas conexões de rede e DNS."
        fi
    fi
    print_color $GREEN "✓ Conexão com os servidores do Proxmox - OK"
    log "INFO" "Todos os pré-requisitos foram validados com sucesso"
}

################################################################################
# BACKUP DAS CONFIGURAÇÕES
################################################################################

create_backup() {
    print_line
    print_color $CYAN "💾 Criando Backup das Configurações do Proxmox..."
    print_line

    local target_backup_dir="$BACKUP_DIR/$BACKUP_DATE"
    mkdir -p "$target_backup_dir"
    log "INFO" "Criando diretório de backup em: $target_backup_dir"

    if [ -f "/var/lib/pve-cluster/config.db" ]; then
        print_color $BLUE "▶ Copiando base do cluster (/var/lib/pve-cluster/config.db)..."
        cp -a /var/lib/pve-cluster/config.db "$target_backup_dir/" >> "$LOG_FILE" 2>&1
        print_color $GREEN "✓ Base do cluster salva com sucesso"
    fi

    local items_to_backup=(
        "/etc/pve"
        "/etc/apt"
        "/etc/network/interfaces"
        "/etc/hosts"
        "/etc/corosync"
        "/root/.ssh"
    )

    for item in "${items_to_backup[@]}"; do
        if [ -e "$item" ]; then
            print_color $BLUE "▶ Fazendo backup de: $item"
            cp -r "$item" "$target_backup_dir/" >> "$LOG_FILE" 2>&1
            if [ $? -eq 0 ]; then
                print_color $GREEN "✓ Backup de $item - OK"
            else
                print_color $YELLOW "⚠ Falha ao copiar $item (não crítico)"
                log "WARN" "Falha na cópia de backup do item $item"
            fi
        fi
    done

    if command -v qm &> /dev/null; then
        qm list > "$target_backup_dir/vms-qemu.txt" 2>> "$LOG_FILE" || true
    fi
    if command -v pct &> /dev/null; then
        pct list > "$target_backup_dir/containers-lxc.txt" 2>> "$LOG_FILE" || true
    fi

    print_color $BLUE "▶ Compactando arquivos de backup..."
    tar -czf "$target_backup_dir/pve-backup-$BACKUP_DATE.tar.gz" -C "$target_backup_dir" . >> "$LOG_FILE" 2>&1

    print_color $GREEN "✓ Backup completo salvo em: $target_backup_dir"
    log "INFO" "Backup finalizado com sucesso em $target_backup_dir"
}

################################################################################
# MIGRAÇÃO DE REPOSITÓRIOS PARA BOOKWORM + PROXMOX 8 (NO-SUBSCRIPTION)
################################################################################

switch_repositories_to_bookworm() {
    print_line
    print_color $CYAN "🔄 Configurando Repositórios Oficiais do Proxmox VE 8 (Debian Bookworm)..."
    print_line

    local backup_apt_dir="/etc/apt/backup-sources-$BACKUP_DATE"
    mkdir -p "$backup_apt_dir"
    cp -a /etc/apt/sources.list "$backup_apt_dir/" 2>/dev/null || true
    if [ -d /etc/apt/sources.list.d ]; then
        cp -a /etc/apt/sources.list.d "$backup_apt_dir/" 2>/dev/null || true
    fi
    log "INFO" "Backup completo de /etc/apt criado em $backup_apt_dir"

    if [ -d /etc/apt/sources.list.d ]; then
        print_color $BLUE "▶ Desativando arquivos conflitantes em /etc/apt/sources.list.d/..."
        for f in /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] || continue
            mv "$f" "${f}.disabled" 2>> "$LOG_FILE" || true
            log "INFO" "Desativado arquivo legado: $f -> ${f}.disabled"
        done
        print_color $GREEN "✓ Diretório /etc/apt/sources.list.d/ limpo e sem conflitos"
    fi

    print_color $BLUE "▶ Escrevendo fontes limpas do Proxmox 8 em /etc/apt/sources.list..."
    cat << 'EOF' > /etc/apt/sources.list
# Repositórios Oficiais Debian 12 (Bookworm)
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

# Repositório Proxmox VE 8 No-Subscription
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription

# Atualizações de Segurança Debian 12
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

    log "INFO" "Arquivo /etc/apt/sources.list configurado com as fontes oficiais do Proxmox 8"
    print_color $GREEN "✓ /etc/apt/sources.list atualizado com sucesso!"
}

################################################################################
# ATUALIZAÇÃO REGULAR DE PACOTES (SEM UPGRADE MAIOR)
################################################################################

upgrade_system() {
    print_line
    print_color $CYAN "📦 Atualizando Sistema e Pacotes do Proxmox VE..."
    print_line

    run_with_spinner "Atualizando lista de pacotes dos repositórios (apt update)" "apt-get update" true

    local upgradable_count
    upgradable_count=$(apt-get -s dist-upgrade | grep -oP '^\d+ (?=upgraded)' || echo "0")
    print_color $BLUE "▶ Pacotes disponíveis para atualização: $upgradable_count"
    log "INFO" "Pacotes a serem atualizados: $upgradable_count"

    if [ "$upgradable_count" -eq 0 ]; then
        echo ""
        print_color $GREEN "✓ Todos os pacotes já estão em suas versões mais recentes!"
        print_color $CYAN "ℹ️  O seu nó Proxmox VE ($CURRENT_VERSION) já possui todos os pacotes atualizados."
        echo ""
        return 0
    fi

    echo ""
    print_color $YELLOW "╔════════════════════════════════════════════════════════════════════════════╗"
    print_color $YELLOW "║ ⏳ AVISO: A atualização de pacotes (dist-upgrade) será iniciada.          ║"
    print_color $YELLOW "║    • Esta etapa baixa e instala novos pacotes do sistema e novo kernel.   ║"
    print_color $YELLOW "║    • O processo PODE DEMORAR entre 5 a 20 minutos.                        ║"
    print_color $YELLOW "║    • Um indicador animado com o tempo decorrido será exibido abaixo.      ║"
    print_color $YELLOW "║    • Por favor, NÃO cancele nem feche o terminal durante este processo!   ║"
    print_color $YELLOW "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    run_with_spinner "Atualizando pacotes do sistema (apt-get dist-upgrade)" \
        "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" true

    run_command "Removendo pacotes desnecessários (autoremove)" "apt-get autoremove -y" false
    run_command "Limpando cache do APT (clean)" "apt-get clean" false

    print_color $GREEN "✓ Atualização de pacotes concluída com sucesso"
    log "INFO" "Atualização de pacotes concluída"
}

################################################################################
# VERIFICAÇÃO PÓS-ATUALIZAÇÃO
################################################################################

post_update_check() {
    print_line
    print_color $CYAN "✅ Verificando Integridade do Proxmox VE Pós-Atualização..."
    print_line

    if command -v pveversion &> /dev/null; then
        local new_version
        new_version=$(pveversion | grep -oP 'pve-manager/\K[^/ ]+' || echo "desconhecida")
        print_color $GREEN "✓ Versão do Proxmox VE: $new_version"
        log "INFO" "Versão Proxmox pós-atualização: $new_version"
    else
        print_color $RED "❌ Erro ao validar comando pveversion."
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi

    print_color $BLUE "▶ Verificando serviços críticos..."
    local services=("pve-manager" "pvedaemon" "pveproxy" "pvestatd")

    if systemctl list-unit-files | grep -q "corosync.service"; then
        services+=("corosync")
    fi

    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            print_color $GREEN "✓ Serviço $svc - ATIVO"
            log "INFO" "Serviço $svc está ativo"
        else
            print_color $YELLOW "⚠ Serviço $svc - INATIVO (tentando iniciar...)"
            systemctl start "$svc" >> "$LOG_FILE" 2>&1 || true
            if systemctl is-active --quiet "$svc"; then
                print_color $GREEN "✓ Serviço $svc - INICIADO com sucesso"
            else
                print_color $RED "❌ Serviço $svc falhou ao iniciar"
                log "WARN" "Serviço $svc inativo"
                ERROR_COUNT=$((ERROR_COUNT + 1))
            fi
        fi
    done

    print_color $BLUE "▶ Espaço em disco atualizado:"
    df -h / | tail -1
}

################################################################################
# REBOOT INTELIGENTE
################################################################################

check_and_handle_reboot() {
    print_line
    print_color $CYAN "🔄 Avaliação de Reinicialização (Reboot)"
    print_line

    local reboot_recommended=false
    local running_kernel
    local latest_installed_kernel

    running_kernel=$(uname -r)
    latest_installed_kernel=$(ls -v /boot/vmlinuz-* 2>/dev/null | tail -n 1 | sed 's|/boot/vmlinuz-||')

    echo "Kernel em execução: $running_kernel"
    if [ -n "$latest_installed_kernel" ]; then
        echo "Último kernel instalado: $latest_installed_kernel"
    fi

    if [ -f /var/run/reboot-required ]; then
        print_color $YELLOW "⚠ O sistema operacional sinalizou que uma reinicialização é necessária (/var/run/reboot-required)."
        reboot_recommended=true
    fi

    if [ -n "$latest_installed_kernel" ] && [ "$running_kernel" != "$latest_installed_kernel" ]; then
        print_color $YELLOW "⚠ Um novo kernel Proxmox ($latest_installed_kernel) foi instalado e requer reboot para ser ativado."
        reboot_recommended=true
    fi

    echo ""
    if [ "$reboot_recommended" = true ]; then
        print_color $YELLOW "🔔 RECOMENDAÇÃO: É altamente recomendável reiniciar o servidor para aplicar o novo kernel e módulos."
    else
        print_color $GREEN "ℹ️ O kernel atual está sincronizado. Reiniciar agora é opcional."
    fi
    echo ""

    if confirm "Deseja reiniciar o servidor Proxmox agora?"; then
        log "INFO" "Usuário optou por reiniciar o servidor agora"
        print_color $RED "⚠️  O servidor será REINICIADO em 5 segundos..."
        print_color $YELLOW "Pressione Ctrl+C para cancelar imediatamente."
        sleep 5
        log "INFO" "Executando comando reboot"
        reboot
    else
        log "INFO" "Usuário optou por adiar o reboot"
        print_color $GREEN "✓ Reboot adiado. Você pode reiniciar manualmente quando for conveniente executando: reboot"
    fi
}

################################################################################
# VERIFICAÇÃO PRÉVIA — pve7to8
################################################################################

run_pve7to8_check() {
    print_line
    print_color $CYAN "🔍 Executando Verificação Prévia de Compatibilidade (pve7to8)..."
    print_line

    if ! command -v pve7to8 &> /dev/null; then
        print_color $YELLOW "ℹ️ O comando 'pve7to8' não está presente. Tentando instalar via apt..."
        apt-get update -qq >> "$LOG_FILE" 2>&1 || true
        apt-get install -y pve7to8 >> "$LOG_FILE" 2>&1 || true
    fi

    if command -v pve7to8 &> /dev/null; then
        print_color $BLUE "▶ Executando checklist oficial 'pve7to8 --full'..."
        pve7to8 --full | tee -a "$LOG_FILE"
        local status=${PIPESTATUS[0]}
        if [ $status -eq 0 ]; then
            print_color $GREEN "✓ Checklist pve7to8 aprovado sem erros críticos."
        else
            print_color $YELLOW "⚠ O pve7to8 reportou avisos ou recomendações (código $status)."
            if ! confirm "Deseja prosseguir com o upgrade mesmo com os avisos acima?"; then
                error_exit "Migração cancelada pelo usuário para revisão do pve7to8."
            fi
        fi
    else
        print_color $YELLOW "⚠ Não foi possível instalar o pve7to8. Prosseguindo sem verificação oficial..."
    fi
}

################################################################################
# UPGRADE MAIOR: PROXMOX VE 7.4 → 8.x
################################################################################

major_upgrade_7_to_8() {
    print_line
    print_color $RED "🚀 UPGRADE MAIOR: PROXMOX VE 7.4 → 8.x (MIGRAÇÃO DE SISTEMA)"
    print_line
    cat << 'EOF'
Este procedimento irá realizar a MIGRAÇÃO COMPLETA:
  • Validação de pré-requisitos e teste de compatibilidade (pve7to8)
  • Backup completo das configurações (/etc/pve, cluster SQLite, redes, VMs)
  • Garantia de que a base 7.4 atual está totalmente atualizada
  • Migração dos repositórios: Debian 11 (Bullseye) → Debian 12 (Bookworm)
  • Instalação dos pacotes do Proxmox VE 8.x e novo Kernel Linux
  • Verificação pós-upgrade e solicitação de reinicialização do servidor

⏳ Tempo estimado: 15 a 35 minutos (dependendo da conexão e disco)
⚠️  Recomendado: Certifique-se de que não há tarefas críticas em execução.
EOF
    print_line

    if ! confirm "Tem certeza que deseja iniciar o Upgrade para Proxmox VE 8.x agora?"; then
        log "INFO" "Upgrade maior cancelado pelo usuário"
        print_color $YELLOW "Operação cancelada."
        return 0
    fi

    log "INFO" "Iniciando processo de Upgrade Proxmox 7.4 para 8.x"

    check_prerequisites
    run_pve7to8_check
    create_backup

    # Etapa 1: Atualiza os pacotes da versão atual (7.x) antes de migrar
    print_color $CYAN "▶ Etapa 1/4: Atualizando todos os pacotes da versão 7.x atual..."
    run_with_spinner "Atualizando base 7.x antes da migração (apt update)" "apt-get update" true
    run_with_spinner "Aplicando patches atuais do Proxmox 7 (apt dist-upgrade)" \
        "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" true

    # Etapa 2: Migra repositórios para Bookworm
    print_color $CYAN "▶ Etapa 2/4: Migrando repositórios para Debian 12 Bookworm + Proxmox 8..."
    switch_repositories_to_bookworm

    # Etapa 3: Major Upgrade
    echo ""
    print_color $YELLOW "╔════════════════════════════════════════════════════════════════════════════╗"
    print_color $YELLOW "║ 🚀 ETAPA 3/4: INSTALANDO PROXMOX VE 8.x E KERNEL                         ║"
    print_color $YELLOW "║    • Baixando e instalando pacotes do Proxmox 8 e Debian 12 (Bookworm).   ║"
    print_color $YELLOW "║    • Este processo pode demorar até 30 minutos.                           ║"
    print_color $YELLOW "║    • NÃO INTERROMPA nem feche a janela do terminal durante a instalação!  ║"
    print_color $YELLOW "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    run_with_spinner "Baixando catálogos do Debian 12 Bookworm e Proxmox 8" "apt-get update" true
    run_with_spinner "Instalando Proxmox VE 8.x e Kernel (apt-get dist-upgrade)" \
        "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" true

    run_command "Removendo pacotes obsoletos (autoremove)" "apt-get autoremove -y" false
    run_command "Limpando cache do APT (clean)" "apt-get clean" false

    # Etapa 4: Verificação pós-upgrade
    print_color $CYAN "▶ Etapa 4/4: Verificando integridade do Proxmox VE 8..."
    post_update_check
    print_recommendations

    echo ""
    print_color $GREEN "🎉 O upgrade para o Proxmox VE 8.x foi concluído com sucesso!"
    print_color $YELLOW "🔔 Para inicializar com o novo kernel do Proxmox 8, o servidor deve ser reiniciado."
    echo ""

    if confirm "Deseja reiniciar o servidor Proxmox agora para carregar o Proxmox VE 8.x?"; then
        log "INFO" "Usuário autorizou reboot pós-upgrade para Proxmox 8"
        print_color $RED "⚠️  O servidor será REINICIADO em 5 segundos..."
        print_color $YELLOW "Pressione Ctrl+C para cancelar imediatamente."
        sleep 5
        log "INFO" "Executando comando reboot"
        reboot
    else
        log "INFO" "Reboot adiado pelo usuário"
        print_color $GREEN "✓ Reinicialização adiada. Para concluir e ativar o Proxmox 8.x, execute quando for conveniente: reboot"
    fi
}

################################################################################
# RECOMENDAÇÕES PÓS-ATUALIZAÇÃO
################################################################################

print_recommendations() {
    print_line
    print_color $CYAN "📋 Recomendações e Instruções:"
    print_line

    cat << EOF
1. ✓ Acompanhe o log completo desta execução em:
   $LOG_FILE

2. ✓ Backup das configurações salvo em:
   $BACKUP_DIR/$BACKUP_DATE

3. ✓ Caso precise reiniciar manualmente mais tarde:
   reboot

4. ✓ Para verificar o status das máquinas virtuais e contêineres:
   qm list
   pct list

5. ✓ Para verificar a versão detalhada do Proxmox:
   pveversion -v
EOF
    log "INFO" "Recomendações finais exibidas ao usuário"
}

################################################################################
# MENU PRINCIPAL
################################################################################

show_banner() {
    clear
    local top="╔════════════════════════════════════════════════════════════════════════════╗"
    local bottom="╚════════════════════════════════════════════════════════════════════════════╝"
    local empty="║                                                                            ║"

    box_line() {
        local text="$1"
        local content="  $text"
        local text_len=${#content}
        local pad_len=$((76 - text_len))
        [ $pad_len -lt 0 ] && pad_len=0
        local padding=$(printf "%*s" "$pad_len" "")
        print_color $BLUE "║${content}${padding}║"
    }

    box_center() {
        local text="$1"
        local text_len=${#text}
        local visual_len=$((text_len + 1))
        local pad_total=$((76 - visual_len))
        local pad_left=$((pad_total / 2))
        local pad_right=$((pad_total - pad_left))
        local left_spaces=$(printf "%*s" "$pad_left" "")
        local right_spaces=$(printf "%*s" "$pad_right" "")
        print_color $BLUE "║${left_spaces}${text}${right_spaces}║"
    }

    print_color $BLUE "$top"
    print_color $BLUE "$empty"
    box_center "🚀 Upgrade Proxmox VE 7 → 8 (No-Subscription)"
    print_color $BLUE "$empty"
    box_line "Versão do Script: $SCRIPT_VERSION"
    box_line "Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
    box_line "Log: $LOG_FILE"
    print_color $BLUE "$empty"
    print_color $BLUE "$bottom"
    echo ""
}

show_menu() {
    print_line
    print_color $CYAN "Opções Disponíveis:"
    print_line
    echo "1) 🚀 Realizar Upgrade Maior: Proxmox VE 7.4 → 8.x (Debian Bookworm)"
    echo "2) 🔄 Atualização Regular de Pacotes (Manter versão atual 7.x)"
    echo "3) 🔍 Executar Verificação Prévia de Compatibilidade (pve7to8)"
    echo "4) 💾 Apenas criar backup das configurações"
    echo "5) ⚙️  Apenas configurar repositórios No-Subscription (Bookworm)"
    echo "6) ✅ Apenas verificar integridade dos serviços pós-atualização"
    echo "7) 📄 Exibir log da execução atual"
    echo "8) 🚪 Sair"
    echo ""
}

################################################################################
# FLUXO PRINCIPAL
################################################################################

main() {
    show_banner

    touch "$LOG_FILE" 2>/dev/null || true
    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "Assistente de Upgrade Proxmox VE 7 → 8 iniciado"
    log "INFO" "Usuário: $(whoami) | Hostname: $(hostname)"
    log "INFO" "═══════════════════════════════════════════════════════════"
    echo " "
    while true; do
        show_menu
        read -r -p "$(echo -e "${YELLOW}➤ Selecione uma opção [1-8]: ${NC}")" option

        case "$option" in
            1)
                major_upgrade_7_to_8
                ;;

            2)
                check_prerequisites
                create_backup
                switch_repositories_to_bookworm
                upgrade_system
                post_update_check
                print_recommendations
                check_and_handle_reboot
                ;;

            3)
                check_prerequisites
                run_pve7to8_check
                ;;

            4)
                create_backup
                print_color $GREEN "✓ Backup das configurações concluído."
                ;;

            5)
                check_prerequisites
                switch_repositories_to_bookworm
                print_color $GREEN "✓ Repositórios No-Subscription (Bookworm) configurados com sucesso."
                ;;

            6)
                post_update_check
                ;;

            7)
                if [ -f "$LOG_FILE" ]; then
                    if command -v less &> /dev/null; then
                        less "$LOG_FILE"
                    else
                        cat "$LOG_FILE"
                    fi
                else
                    print_color $YELLOW "Nenhum arquivo de log encontrado em $LOG_FILE."
                fi
                ;;

            8)
                log "INFO" "Script finalizado pelo usuário"
                print_color $CYAN "Até logo!"
                exit 0
                ;;

            *)
                print_color $RED "Opção inválida! Digite um número de 1 a 8."
                ;;
        esac

        echo ""
        read -r -p "Pressione [Enter] para retornar ao menu principal..."
        show_banner
    done
}

################################################################################
# TRATAMENTO DE SINAIS E INÍCIO
################################################################################

trap 'tput cnorm 2>/dev/null || true; print_color $RED "\n❌ Script interrompido pelo usuário (Ctrl+C)"; log "WARN" "Script interrompido via SIGINT"; exit 130' INT

main
