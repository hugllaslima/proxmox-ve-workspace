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

    run_command "Atualizando lista de pacotes (apt update)" "apt-get update" true

    # Checa pacotes que podem ser atualizados
    local upgradable_count
    upgradable_count=$(apt-get -s dist-upgrade | grep -oP '^\d+ (?=upgraded)' || echo "0")
    print_color $BLUE "▶ Pacotes disponíveis para atualização: $upgradable_count"
    log "INFO" "Pacotes a serem atualizados: $upgradable_count"

    if [ "$upgradable_count" -eq 0 ]; then
        print_color $GREEN "✓ Todos os pacotes já estão em suas versões mais recentes!"
        return 0
    fi

    # Executa a atualização completa
    print_color $YELLOW "⏳ Executando atualização de pacotes (pode demorar alguns minutos)..."
    run_command "Atualizando pacotes (apt-get dist-upgrade)" \
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
    print_color $BLUE "╔════════════════════════════════════════════════════════════════════════════╗"
    print_color $BLUE "║                                                                            ║"
    print_color $BLUE "║          🚀 Assistente de Atualização Proxmox VE (No-Subscription)         ║"
    print_color $BLUE "║                                                                            ║"
    print_color $BLUE "║  Versão do Script: $SCRIPT_VERSION                                         ║"
    print_color $BLUE "║  Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')                                   ║"
    print_color $BLUE "║  Log: $LOG_FILE                                                            ║"
    print_color $BLUE "║                                                                            ║"
    print_color $BLUE "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_menu() {
    print_line
    print_color $CYAN "Opções Disponíveis:"
    print_line
    echo "1) Realizar atualização completa do Proxmox VE (Recomendado)"
    echo "2) Apenas verificar pré-requisitos e status do sistema"
    echo "3) Apenas criar backup das configurações"
    echo "4) Apenas configurar repositórios No-Subscription"
    echo "5) Apenas verificar integridade dos serviços pós-atualização"
    echo "6) Exibir log da execução atual"
    echo "7) Sair"
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

    while true; do
        show_menu
        read -r -p "$(echo -e "${YELLOW}➤ Selecione uma opção [1-7]: ${NC}")" option

        case "$option" in
            1)
                print_color $YELLOW "⚠️  ATENÇÃO - Atualização do Proxmox VE"
                print_line
                cat << 'EOF'
O procedimento irá:
  • Validar pré-requisitos e espaço em disco
  • Criar backup de segurança das configurações (/etc/pve, redes, APT, cluster)
  • Configurar repositórios oficiais pve-no-subscription (Debian Bookworm)
  • Atualizar todos os pacotes do sistema com apt-get dist-upgrade
  • Verificar integridade dos serviços do Proxmox
  • Avaliar a necessidade de reboot e solicitar sua autorização
EOF
                print_line

                if confirm "Deseja iniciar a atualização completa agora?"; then
                    log "INFO" "Usuário confirmou atualização completa"

                    check_prerequisites
                    create_backup
                    setup_repositories
                    upgrade_system
                    post_update_check
                    print_recommendations
                    check_and_handle_reboot
                else
                    log "INFO" "Atualização cancelada pelo usuário"
                    print_color $YELLOW "Atualização não realizada."
                fi
                ;;

            2)
                check_prerequisites
                print_color $GREEN "✓ Verificação de pré-requisitos concluída com sucesso."
                ;;

            3)
                create_backup
                print_color $GREEN "✓ Backup das configurações concluído."
                ;;

            4)
                check_prerequisites
                setup_repositories
                print_color $GREEN "✓ Repositórios configurados. Execute 'apt update' para atualizar a lista de pacotes."
                ;;

            5)
                post_update_check
                ;;

            6)
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

            7)
                log "INFO" "Script finalizado pelo usuário"
                print_color $CYAN "Até logo!"
                exit 0
                ;;

            *)
                print_color $RED "Opção inválida! Digite um número de 1 a 7."
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

trap 'print_color $RED "\n❌ Script interrompido pelo usuário (Ctrl+C)"; log "WARN" "Script interrompido via SIGINT"; exit 130' INT

main
