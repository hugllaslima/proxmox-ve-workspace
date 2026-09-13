#!/bin/bash

################################################################################
# Script de Atualização Proxmox VE 8.x (Sem Subscrição / No-Subscription)
# Autor: SysAdmin / Hugllas Lima
# Data: 2026-09-12
# Versão: 2.0
# Descrição: Atualização interativa, segura e tolerante a falhas para Proxmox VE 8
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
SCRIPT_VERSION="2.0"
LOG_FILE="/var/log/proxmox-upgrade-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/root/proxmox-config-backup"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
ERROR_COUNT=0
CURRENT_VERSION=""
DEBIAN_CODENAME=""

################################################################################
# FUNÇÕES AUXILIARES
################################################################################

# Log com timestamp
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Print com cor
print_color() {
    local color=$1
    shift
    local message="$*"
    echo -e "${color}${message}${NC}"
}

# Linha divisória
print_line() {
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# Pergunta com confirmação (sim/não)
confirm() {
    local prompt="$1"
    local response

    while true; do
        read -r -p "$(echo -e "${YELLOW}❓ $prompt (s/n): ${NC}")" response
        case "$response" in
            [sS][iI]|[sS])
                return 0
                ;;
            [nN][ãÃ][oO]|[nN])
                return 1
                ;;
            *)
                print_color $RED "Resposta inválida. Digite 's' para sim ou 'n' para não."
                ;;
        esac
    done
}

# Tratamento de erro fatal
error_exit() {
    local message="$1"
    local exit_code=${2:-1}
    print_color $RED "❌ ERRO: $message"
    log "ERROR" "$message"
    exit "$exit_code"
}

# Executa comando registrando log
run_command() {
    local description="$1"
    local command="$2"
    local critical=${3:-true}  # true = crítico, false = opcional

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

# Executa comando longo com spinner animado, tempo decorrido e feedback visual
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

    # Executa o comando em segundo plano gravando no arquivo de log
    eval "$command" >> "$LOG_FILE" 2>&1 &
    local cmd_pid=$!

    # Oculta o cursor durante o progresso
    tput civis 2>/dev/null || true

    while kill -0 "$cmd_pid" 2>/dev/null; do
        local now
        now=$(date +%s)
        local elapsed=$((now - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        local time_str
        time_str=$(printf "%02d:%02d" "$mins" "$secs")

        # Captura última linha útil do log para mostrar o que o APT está fazendo
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

    # Restaura o cursor
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

    # 1. Verifica se é root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Este script deve ser executado com privilégios de root."
    fi
    log "INFO" "Privilégios de root confirmados"
    print_color $GREEN "✓ Privilégios root - OK"

    # 2. Verifica se o Proxmox VE está instalado
    if ! command -v pveversion &> /dev/null; then
        error_exit "Proxmox VE não foi detectado (comando pveversion não encontrado)."
    fi

    CURRENT_VERSION=$(pveversion | grep -oP 'pve-manager/\K[^/ ]+' || echo "desconhecida")
    print_color $GREEN "✓ Proxmox VE instalado - Versão detectada: $CURRENT_VERSION"
    log "INFO" "Versão do Proxmox: $CURRENT_VERSION"

    # 3. Detecta versão base do Debian
    if [ -f /etc/os-release ]; then
        DEBIAN_CODENAME=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release || echo "")
    fi
    if [ -z "$DEBIAN_CODENAME" ] && command -v lsb_release &> /dev/null; then
        DEBIAN_CODENAME=$(lsb_release -cs)
    fi

    print_color $GREEN "✓ Base Debian detectada: $DEBIAN_CODENAME"
    log "INFO" "Codename Debian: $DEBIAN_CODENAME"

    if [ "$DEBIAN_CODENAME" != "bookworm" ]; then
        print_color $YELLOW "⚠ ATENÇÃO: Este host está executando o Debian '$DEBIAN_CODENAME' (esperado: 'bookworm' para Proxmox 8.x)."
        if ! confirm "Deseja continuar mesmo assim?"; then
            error_exit "Execução abortada pelo usuário devido à incompatibilidade de versão do Debian."
        fi
    fi

    # 4. Verifica processos do APT/dpkg bloqueados
    if fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
        error_exit "Existe outro processo do apt/dpkg em execução no momento. Aguarde sua finalização."
    fi
    print_color $GREEN "✓ Bloqueios do gerenciador de pacotes - Desimpedidos"

    # 5. Verifica espaço livre em disco (/ e /var)
    local available_root_kb
    local available_var_kb
    available_root_kb=$(df --output=avail / | tail -n 1)
    available_var_kb=$(df --output=avail /var | tail -n 1)

    # Requer pelo menos 4GB livres (4194304 KB)
    if [ "$available_root_kb" -lt 4194304 ] || [ "$available_var_kb" -lt 4194304 ]; then
        print_color $YELLOW "⚠ Pouco espaço disponível em disco (/ ou /var com menos de 4GB livres)."
        if ! confirm "Deseja continuar mesmo com espaço reduzido?"; then
            error_exit "Atualização cancelada pelo usuário para liberação de espaço em disco."
        fi
    else
        print_color $GREEN "✓ Espaço em disco disponível - Suficiente"
    fi

    # 6. Verifica conectividade com a internet e repositórios
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
# VERIFICAÇÃO DE STORAGES EXTERNOS (USB / NFS / DISCO ADICIONAL)
################################################################################

# Lista variável global para armazenar storages USB detectados
USB_STORAGE_DETECTED=false
USB_STORAGE_PATHS=()

check_external_storage() {
    print_line
    print_color $CYAN "💽 Verificando Storages Externos Montados no Proxmox VE..."
    print_line

    local found_any=false

    # Itera sobre pontos de montagem sob /mnt/pve/ (padrão de storages no Proxmox)
    while IFS= read -r mount_point; do
        [ -z "$mount_point" ] && continue
        found_any=true

        local device
        device=$(df --output=source "$mount_point" 2>/dev/null | tail -n 1)

        # Detecta se o dispositivo é USB verificando o sys bus path
        local is_usb=false
        if [ -n "$device" ] && [[ "$device" == /dev/* ]]; then
            local dev_name
            dev_name=$(basename "$device" | sed 's/[0-9]*$//')
            local sys_path="/sys/block/${dev_name}/device/../../../"
            if ls "$sys_path" 2>/dev/null | grep -q 'usb' 2>/dev/null || \
               udevadm info --query=property --name="$device" 2>/dev/null | grep -q 'ID_BUS=usb'; then
                is_usb=true
            fi
        fi

        if [ "$is_usb" = true ]; then
            USB_STORAGE_DETECTED=true
            USB_STORAGE_PATHS+=("$mount_point")
            print_color $YELLOW "⚠  Storage USB detectado: $mount_point  →  dispositivo: $device"
            log "WARN" "Storage USB em uso: $mount_point ($device)"
        else
            print_color $GREEN "✓ Storage externo OK: $mount_point  →  $device"
            log "INFO" "Storage externo: $mount_point ($device)"
        fi

    done < <(mount | awk '{print $3}' | grep '^/mnt/pve/')

    if [ "$found_any" = false ]; then
        print_color $BLUE "ℹ️  Nenhum storage em /mnt/pve/ detectado no momento."
        log "INFO" "Nenhum storage externo (/mnt/pve/*) montado"
    fi

    if [ "$USB_STORAGE_DETECTED" = true ]; then
        echo ""
        print_color $YELLOW "╔══════════════════════════════════════════════════════════════════════════╗"
        print_color $YELLOW "║ ⚠  ATENÇÃO: Storages USB detectados!                                    ║"
        print_color $YELLOW "║    Após atualização de kernel (dist-upgrade), dispositivos USB           ║"
        print_color $YELLOW "║    podem ser remapeados ou perder compatibilidade.                       ║"
        print_color $YELLOW "║    O script aplicará automaticamente o fix de quirks USB ao final.       ║"
        print_color $YELLOW "╚══════════════════════════════════════════════════════════════════════════╝"
        echo ""
        log "WARN" "Storages USB detectados — fix de quirks será aplicado pós-upgrade"
    fi
}

################################################################################
# FIX DE COMPATIBILIDADE: USB STORAGE QUIRKS
# Corrige falha de reconhecimento de discos USB após atualização de kernel.
# Causa raiz: novo kernel Proxmox pode mudar o modo UAS (USB Attached SCSI),
# tornando o dispositivo inacessível. O quirk força o modo de compatibilidade.
# Solução aplicada: options usb-storage quirks=*:u + update-initramfs -u -k all
################################################################################

fix_usb_storage_quirks() {
    print_line
    print_color $CYAN "🔧 Aplicando Fix de Compatibilidade para Discos USB (USB Quirks)..."
    print_line

    local conf_file="/etc/modprobe.d/usb-storage.conf"
    local quirk_line="options usb-storage quirks=*:u"

    # Verifica se o fix já foi aplicado
    if [ -f "$conf_file" ] && grep -qF "$quirk_line" "$conf_file"; then
        print_color $GREEN "✓ Fix USB quirks já está aplicado em $conf_file — nenhuma ação necessária."
        log "INFO" "USB quirks já presentes em $conf_file"
    else
        print_color $BLUE "▶ Criando/atualizando $conf_file com opção de quirks..."
        echo "$quirk_line" >> "$conf_file"
        if [ $? -eq 0 ]; then
            print_color $GREEN "✓ Opção '$quirk_line' adicionada em $conf_file"
            log "INFO" "USB quirk escrito em $conf_file"
        else
            print_color $RED "❌ Falha ao escrever em $conf_file"
            log "ERROR" "Falha ao escrever USB quirk em $conf_file"
            return 1
        fi
    fi

    # Recria o initramfs para todos os kernels instalados
    print_color $BLUE "▶ Recriando initramfs para todos os kernels instalados (update-initramfs -u -k all)..."
    print_color $YELLOW "   ⏳ Este processo pode levar alguns minutos..."

    run_with_spinner \
        "Recriando initramfs (update-initramfs -u -k all)" \
        "update-initramfs -u -k all" \
        true

    echo ""
    print_color $GREEN "✓ Fix USB quirks aplicado com sucesso!"
    print_color $CYAN "ℹ️  O fix será ativado após a próxima reinicialização do servidor."
    log "INFO" "Fix USB quirks aplicado e initramfs regenerado com sucesso"

    # Exibe storages USB que serão beneficiados
    if [ ${#USB_STORAGE_PATHS[@]} -gt 0 ]; then
        print_color $BLUE "▶ Storages USB que serão beneficiados após reboot:"
        for path in "${USB_STORAGE_PATHS[@]}"; do
            print_color $GREEN "   • $path"
        done
    fi
    echo ""
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

    # Backup da base SQLite do Proxmox cluster (se existir)
    if [ -f "/var/lib/pve-cluster/config.db" ]; then
        print_color $BLUE "▶ Copiando base do cluster (/var/lib/pve-cluster/config.db)..."
        cp -a /var/lib/pve-cluster/config.db "$target_backup_dir/" >> "$LOG_FILE" 2>&1
        print_color $GREEN "✓ Base do cluster salva com sucesso"
    fi

    # Itens essenciais do sistema e Proxmox
    local items_to_backup=(
        "/etc/pve"
        "/etc/apt"
        "/etc/network/interfaces"
        "/etc/fstab"
        "/etc/hosts"
        "/etc/corosync"
        "/etc/modprobe.d"
        "/root/.ssh"
    )

    # Backup explícito do storage.cfg (crítico para recuperação de storages externos)
    if [ -f "/etc/pve/storage.cfg" ]; then
        print_color $BLUE "▶ Copiando configuração de storages (/etc/pve/storage.cfg)..."
        cp -a /etc/pve/storage.cfg "$target_backup_dir/storage.cfg.bak" >> "$LOG_FILE" 2>&1
        print_color $GREEN "✓ storage.cfg salvo com sucesso"
    fi

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

    # Salva lista de VMs e Containers para referência
    if command -v qm &> /dev/null; then
        qm list > "$target_backup_dir/vms-qemu.txt" 2>> "$LOG_FILE" || true
    fi
    if command -v pct &> /dev/null; then
        pct list > "$target_backup_dir/containers-lxc.txt" 2>> "$LOG_FILE" || true
    fi

    # Compacta o backup para economia de espaço e facilidade de restauração
    print_color $BLUE "▶ Compactando arquivos de backup..."
    tar -czf "$target_backup_dir/pve-backup-$BACKUP_DATE.tar.gz" -C "$target_backup_dir" . >> "$LOG_FILE" 2>&1

    print_color $GREEN "✓ Backup completo salvo em: $target_backup_dir"
    log "INFO" "Backup finalizado com sucesso em $target_backup_dir"
}

################################################################################
# CONFIGURAÇÃO DE REPOSITÓRIOS (NO-SUBSCRIPTION)
################################################################################

setup_repositories() {
    print_line
    print_color $CYAN "🔄 Configurando Repositórios (No-Subscription)..."
    print_line

    local codename="${DEBIAN_CODENAME:-bookworm}"

    # 1. Backup do sources.list atual
    cp /etc/apt/sources.list "/etc/apt/sources.list.backup.$BACKUP_DATE"
    log "INFO" "Backup de /etc/apt/sources.list criado"

    # 2. Desativa repositório corporativo no /etc/apt/sources.list
    sed -i 's|^deb https://enterprise.proxmox.com|# deb https://enterprise.proxmox.com|g' /etc/apt/sources.list
    sed -i 's|^deb http://enterprise.proxmox.com|# deb http://enterprise.proxmox.com|g' /etc/apt/sources.list

    # 3. Desativa repositório corporativo no arquivo pve-enterprise.list padrão se existir
    local enterprise_list="/etc/apt/sources.list.d/pve-enterprise.list"
    if [ -f "$enterprise_list" ]; then
        print_color $BLUE "▶ Desativando repositório Enterprise em $enterprise_list..."
        sed -i 's|^deb |# deb |g' "$enterprise_list"
        log "INFO" "Repositório corporativo desativado em $enterprise_list"
    fi

    # 4. Desativa Ceph enterprise se presente
    local ceph_list="/etc/apt/sources.list.d/ceph.list"
    if [ -f "$ceph_list" ]; then
        print_color $BLUE "▶ Ajustando repositório Ceph em $ceph_list..."
        sed -i 's|^deb https://enterprise.proxmox.com/debian/ceph|# deb https://enterprise.proxmox.com/debian/ceph|g' "$ceph_list"
    fi

    # 5. Configura repositório No-Subscription em arquivo dedicado para melhor organização
    local nosub_file="/etc/apt/sources.list.d/pve-no-subscription.list"
    print_color $BLUE "▶ Configurando repositório pve-no-subscription para $codename..."
    cat << EOF > "$nosub_file"
# Proxmox VE No-Subscription Repository
deb http://download.proxmox.com/debian/pve $codename pve-no-subscription
EOF
    log "INFO" "Arquivo $nosub_file atualizado com sucesso"

    # 6. Garante que os repositórios oficiais Debian estejam presentes no sources.list
    if ! grep -q "deb.debian.org/debian" /etc/apt/sources.list; then
        print_color $YELLOW "▶ Adicionando espelhos oficiais do Debian $codename em /etc/apt/sources.list..."
        cat << EOF >> /etc/apt/sources.list

# Repositórios oficiais do Debian ($codename)
deb http://deb.debian.org/debian $codename main contrib
deb http://deb.debian.org/debian $codename-updates main contrib
deb http://security.debian.org/debian-security $codename-security main contrib
EOF
        log "INFO" "Repositórios Debian adicionados ao sources.list"
    fi

    print_color $GREEN "✓ Repositórios No-Subscription configurados com sucesso"
    log "INFO" "Configuração de repositórios finalizada"
}

################################################################################
# ATUALIZAÇÃO DOS PACOTES
################################################################################

upgrade_system() {
    print_line
    print_color $CYAN "📦 Atualizando Sistema e Pacotes do Proxmox VE..."
    print_line

    run_with_spinner "Atualizando lista de pacotes dos repositórios (apt update)" "apt-get update" true

    # Checa pacotes que podem ser atualizados
    local upgradable_count
    upgradable_count=$(apt-get -s dist-upgrade | grep -oP '^\d+ (?=upgraded)' || echo "0")
    print_color $BLUE "▶ Pacotes disponíveis para atualização: $upgradable_count"
    log "INFO" "Pacotes a serem atualizados: $upgradable_count"

    if [ "$upgradable_count" -eq 0 ]; then
        echo ""
        print_color $GREEN "✓ Todos os pacotes já estão em suas versões mais recentes!"
        print_color $CYAN "ℹ️  O seu nó Proxmox VE ($CURRENT_VERSION) já possui todos os pacotes atualizados."
        print_color $CYAN "   Não há novas atualizações disponíveis no repositório No-Subscription no momento."
        echo ""
        return 0
    fi

    # Mensagem destacada sobre o tempo de execução
    echo ""
    print_color $YELLOW "╔════════════════════════════════════════════════════════════════════════════╗"
    print_color $YELLOW "║ ⏳ AVISO: A atualização de pacotes (dist-upgrade) será iniciada.          ║"
    print_color $YELLOW "║    • Esta etapa baixa e instala novos pacotes do sistema e novo kernel.   ║"
    print_color $YELLOW "║    • O processo PODE DEMORAR entre 5 a 20 minutos.                         ║"
    print_color $YELLOW "║    • Um indicador animado com o tempo decorrido será exibido abaixo.       ║"
    print_color $YELLOW "║    • Por favor, NÃO cancele nem feche o terminal durante este processo!    ║"
    print_color $YELLOW "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Executa a atualização completa com spinner e feedback de tempo
    run_with_spinner "Atualizando pacotes do sistema (apt-get dist-upgrade)" \
        "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" true

    # Limpeza de pacotes órfãos e cache
    print_color $BLUE "▶ Limpando pacotes obsoletos..."
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

    # Verifica nova versão do Proxmox
    if command -v pveversion &> /dev/null; then
        local new_version
        new_version=$(pveversion | grep -oP 'pve-manager/\K[^/ ]+' || echo "desconhecida")
        print_color $GREEN "✓ Versão do Proxmox VE: $new_version"
        log "INFO" "Versão Proxmox pós-atualização: $new_version"
    else
        print_color $RED "❌ Erro ao validar comando pveversion."
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi

    # Verifica status dos serviços essenciais do Proxmox
    print_color $BLUE "▶ Verificando serviços críticos..."
    local services=("pve-manager" "pvedaemon" "pveproxy" "pvestatd")
    
    # Se corosync estiver instalado, verifica também
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

    # Exibe espaço em disco pós-atualização
    print_color $BLUE "▶ Espaço em disco atualizado:"
    df -h / | tail -1
}

################################################################################
# VERIFICAÇÃO E CONFIRMAÇÃO DE REBOOT
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

    # 1. Verifica se arquivo do sistema indica necessidade de reboot
    if [ -f /var/run/reboot-required ]; then
        print_color $YELLOW "⚠ O sistema operacional sinalizou que uma reinicialização é necessária (/var/run/reboot-required)."
        reboot_recommended=true
    fi

    # 2. Verifica se o kernel ativo é diferente do mais recente instalado
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

    # Pergunta expressa ao usuário se deseja reiniciar agora
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
# RECOMENDAÇÕES PÓS-ATUALIZAÇÃO
################################################################################

################################################################################
# MIGRAÇÃO PARA PROXMOX VE 9.x (DEBIAN TRIXIE)
################################################################################

run_pve8to9_check() {
    print_line
    print_color $CYAN "🔍 Executando Verificação Prévia de Compatibilidade (pve8to9)..."
    print_line

    if command -v pve8to9 &> /dev/null; then
        print_color $BLUE "▶ Executando checklist oficial 'pve8to9 --full'..."
        pve8to9 --full | tee -a "$LOG_FILE"
        local status=${PIPESTATUS[0]}
        if [ $status -eq 0 ]; then
            print_color $GREEN "✓ Checklist pve8to9 aprovado sem erros críticos."
        else
            print_color $YELLOW "⚠ O pve8to9 reportou avisos ou recomendações (código $status)."
            if ! confirm "Deseja prosseguir com o upgrade mesmo com os avisos acima?"; then
                error_exit "Migração cancelada pelo usuário para revisão do pve8to9."
            fi
        fi
    else
        print_color $YELLOW "ℹ️ O comando 'pve8to9' não está presente no nó. Prosseguindo com verificações padrão..."
    fi
}

switch_repositories_to_trixie() {
    print_line
    print_color $CYAN "🔄 Configurando Repositórios Oficiais do Proxmox VE 9 (Debian Trixie)..."
    print_line

    # 1. Backup de segurança de todo o diretório /etc/apt
    local backup_apt_dir="/etc/apt/backup-sources-$BACKUP_DATE"
    mkdir -p "$backup_apt_dir"
    cp -a /etc/apt/sources.list "$backup_apt_dir/" 2>/dev/null || true
    if [ -d /etc/apt/sources.list.d ]; then
        cp -a /etc/apt/sources.list.d "$backup_apt_dir/" 2>/dev/null || true
    fi
    log "INFO" "Backup completo de /etc/apt criado em $backup_apt_dir"

    # 2. Desativa TODOS os arquivos em /etc/apt/sources.list.d para eliminar 404 (como ceph.list) e 401 (enterprise)
    if [ -d /etc/apt/sources.list.d ]; then
        print_color $BLUE "▶ Desativando arquivos conflitantes em /etc/apt/sources.list.d/..."
        for f in /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] || continue
            mv "$f" "${f}.disabled" 2>> "$LOG_FILE" || true
            log "INFO" "Desativado arquivo legado: $f -> ${f}.disabled"
        done
        print_color $GREEN "✓ Diretório /etc/apt/sources.list.d/ limpo e sem conflitos"
    fi

    # 3. Configura o /etc/apt/sources.list diretamente com as 4 fontes limpas oficiais
    print_color $BLUE "▶ Escrevendo fontes limpas do Proxmox 9 em /etc/apt/sources.list..."
    cat << 'EOF' > /etc/apt/sources.list
# Repositórios Oficiais Debian 13 (Trixie)
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware

# Repositório Proxmox VE 9 No-Subscription
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription

# Atualizações de Segurança Debian 13
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

    log "INFO" "Arquivo /etc/apt/sources.list configurado com as fontes oficiais do Proxmox 9"
    print_color $GREEN "✓ /etc/apt/sources.list atualizado com sucesso!"
}

major_upgrade_8_to_9() {
    print_line
    print_color $RED "🚀 UPGRADE MAIOR: PROXMOX VE 8.4 → 9.2 (MIGRAÇÃO DE SISTEMA)"
    print_line
    cat << 'EOF'
Este procedimento irá realizar a MIGRAÇÃO COMPLETA:
  • Validação de pré-requisitos e teste de compatibilidade (pve8to9)
  • Detecção de storages externos (USB, NFS, SSD adicional) e aviso de riscos
  • Backup completo das configurações (/etc/pve, storage.cfg, fstab, modprobe.d)
  • Garantia de que a base 8.4 atual está totalmente atualizada
  • Migração dos repositórios: Debian 12 (Bookworm) → Debian 13 (Trixie)
  • Instalação dos pacotes do Proxmox VE 9.2 e novo Kernel Linux
  • Aplicação automática de fix de compatibilidade USB (quirks) se USB detectado
  • Verificação pós-upgrade e solicitação de reinicialização do servidor

⏳ Tempo estimado: 15 a 35 minutos (dependendo da conexão e disco)
⚠️  Recomendado: Certifique-se de que não há tarefas críticas em execução.
EOF
    print_line

    if ! confirm "Tem certeza que deseja iniciar o Upgrade para Proxmox VE 9.2 agora?"; then
        log "INFO" "Upgrade maior cancelado pelo usuário"
        print_color $YELLOW "Operação cancelada."
        return 0
    fi

    log "INFO" "Iniciando processo de Upgrade Proxmox 8.4 para 9.2"

    # 0. Verificações iniciais e inventário do ambiente
    check_prerequisites
    check_external_storage   # Detecta USB/NFS/SSD e armazena resultado para uso pós-upgrade
    run_pve8to9_check
    create_backup            # Backup inclui fstab, storage.cfg e modprobe.d

    # 1. Migra repositórios para Trixie e desativa repositórios legados (Ceph/Enterprise)
    switch_repositories_to_trixie

    # 2. Executa o Major Upgrade para Proxmox 9
    echo ""
    print_color $YELLOW "╔════════════════════════════════════════════════════════════════════════════╗"
    print_color $YELLOW "║ 🚀 INICIANDO INSTALAÇÃO DO PROXMOX VE 9.2 E KERNEL                         ║"
    print_color $YELLOW "║    • Baixando e instalando pacotes do Proxmox 9 e Debian 13 (Trixie).      ║"
    print_color $YELLOW "║    • Este processo pode demorar até 30 minutos.                            ║"
    print_color $YELLOW "║    • NÃO INTERROMPA nem feche a janela do terminal durante a instalação!   ║"
    print_color $YELLOW "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    run_with_spinner "Baixando catálogos do Debian 13 Trixie e Proxmox 9" "apt-get update" true
    run_with_spinner "Instalando Proxmox VE 9.2 e Kernel (apt-get dist-upgrade)" \
        "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y" true

    run_command "Removendo pacotes obsoletos (autoremove)" "apt-get autoremove -y" false
    run_command "Limpando cache do APT (clean)" "apt-get clean" false

    # 3. Fix automático de compatibilidade USB se storage USB foi detectado antes do upgrade
    if [ "$USB_STORAGE_DETECTED" = true ]; then
        echo ""
        print_color $YELLOW "🔧 Storage USB detectado anteriormente — aplicando fix de quirks USB..."
        fix_usb_storage_quirks
    fi

    # 4. Checagem pós-upgrade
    post_update_check
    print_recommendations

    # 5. Reinicialização obrigatória para carregar o Proxmox 9
    echo ""
    print_color $GREEN "🎉 O upgrade para a versão 9.2 foi concluído com sucesso!"
    print_color $YELLOW "🔔 Para inicializar com o novo kernel do Proxmox 9, o servidor deve ser reiniciado."
    if [ "$USB_STORAGE_DETECTED" = true ]; then
        print_color $YELLOW "🔌 O fix de compatibilidade USB também requer reboot para ser ativado."
    fi
    echo ""

    if confirm "Deseja reiniciar o servidor Proxmox agora para carregar a versão 9.2?"; then
        log "INFO" "Usuário autorizou reboot pós-upgrade para Proxmox 9"
        print_color $RED "⚠️  O servidor será REINICIADO em 5 segundos..."
        print_color $YELLOW "Pressione Ctrl+C para cancelar imediatamente."
        sleep 5
        log "INFO" "Executando comando reboot"
        reboot
    else
        log "INFO" "Reboot adiado pelo usuário"
        print_color $GREEN "✓ Reinicialização adiada. Para concluir e ativar o Proxmox 9.2, execute quando for conveniente: reboot"
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

    # Alinha linha à esquerda com padding dinâmico
    box_line() {
        local text="$1"
        local content="  $text"
        local text_len=${#content}
        local pad_len=$((76 - text_len))
        [ $pad_len -lt 0 ] && pad_len=0
        local padding=$(printf "%*s" "$pad_len" "")
        print_color $BLUE "║${content}${padding}║"
    }

    # Centraliza título com emoji (compensando 2 colunas visuais no terminal)
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
    box_center "🚀 Assistente de Atualização Proxmox VE (No-Subscription)"
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
    echo "1) 🚀 Realizar Upgrade Maior: Proxmox VE 8.4 → 9.2 (Debian Trixie)"
    echo "2) 🔄 Atualização Regular de Pacotes (Manter versão atual)"
    echo "3) 🔍 Executar Verificação Prévia de Compatibilidade (pve8to9)"
    echo "4) 💾 Apenas criar backup das configurações"
    echo "5) ⚙️  Apenas configurar repositórios No-Subscription"
    echo "6) ✅ Apenas verificar integridade dos serviços pós-atualização"
    echo "7) 💽 Verificar storages externos e aplicar fix USB (quirks)"
    echo "8) 📄 Exibir log da execução atual"
    echo "9) 🚪 Sair"
    echo ""
}

################################################################################
# FLUXO PRINCIPAL
################################################################################

main() {
    show_banner

    # Inicializa arquivo de log
    touch "$LOG_FILE" 2>/dev/null || true
    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "Assistente de Atualização Proxmox VE iniciado"
    log "INFO" "Usuário: $(whoami) | Hostname: $(hostname)"
    log "INFO" "═══════════════════════════════════════════════════════════"
    echo " "
    while true; do
        show_menu
        read -r -p "$(echo -e "${YELLOW}➤ Selecione uma opção [1-8]: ${NC}")" option

        case "$option" in
            1)
                major_upgrade_8_to_9
                ;;

            2)
                check_prerequisites
                check_external_storage
                create_backup
                setup_repositories
                upgrade_system
                if [ "$USB_STORAGE_DETECTED" = true ]; then
                    print_color $YELLOW "🔧 Storage USB detectado — aplicando fix de quirks USB..."
                    fix_usb_storage_quirks
                fi
                post_update_check
                print_recommendations
                check_and_handle_reboot
                ;;

            3)
                check_prerequisites
                run_pve8to9_check
                ;;

            4)
                create_backup
                print_color $GREEN "✓ Backup das configurações concluído."
                ;;

            5)
                check_prerequisites
                setup_repositories
                print_color $GREEN "✓ Repositórios No-Subscription configurados com sucesso."
                ;;

            6)
                post_update_check
                ;;

            7)
                # Verificação de storages externos e fix USB
                check_external_storage
                echo ""
                if [ "$USB_STORAGE_DETECTED" = true ]; then
                    print_color $YELLOW "💽 Storages USB detectados. Deseja aplicar o fix de quirks USB agora?"
                    if confirm "Aplicar fix USB quirks e regenerar initramfs?"; then
                        fix_usb_storage_quirks
                        echo ""
                        print_color $CYAN "ℹ️  Reinicie o servidor para ativar o fix: reboot"
                    else
                        print_color $YELLOW "Fix USB não aplicado."
                    fi
                else
                    print_color $GREEN "✓ Nenhum storage USB detectado. Fix não necessário."
                    if confirm "Deseja forçar a aplicação do fix USB quirks mesmo assim?"; then
                        fix_usb_storage_quirks
                    fi
                fi
                ;;

            8)
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

            9)
                log "INFO" "Script finalizado pelo usuário"
                print_color $CYAN "Até logo!"
                exit 0
                ;;

            *)
                print_color $RED "Opção inválida! Digite um número de 1 a 9."
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
