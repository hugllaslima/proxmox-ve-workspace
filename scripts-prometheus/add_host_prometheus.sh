#!/bin/bash

#########################################################
# Script de Adição de Host no Prometheus
# Autor: Sistema de Monitoramento
# Data: 2025-10-29
# Descrição: Adiciona novos hosts ao prometheus.yml
#########################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
PROMETHEUS_FILE="/opt/app-prometheus/prometheus/prometheus.yml"
BACKUP_DIR="/opt/app-prometheus/prometheus/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

#########################################################
# Funções
#########################################################

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  ADICIONAR HOST NO PROMETHEUS${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
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

# Função para validar porta
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Função para confirmar entrada
confirm_input() {
    local prompt="$1"
    local value="$2"
    
    while true; do
        echo -e "${YELLOW}${prompt}${NC}"
        echo -e "Valor informado: ${GREEN}${value}${NC}"
        read -p "Está correto? (s/n): " confirm
        case $confirm in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Por favor, responda 's' para sim ou 'n' para não.";;
        esac
    done
}

# Função para criar backup
create_backup() {
    print_info "Criando backup do arquivo prometheus.yml..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    cp "$PROMETHEUS_FILE" "$BACKUP_DIR/prometheus_${TIMESTAMP}.yml"
    
    if [ $? -eq 0 ]; then
        print_success "Backup criado: $BACKUP_DIR/prometheus_${TIMESTAMP}.yml"
        return 0
    else
        print_error "Falha ao criar backup!"
        return 1
    fi
}

# Função para coletar informações
collect_info() {
    echo ""
    print_header
    
    # Nome do Serviço
    while true; do
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "1. Nome do Serviço (será usado no comentário)"
        echo -e "   Exemplo: ${YELLOW}Grafana${NC}, ${YELLOW}PostgreSQL${NC}, ${YELLOW}Redis${NC}"
        read -p "Digite o nome do serviço: " SERVICE_NAME
        
        if [ -n "$SERVICE_NAME" ]; then
            if confirm_input "Nome do Serviço" "$SERVICE_NAME"; then
                break
            fi
        else
            print_error "Nome do serviço não pode ser vazio!"
        fi
    done
    
    # Job Name - App Metrics
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "2. Job Name para métricas da aplicação"
        echo -e "   Exemplo: ${YELLOW}grafana_app_metrics${NC}, ${YELLOW}postgres_app_metrics${NC}"
        read -p "Digite o job_name da aplicação: " JOB_NAME_APP
        
        if [ -n "$JOB_NAME_APP" ]; then
            if confirm_input "Job Name da Aplicação" "$JOB_NAME_APP"; then
                break
            fi
        else
            print_error "Job name não pode ser vazio!"
        fi
    done
    
    # IP da Aplicação
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "3. IP do host da aplicação"
        echo -e "   Exemplo: ${YELLOW}10.10.1.225${NC}, ${YELLOW}192.168.1.100${NC}"
        read -p "Digite o IP: " APP_IP
        
        if validate_ip "$APP_IP"; then
            if confirm_input "IP da Aplicação" "$APP_IP"; then
                break
            fi
        else
            print_error "IP inválido! Use o formato: xxx.xxx.xxx.xxx"
        fi
    done
    
    # Porta da Aplicação
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "4. Porta da aplicação"
        echo -e "   Exemplo: ${YELLOW}3000${NC}, ${YELLOW}8080${NC}, ${YELLOW}9090${NC}"
        read -p "Digite a porta: " APP_PORT
        
        if validate_port "$APP_PORT"; then
            if confirm_input "Porta da Aplicação" "$APP_PORT"; then
                break
            fi
        else
            print_error "Porta inválida! Use um número entre 1 e 65535"
        fi
    done
    
    # Protocolo (Scheme)
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "5. Protocolo de comunicação"
        echo -e "   Opções: ${YELLOW}http${NC} ou ${YELLOW}https${NC}"
        echo -e "   Exemplo: Para aplicações sem SSL use ${YELLOW}http${NC}, com SSL use ${YELLOW}https${NC}"
        read -p "Digite o protocolo (http/https): " SCHEME
        
        case $SCHEME in
            http|https)
                if confirm_input "Protocolo" "$SCHEME"; then
                    break
                fi
                ;;
            *)
                print_error "Protocolo inválido! Use 'http' ou 'https'"
                ;;
        esac
    done
    
    # Metrics Path
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "6. Caminho das métricas (metrics path)"
        echo -e "   Padrão: ${YELLOW}/metrics${NC}"
        echo -e "   Outros exemplos: ${YELLOW}/actuator/prometheus${NC}, ${YELLOW}/api/metrics${NC}, ${YELLOW}/stats${NC}"
        echo -e "   ${GREEN}Pressione ENTER para usar o padrão '/metrics'${NC}"
        read -p "Digite o caminho das métricas: " METRICS_PATH
        
        # Se vazio, usa o padrão
        if [ -z "$METRICS_PATH" ]; then
            METRICS_PATH="/metrics"
            print_success "Usando caminho padrão: /metrics"
            break
        fi
        
        # Validar se começa com /
        if [[ ! $METRICS_PATH =~ ^/ ]]; then
            print_warning "O caminho deve começar com '/'. Adicionando automaticamente..."
            METRICS_PATH="/$METRICS_PATH"
        fi
        
        if confirm_input "Caminho das Métricas" "$METRICS_PATH"; then
            break
        fi
    done
    
    # Instance Name - App
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "7. Nome da instância da aplicação"
        echo -e "   Exemplo: ${YELLOW}grafana-service${NC}, ${YELLOW}postgres-primary${NC}"
        read -p "Digite o nome da instância: " INSTANCE_NAME_APP
        
        if [ -n "$INSTANCE_NAME_APP" ]; then
            if confirm_input "Nome da Instância da Aplicação" "$INSTANCE_NAME_APP"; then
                break
            fi
        fi
    done
    
    # Environment - App
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "8. Ambiente da aplicação"
        echo -e "   Opções: ${YELLOW}staging${NC} ou ${YELLOW}production${NC}"
        read -p "Digite o ambiente (staging/production): " ENV_APP
        
        case $ENV_APP in
            staging|production)
                if confirm_input "Ambiente da Aplicação" "$ENV_APP"; then
                    break
                fi
                ;;
            *)
                print_error "Ambiente inválido! Use 'staging' ou 'production'"
                ;;
        esac
    done
    
    # Job Name - VM Metrics
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "9. Job Name para métricas do sistema operacional"
        echo -e "   Exemplo: ${YELLOW}grafana_vm_os_metrics${NC}, ${YELLOW}postgres_vm_os_metrics${NC}"
        read -p "Digite o job_name do SO: " JOB_NAME_VM
        
        if [ -n "$JOB_NAME_VM" ]; then
            if confirm_input "Job Name do SO" "$JOB_NAME_VM"; then
                break
            fi
        fi
    done
    
    # Instance Name - VM
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "10. Nome da instância da VM"
        echo -e "   Exemplo: ${YELLOW}grafana-vm${NC}, ${YELLOW}postgres-vm${NC}"
        read -p "Digite o nome da instância da VM: " INSTANCE_NAME_VM
        
        if [ -n "$INSTANCE_NAME_VM" ]; then
            if confirm_input "Nome da Instância da VM" "$INSTANCE_NAME_VM"; then
                break
            fi
        fi
    done
    
    # Environment - VM
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "11. Ambiente da VM"
        echo -e "   Opções: ${YELLOW}staging${NC} ou ${YELLOW}production${NC}"
        read -p "Digite o ambiente (staging/production): " ENV_VM
        
        case $ENV_VM in
            staging|production)
                if confirm_input "Ambiente da VM" "$ENV_VM"; then
                    break
                fi
                ;;
            *)
                print_error "Ambiente inválido! Use 'staging' ou 'production'"
                ;;
        esac
    done
}

# Função para exibir resumo
show_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}RESUMO DAS CONFIGURAÇÕES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Serviço:${NC} $SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}Métricas da Aplicação:${NC}"
    echo "  Job Name: $JOB_NAME_APP"
    echo "  Target: ${APP_IP}:${APP_PORT}"
    echo "  Scheme: $SCHEME"
    echo "  Metrics Path: $METRICS_PATH"
    echo "  Instance: $INSTANCE_NAME_APP"
    echo "  Environment: $ENV_APP"
    echo ""
    echo -e "${YELLOW}Métricas do Sistema Operacional:${NC}"
    echo "  Job Name: $JOB_NAME_VM"
    echo "  Target: ${APP_IP}:9100"
    echo "  Instance: $INSTANCE_NAME_VM"
    echo "  Environment: $ENV_VM"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Função para adicionar configuração
add_to_prometheus() {
    print_info "Adicionando configuração ao prometheus.yml..."
    
    # Criar conteúdo a ser adicionado
    cat >> "$PROMETHEUS_FILE" << EOF

  # --- Monitoramento do $SERVICE_NAME ---
  - job_name: '$JOB_NAME_APP'
    metrics_path: '$METRICS_PATH'
    scheme: '$SCHEME'
    static_configs:
      - targets: ['${APP_IP}:${APP_PORT}']
        labels:
          instance: '$INSTANCE_NAME_APP'
          environment: '$ENV_APP'

  - job_name: '$JOB_NAME_VM'
    static_configs:
      - targets: ['${APP_IP}:9100']
        labels:
          instance: '$INSTANCE_NAME_VM'
          environment: '$ENV_VM'
EOF

    if [ $? -eq 0 ]; then
        print_success "Configuração adicionada com sucesso!"
        return 0
    else
        print_error "Falha ao adicionar configuração!"
        return 1
    fi
}

# Função para validar YAML
validate_yaml() {
    print_info "Validando sintaxe do arquivo YAML..."
    
    if command -v promtool &> /dev/null; then
        promtool check config "$PROMETHEUS_FILE" &> /dev/null
        if [ $? -eq 0 ]; then
            print_success "Arquivo YAML válido!"
            return 0
        else
            print_error "Arquivo YAML inválido!"
            print_warning "Restaurando backup..."
            cp "$BACKUP_DIR/prometheus_${TIMESTAMP}.yml" "$PROMETHEUS_FILE"
            return 1
        fi
    else
        print_warning "promtool não encontrado. Pulando validação."
        return 0
    fi
}

# Função para recarregar Prometheus
reload_prometheus() {
    echo ""
    read -p "Deseja recarregar o Prometheus agora? (s/n): " reload
    
    case $reload in
        [Ss]*)
            print_info "Recarregando Prometheus..."
            
            # Tenta reload via API
            if curl -X POST http://localhost:9090/-/reload &> /dev/null; then
                print_success "Prometheus recarregado via API!"
            else
                print_warning "Não foi possível recarregar via API."
                print_info "Execute manualmente: docker restart prometheus"
                print_info "Ou: systemctl restart prometheus"
            fi
            ;;
        [Nn]*)
            print_warning "Lembre-se de recarregar o Prometheus manualmente!"
            ;;
    esac
}

#########################################################
# Script Principal
#########################################################

main() {
    # Verificar se o arquivo existe
    if [ ! -f "$PROMETHEUS_FILE" ]; then
        print_error "Arquivo prometheus.yml não encontrado em: $PROMETHEUS_FILE"
        exit 1
    fi
    
    # Verificar permissões
    if [ ! -w "$PROMETHEUS_FILE" ]; then
        print_error "Sem permissão de escrita no arquivo prometheus.yml"
        print_info "Execute com sudo ou ajuste as permissões"
        exit 1
    fi
    
    # Coletar informações
    collect_info
    
    # Mostrar resumo
    show_summary
    
    # Confirmar adição
    read -p "Deseja adicionar esta configuração? (s/n): " final_confirm
    
    case $final_confirm in
        [Ss]*)
            # Criar backup
            if ! create_backup; then
                print_error "Abortando operação!"
                exit 1
            fi
            
            # Adicionar configuração
            if add_to_prometheus; then
                # Validar YAML
                if validate_yaml; then
                    print_success "Operação concluída com sucesso!"
                    
                    # Recarregar Prometheus
                    reload_prometheus
                    
                    echo ""
                    print_success "✓ Host adicionado ao monitoramento!"
                    print_info "Backup salvo em: $BACKUP_DIR/prometheus_${TIMESTAMP}.yml"
                else
                    print_error "Configuração revertida devido a erro de validação!"
                    exit 1
                fi
            else
                exit 1
            fi
            ;;
        [Nn]*)
            print_warning "Operação cancelada pelo usuário."
            exit 0
            ;;
        *)
            print_error "Resposta inválida. Operação cancelada."
            exit 1
            ;;
    esac
}

# Executar script
main
