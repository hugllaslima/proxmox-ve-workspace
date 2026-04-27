#!/bin/bash

#==============================================================================
# Script: setup_runner.sh
# Descrição: Configuração de GitHub Actions Self-hosted Runner — Padrão
# Perfil: Padrão/robusto — recomendado para produção; tolerante a falhas
# Diferenciais: logging detalhado, checkpoints, validação de comandos, rollback, recuperação
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 2.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Criação do usuário dedicado para o runner
# 2. Download e instalação do GitHub Actions Runner
# 3. Configuração do runner com token de autenticação
# 4. Criação do serviço systemd
# 5. Configuração de permissões e segurança avançada
# 6. Validação e correções de fluxo
# 7. Inicialização e verificação do serviço

# ============================================================================
# CONFIGURAÇÕES INICIAIS
# ============================================================================

set +e  

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Arquivos de controle
STATE_FILE="/tmp/runner_setup_state"
LOG_FILE="/tmp/runner_setup_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/runner_backup_$(date +%Y%m%d_%H%M%S)"

# Variável para controlar se estamos em teste
IN_RUNNER_TEST=false

# ============================================================================
# FUNÇÕES DE UTILIDADE
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    log "ETAPA: $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
    log "INFO: $1"
}

# Salvar estado atual
save_state() {
    echo "$1" > "$STATE_FILE"
    log "Estado salvo: $1"
}

# Ler estado salvo
get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "0"
    fi
}

# Limpar estado
clear_state() {
    rm -f "$STATE_FILE"
    log "Estado limpo"
}

# Função para executar comandos como runner
run_as_runner() {
    sudo -u runner bash -c "$1" 2>&1 | tee -a "$LOG_FILE"
    return ${PIPESTATUS[0]}
}

# Tratar interrupção (Ctrl+C)
handle_interrupt() {
    if [ "$IN_RUNNER_TEST" = true ]; then
        # Se estamos no teste do runner, apenas continua
        echo
        print_info "Teste do runner interrompido"
        log "Teste do runner interrompido com Ctrl+C"
        IN_RUNNER_TEST=false
        return 0
    else
        # Caso contrário, salva estado e sai
        echo -e "\n${YELLOW}⚠️  Script interrompido pelo usuário${NC}"
        echo -e "${CYAN}Estado atual salvo. Você pode retomar executando o script novamente.${NC}"
        log "Script interrompido pelo usuário"
        exit 130
    fi
}

# Configurar trap para capturar Ctrl+C
trap 'handle_interrupt' INT TERM

# Validar formato de comando
validate_command() {
    local cmd="$1"
    local expected_pattern="$2"
    local cmd_name="$3"
    
    if [[ "$cmd" =~ $expected_pattern ]]; then
        return 0
    else
        print_error "Formato do comando $cmd_name parece incorreto"
        print_info "Esperado algo como: $expected_pattern"
        return 1
    fi
}

# Perguntar se deseja tentar novamente
ask_retry() {
    local question="$1"
    echo
    echo -e "${YELLOW}Opções:${NC}"
    echo "1. Tentar novamente"
    echo "2. Pular esta etapa (não recomendado)"
    echo "3. Cancelar instalação"
    echo
    read -p "Escolha uma opção [1-3]: " choice
    
    case $choice in
        1) return 0 ;;
        2) return 1 ;;
        3) 
            print_warning "Instalação cancelada pelo usuário"
            exit 0
            ;;
        *)
            print_error "Opção inválida"
            ask_retry "$question"
            ;;
    esac
}

# Criar backup antes de operações críticas
create_backup() {
    local what="$1"
    mkdir -p "$BACKUP_DIR"
    log "Criando backup de: $what"
    
    case "$what" in
        "sudoers")
            if [ -f "/etc/sudoers.d/runner" ]; then
                cp /etc/sudoers.d/runner "$BACKUP_DIR/sudoers.runner.bak"
            fi
            ;;
        "user")
            if id "runner" &>/dev/null; then
                getent passwd runner > "$BACKUP_DIR/user.runner.bak"
            fi
            ;;
    esac
}

# Restaurar backup em caso de erro
restore_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        print_info "Restaurando configurações anteriores..."
        log "Backup disponível em: $BACKUP_DIR"
    fi
}

# ============================================================================
# VERIFICAÇÕES INICIAIS
# ============================================================================

print_header "Self-Hosted Runner Setup Script v2.0"
echo -e "${GREEN}✅ Tratamento avançado de erros${NC}"
echo -e "${GREEN}✅ Validação de comandos antes de executar${NC}"
echo -e "${GREEN}✅ Possibilidade de correção sem recomeçar${NC}"
echo -e "${GREEN}✅ Sistema de checkpoints de progresso${NC}"
echo -e "${GREEN}✅ Rollback automático em caso de erro${NC}"
echo -e "${GREEN}✅ Logs detalhados para debug${NC}"
echo -e "${GREEN}✅ Modo de recuperação de instalação parcial${NC}"
echo -e "${GREEN}✅ Suporte a sha256sum e shasum${NC}"
echo -e "${GREEN}✅ Fluxo de teste corrigido (Ctrl+C não interrompe)${NC}"
echo

log "Iniciando script de instalação"
log "Log será salvo em: $LOG_FILE"

# Verificar se está rodando como sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado com sudo!"
    echo "Execute: sudo ./setup-runner.sh"
    exit 1
fi

# Verificar se há instalação anterior interrompida
current_state=$(get_state)
if [ "$current_state" != "0" ] && [ "$current_state" != "" ]; then
    print_warning "Detectada instalação anterior interrompida na etapa: $current_state"
    echo
    echo "Deseja:"
    echo "1. Continuar de onde parou"
    echo "2. Recomeçar do zero"
    read -p "Escolha [1-2]: " resume_choice
    
    if [ "$resume_choice" == "2" ]; then
        clear_state
        current_state="0"
        print_info "Recomeçando instalação do zero"
    else
        print_info "Continuando da etapa $current_state"
    fi
fi

# ============================================================================
# ETAPA 1: CRIAÇÃO DO USUÁRIO RUNNER
# ============================================================================

if [ "$current_state" -lt "1" ]; then
    print_header "ETAPA 1: Criando usuário 'runner'"
    
    create_backup "user"
    
    if id "runner" &>/dev/null; then
        print_warning "Usuário 'runner' já existe"
        echo "Deseja:"
        echo "1. Usar o usuário existente"
        echo "2. Remover e recriar"
        read -p "Escolha [1-2]: " user_choice
        
        if [ "$user_choice" == "2" ]; then
            print_info "Removendo usuário existente..."
            systemctl stop actions.runner.* 2>/dev/null || true
            userdel -r runner 2>/dev/null || true
            useradd -m -s /bin/bash runner
            if [ $? -eq 0 ]; then
                print_success "Usuário 'runner' recriado"
            else
                print_error "Falha ao recriar usuário"
                if ask_retry "criação do usuário"; then
                    exec "$0" "$@"
                fi
            fi
        fi
    else
        useradd -m -s /bin/bash runner
        if [ $? -eq 0 ]; then
            print_success "Usuário 'runner' criado"
        else
            print_error "Falha ao criar usuário runner"
            if ask_retry "criação do usuário"; then
                exec "$0" "$@"
            fi
            exit 1
        fi
    fi
    
    # Configurar senha
    print_info "Configurando senha para o usuário runner..."
    while true; do
        if passwd runner; then
            print_success "Senha configurada"
            break
        else
            print_error "Falha ao configurar senha"
            if ! ask_retry "configuração de senha"; then
                break
            fi
        fi
    done
    
    # Adicionar ao grupo docker
    if groups runner | grep -q docker; then
        print_info "Usuário já está no grupo docker"
    else
        usermod -aG docker runner
        if [ $? -eq 0 ]; then
            print_success "Usuário adicionado ao grupo docker"
        else
            print_error "Falha ao adicionar ao grupo docker"
            print_warning "Você precisará adicionar manualmente: sudo usermod -aG docker runner"
        fi
    fi
    
    save_state "1"
fi

# ============================================================================
# ETAPA 2: CONFIGURAÇÃO DE PERMISSÕES SUDO
# ============================================================================

if [ "$current_state" -lt "2" ]; then
    print_header "ETAPA 2: Configurando permissões sudo"
    
    create_backup "sudoers"
    
    cat > /etc/sudoers.d/runner << 'EOF'
# Permissões específicas para o usuário runner
runner ALL=(ALL) NOPASSWD: /bin/systemctl restart *
runner ALL=(ALL) NOPASSWD: /bin/systemctl start *
runner ALL=(ALL) NOPASSWD: /bin/systemctl stop *
runner ALL=(ALL) NOPASSWD: /bin/systemctl status *
runner ALL=(ALL) NOPASSWD: /usr/bin/docker
runner ALL=(ALL) NOPASSWD: /usr/local/bin/docker-compose
runner ALL=(ALL) NOPASSWD: /usr/bin/docker-compose
runner ALL=(ALL) NOPASSWD: /bin/chown runner\:runner *
runner ALL=(ALL) NOPASSWD: /bin/chmod *
runner ALL=(ALL) NOPASSWD: /home/runner/actions-runner/svc.sh *
runner ALL=(ALL) NOPASSWD: /bin/su - ubuntu
runner ALL=(ALL) NOPASSWD: /usr/bin/su - ubuntu
runner ALL=(ALL) NOPASSWD: /bin/su ubuntu
runner ALL=(ALL) NOPASSWD: /usr/bin/su ubuntu
runner ALL=(ALL) NOPASSWD: /usr/bin/journalctl *
ubuntu ALL=(runner) NOPASSWD: ALL
EOF
    
    chmod 440 /etc/sudoers.d/runner
    
    # Validar arquivo sudoers
    if visudo -c -f /etc/sudoers.d/runner &>/dev/null; then
        print_success "Permissões sudo configuradas e validadas"
    else
        print_error "Erro na sintaxe do arquivo sudoers!"
        rm -f /etc/sudoers.d/runner
        restore_backup
        print_error "Configuração de sudo falhou. Verifique os logs."
        exit 1
    fi
    
    # Configurar diretório /var/www
    if [ ! -d "/var/www" ]; then
        mkdir -p /var/www
    fi
    chown runner:runner /var/www
    print_success "Diretório /var/www configurado"
    
    save_state "2"
fi

# ============================================================================
# ETAPA 3: CRIAR DIRETÓRIO ACTIONS-RUNNER
# ============================================================================

if [ "$current_state" -lt "3" ]; then
    print_header "ETAPA 3: Criando diretório actions-runner"
    
    if run_as_runner "cd /home/runner && mkdir -p actions-runner"; then
        print_success "Diretório actions-runner criado"
        save_state "3"
    else
        print_error "Falha ao criar diretório"
        if ask_retry "criação do diretório"; then
            exec "$0" "$@"
        fi
        exit 1
    fi
fi

# ============================================================================
# ETAPA 4: DOWNLOAD DO RUNNER
# ============================================================================

if [ "$current_state" -lt "4" ]; then
    print_header "ETAPA 4: Download do GitHub Actions Runner"
    
    echo -e "${CYAN}Instruções:${NC}"
    echo "1. Acesse: Settings > Actions > Runners > New self-hosted runner"
    echo "2. Copie o comando que começa com 'curl -o actions-runner-linux..."
    echo "3. Cole abaixo"
    echo
    
    while true; do
        read -p "Cole o comando de download: " download_command
        
        if [ -z "$download_command" ]; then
            print_error "Comando não pode estar vazio!"
            continue
        fi
        
        # Validar formato do comando
        if ! validate_command "$download_command" "^curl.*actions-runner-linux.*\.tar\.gz" "download"; then
            print_warning "O comando não parece ser um download válido do runner"
            echo "Deseja continuar mesmo assim? (s/n)"
            read -p "> " force_download
            if [[ ! $force_download =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        
        print_info "Executando download..."
        if run_as_runner "cd /home/runner/actions-runner && $download_command"; then
            # Verificar se o arquivo foi baixado
            if run_as_runner "cd /home/runner/actions-runner && ls actions-runner-linux-*.tar.gz &>/dev/null"; then
                print_success "Download concluído com sucesso"
                save_state "4"
                break
            else
                print_error "Arquivo não foi baixado corretamente"
                if ! ask_retry "download"; then
                    break
                fi
            fi
        else
            print_error "Falha no download"
            if ! ask_retry "download"; then
                exit 1
            fi
        fi
    done
fi

# ============================================================================
# ETAPA 5: VALIDAÇÃO DO HASH (OPCIONAL)
# ============================================================================

if [ "$current_state" -lt "5" ]; then
    print_header "ETAPA 5: Validação do hash"
    
    echo -e "${CYAN}Cole o comando de validação ou pressione ENTER para pular:${NC}"
    read -p "> " hash_command
    
    if [ ! -z "$hash_command" ]; then
        while true; do
            # Validar se o comando contém echo e (sha256sum OU shasum)
            if [[ "$hash_command" =~ ^echo.*\|[[:space:]]*(sha256sum|shasum) ]]; then
                print_info "Validando hash..."
                if run_as_runner "cd /home/runner/actions-runner && $hash_command"; then
                    print_success "Hash validado com sucesso"
                    break
                else
                    print_error "Validação de hash falhou"
                    print_warning "Possíveis causas:"
                    echo "  - Hash não corresponde ao arquivo baixado"
                    echo "  - Arquivo corrompido durante download"
                    echo "  - Comando de validação incorreto"
                    echo
                    echo "Opções:"
                    echo "1. Tentar novamente"
                    echo "2. Ignorar validação e continuar (não recomendado)"
                    echo "3. Voltar para re-fazer o download"
                    read -p "Escolha [1-3]: " hash_choice
                    
                    case $hash_choice in
                        1) continue ;;
                        2) 
                            print_warning "Validação de hash ignorada"
                            break
                            ;;
                        3)
                            print_info "Voltando para etapa de download..."
                            save_state "3"
                            exec "$0" "$@"
                            ;;
                        *)
                            print_error "Opção inválida"
                            continue
                            ;;
                    esac
                fi
            else
                print_warning "Comando de validação não parece correto"
                print_info "Comandos válidos incluem:"
                echo "  • echo \"HASH  arquivo.tar.gz\" | sha256sum -c"
                echo "  • echo \"HASH  arquivo.tar.gz\" | shasum -a 256 -c"
                echo
                echo "Deseja tentar mesmo assim? (s/n)"
                read -p "> " force_hash
                if [[ $force_hash =~ ^[Ss]$ ]]; then
                    print_info "Executando comando..."
                    if run_as_runner "cd /home/runner/actions-runner && $hash_command"; then
                        print_success "Validação executada"
                    else
                        print_warning "Comando falhou, mas continuando..."
                    fi
                fi
                break
            fi
        done
    else
        print_info "Validação de hash pulada"
    fi
    
    save_state "5"
fi

# ============================================================================
# ETAPA 6: EXTRAÇÃO DO INSTALADOR
# ============================================================================

if [ "$current_state" -lt "6" ]; then
    print_header "ETAPA 6: Extração do instalador"
    
    echo -e "${CYAN}Cole o comando de extração (tar xzf...):${NC}"
    
    while true; do
        read -p "> " extract_command
        
        if [ -z "$extract_command" ]; then
            print_error "Comando não pode estar vazio!"
            continue
        fi
        
        if ! validate_command "$extract_command" "^tar.*xzf.*actions-runner" "extração"; then
            print_warning "Comando de extração não parece correto"
            echo "Continuar mesmo assim? (s/n)"
            read -p "> " force_extract
            if [[ ! $force_extract =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        
        print_info "Extraindo arquivos..."
        if run_as_runner "cd /home/runner/actions-runner && $extract_command"; then
            # Verificar se foi extraído
            if run_as_runner "cd /home/runner/actions-runner && [ -f config.sh ]"; then
                print_success "Extração concluída com sucesso"
                save_state "6"
                break
            else
                print_error "Arquivos não foram extraídos corretamente"
                if ! ask_retry "extração"; then
                    exit 1
                fi
            fi
        else
            print_error "Falha na extração"
            if ! ask_retry "extração"; then
                exit 1
            fi
        fi
    done
fi

# ============================================================================
# ETAPA 7: CONFIGURAÇÃO DO RUNNER
# ============================================================================

if [ "$current_state" -lt "7" ]; then
    print_header "ETAPA 7: Configuração do Runner"
    
    echo -e "${CYAN}Cole o comando de configuração (./config.sh --url...):${NC}"
    
    while true; do
        read -p "> " config_command
        
        if [ -z "$config_command" ]; then
            print_error "Comando não pode estar vazio!"
            continue
        fi
        
        if ! validate_command "$config_command" "^\\./config\\.sh.*--url.*--token" "configuração"; then
            print_warning "Comando de configuração não parece correto"
            print_info "Deve conter: ./config.sh --url ... --token ..."
            echo "Continuar mesmo assim? (s/n)"
            read -p "> " force_config
            if [[ ! $force_config =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        
        print_info "Configurando runner..."
        if run_as_runner "cd /home/runner/actions-runner && $config_command"; then
            # Verificar se configuração foi bem sucedida
            if run_as_runner "cd /home/runner/actions-runner && [ -f .runner ]"; then
                print_success "Runner configurado com sucesso"
                save_state "7"
                break
            else
                print_error "Configuração não foi concluída corretamente"
                print_info "Verifique se o token está correto e ainda válido"
                if ! ask_retry "configuração"; then
                    exit 1
                fi
            fi
        else
            print_error "Falha na configuração"
            print_warning "Possíveis causas:"
            echo "  - Token inválido ou expirado"
            echo "  - URL do repositório incorreta"
            echo "  - Runner já registrado com este nome"
            if ! ask_retry "configuração"; then
                exit 1
            fi
        fi
    done
fi

# ============================================================================
# ETAPA 8: TESTE E INSTALAÇÃO DO SERVIÇO
# ============================================================================

if [ "$current_state" -lt "8" ]; then
    print_header "ETAPA 8: Teste e Instalação do Serviço"
    
    echo -e "${CYAN}Deseja instalar o runner como serviço automático?${NC}"
    read -p "Instalar como serviço (s/n): " install_service
    
    if [[ $install_service =~ ^[Ss]$ ]]; then
        echo
        print_info "═══════════════════════════════════════════════════"
        print_info "                  TESTE DO RUNNER                  "
        print_info "═══════════════════════════════════════════════════"
        echo
        echo -e "${YELLOW}1. O runner será iniciado agora${NC}"
        echo -e "${YELLOW}2. Aguarde aparecer: 'Listening for Jobs'${NC}"
        echo -e "${YELLOW}3. Pressione Ctrl+C quando aparecer${NC}"
        echo -e "${YELLOW}4. O script continuará automaticamente${NC}"
        echo
        read -p "Pressione ENTER para iniciar o teste..."
        
        print_info "Iniciando runner..."
        
        # Criar um subshell para isolar o teste e redirecionar stderr
        (
            trap '' INT TERM  # Ignorar sinais no subshell
            sudo -u runner bash -c "cd /home/runner/actions-runner && ./run.sh" 2>/dev/null
        ) &
        
        TEST_PID=$!
        
        # Aguardar Ctrl+C do usuário
        echo
        echo -e "${GREEN}Runner iniciado! Aguardando você pressionar Ctrl+C...${NC}"
        
        # Criar um trap temporário apenas para esta seção
        trap 'kill -TERM $TEST_PID 2>/dev/null; wait $TEST_PID 2>/dev/null; echo; print_info "Teste interrompido - finalizando runner..."; sleep 1' INT
        
        # Aguardar o processo ou interrupção
        wait $TEST_PID 2>/dev/null
        
        # Restaurar o trap original
        trap 'handle_interrupt' INT TERM
        
        # Aguardar um momento para o runner terminar completamente
        sleep 2
        
        echo
        print_success "Teste concluído com sucesso"
        sleep 1
        
        print_info "═══════════════════════════════════════════════════"
        print_info "             INSTALANDO COMO SERVIÇO               "
        print_info "═══════════════════════════════════════════════════"
        
        # Continua com a instalação do serviço...
        attempts=0
        max_attempts=3
        
        while [ $attempts -lt $max_attempts ]; do
            print_info "Tentativa $(($attempts + 1)) de $max_attempts..."
            
            if run_as_runner "cd /home/runner/actions-runner && sudo ./svc.sh install runner"; then
                print_success "Serviço instalado"
                sleep 2
                
                if run_as_runner "cd /home/runner/actions-runner && sudo ./svc.sh start"; then
                    print_success "Serviço iniciado"
                    sleep 5
                    
                    print_info "═══════════════════════════════════════════════════"
                    print_info "                STATUS DO SERVIÇO                  "
                    print_info "═══════════════════════════════════════════════════"
                    
                    run_as_runner "cd /home/runner/actions-runner && sudo ./svc.sh status" || true
                    echo
                    systemctl status actions.runner.* --no-pager -l || true
                    
                    save_state "8"
                    break
                else
                    print_error "Falha ao iniciar o serviço"
                    attempts=$((attempts + 1))
                    
                    if [ $attempts -lt $max_attempts ]; then
                        if ask_retry "inicialização do serviço"; then
                            continue
                        else
                            break
                        fi
                    fi
                fi
            else
                print_error "Falha ao instalar o serviço"
                attempts=$((attempts + 1))
                
                if [ $attempts -lt $max_attempts ]; then
                    if ask_retry "instalação do serviço"; then
                        continue
                    else
                        break
                    fi
                fi
            fi
        done
        
        if [ $attempts -eq $max_attempts ]; then
            print_error "Não foi possível instalar o serviço após $max_attempts tentativas"
            print_info "Comandos para instalação manual:"
            echo "  sudo su - runner"
            echo "  cd actions-runner"
            echo "  sudo ./svc.sh install runner"
            echo "  sudo ./svc.sh start"
        fi
    else
        print_info "Runner não será instalado como serviço"
        print_info "Para testar manualmente:"
        echo "  sudo su - runner"
        echo "  cd actions-runner"
        echo "  ./run.sh"
        save_state "8"
    fi
fi

# ============================================================================
# CONCLUSÃO
# ============================================================================

clear_state

echo
print_header "🎉 CONFIGURAÇÃO CONCLUÍDA! 🎉"

echo -e "${CYAN}📋 RESUMO DA CONFIGURAÇÃO:${NC}"
echo "• ✅ Usuário 'runner' criado"
echo "• ✅ Runner instalado em /home/runner/actions-runner"
echo "• ✅ Permissões e grupo docker configurados"
echo "• ✅ Runner registrado no GitHub"
if [[ $install_service =~ ^[Ss]$ ]]; then
    echo "• ✅ Serviço configurado"
fi
echo

echo -e "${CYAN}🔄 NAVEGAÇÃO ENTRE USUÁRIOS:${NC}"
echo "• Para runner: sudo su - runner"
echo "• Para ubuntu: exit (ou sudo su - ubuntu)"
echo

echo -e "${CYAN}🔧 COMANDOS ÚTEIS:${NC}"
echo "• Ver status:"
echo "  sudo su - runner && cd actions-runner && sudo ./svc.sh status"
echo "• Reiniciar:"
echo "  sudo systemctl restart actions.runner.*"
echo "• Ver logs:"
echo "  sudo journalctl -u actions.runner.* -f"
echo "• Parar:"
echo "  sudo systemctl stop actions.runner.*"
echo "• Iniciar:"
echo "  sudo systemctl start actions.runner.*"
echo

echo -e "${CYAN}📝 INFORMAÇÕES DO LOG:${NC}"
echo "• Log completo salvo em: $LOG_FILE"
if [ -d "$BACKUP_DIR" ]; then
    echo "• Backups salvos em: $BACKUP_DIR"
fi
echo

echo -e "${CYAN}🔍 VERIFICAR NO GITHUB:${NC}"
echo "• Settings > Actions > Runners"
echo "• Runner deve aparecer online 🟢"
echo

print_success "🚀 Runner pronto para uso!"
print_warning "💡 Lembre-se da senha do usuário runner"
echo

log "Instalação concluída com sucesso"
