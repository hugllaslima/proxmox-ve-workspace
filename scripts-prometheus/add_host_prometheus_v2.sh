#!/bin/bash

#########################################################
# Script de Adição de Host no Prometheus - VERSÃO 2.0
# Autor: Sistema de Monitoramento
# Data: 2025-10-30
# Descrição: Adiciona hosts com suporte multi-linguagem e banco de dados
#########################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis
PROMETHEUS_FILE="/opt/app-prometheus/prometheus/prometheus.yml"
BACKUP_DIR="/opt/app-prometheus/prometheus/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Variáveis para banco de dados
HAS_DATABASE=false
DB_TYPE=""
DB_EXPORTER_PORT=""

# Variáveis para linguagem
APP_LANGUAGE=""
APP_METRICS_PREFIX=""

#########################################################
# Funções de Output
#########################################################

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  ADICIONAR HOST NO PROMETHEUS v2.0${NC}"
    echo -e "${BLUE}  Multi-Linguagem + Banco de Dados${NC}"
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

print_tip() {
    echo -e "${CYAN}💡 DICA: $1${NC}"
}

#########################################################
# Funções de Validação
#########################################################

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

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

#########################################################
# Funções de Backup
#########################################################

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

#########################################################
# Funções de Detecção de Linguagem
#########################################################

select_language() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Selecione a linguagem/framework da aplicação:"
    echo ""
    echo -e "  ${CYAN}1)${NC} Python (Flask/Django/FastAPI)"
    echo -e "  ${CYAN}2)${NC} Node.js (Express/NestJS)"
    echo -e "  ${CYAN}3)${NC} Java (Spring Boot)"
    echo -e "  ${CYAN}4)${NC} PHP (Laravel/Symfony)"
    echo -e "  ${CYAN}5)${NC} TypeScript (Node.js)"
    echo -e "  ${CYAN}6)${NC} Go"
    echo -e "  ${CYAN}7)${NC} .NET (C#)"
    echo -e "  ${CYAN}8)${NC} Ruby (Rails)"
    echo -e "  ${CYAN}9)${NC} Rust"
    echo ""
    
    while true; do
        read -p "Digite o número da opção: " lang_choice
        
        case $lang_choice in
            1)
                APP_LANGUAGE="python"
                APP_METRICS_PREFIX="flask"
                METRICS_PATH="/metrics"
                print_tip "Para Flask, adicione ao requirements.txt: prometheus-flask-exporter"
                break
                ;;
            2)
                APP_LANGUAGE="nodejs"
                APP_METRICS_PREFIX="nodejs"
                METRICS_PATH="/metrics"
                print_tip "Para Node.js, instale: npm install prom-client"
                break
                ;;
            3)
                APP_LANGUAGE="java"
                APP_METRICS_PREFIX="jvm"
                METRICS_PATH="/actuator/prometheus"
                print_tip "Para Spring Boot, adicione: spring-boot-starter-actuator + micrometer-registry-prometheus"
                break
                ;;
            4)
                APP_LANGUAGE="php"
                APP_METRICS_PREFIX="php"
                METRICS_PATH="/metrics"
                print_tip "Para PHP, use: promphp/prometheus_client_php"
                break
                ;;
            5)
                APP_LANGUAGE="typescript"
                APP_METRICS_PREFIX="nodejs"
                METRICS_PATH="/metrics"
                print_tip "Para TypeScript, instale: npm install prom-client"
                break
                ;;
            6)
                APP_LANGUAGE="go"
                APP_METRICS_PREFIX="go"
                METRICS_PATH="/metrics"
                print_tip "Para Go, use: github.com/prometheus/client_golang"
                break
                ;;
            7)
                APP_LANGUAGE="dotnet"
                APP_METRICS_PREFIX="dotnet"
                METRICS_PATH="/metrics"
                print_tip "Para .NET, use: prometheus-net"
                break
                ;;
            8)
                APP_LANGUAGE="ruby"
                APP_METRICS_PREFIX="ruby"
                METRICS_PATH="/metrics"
                print_tip "Para Ruby, adicione: gem 'prometheus-client'"
                break
                ;;
            9)
                APP_LANGUAGE="rust"
                APP_METRICS_PREFIX="rust"
                METRICS_PATH="/metrics"
                print_tip "Para Rust, use: prometheus crate"
                break
                ;;
            *)
                print_error "Opção inválida! Escolha entre 1 e 9."
                ;;
        esac
    done
    
    echo ""
    print_success "Linguagem selecionada: $APP_LANGUAGE"
    print_info "Prefixo de métricas: ${APP_METRICS_PREFIX}_*"
    print_info "Caminho padrão: $METRICS_PATH"
    echo ""
}

#########################################################
# Funções de Banco de Dados
#########################################################

check_database() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Esta aplicação utiliza banco de dados?"
    echo ""
    
    while true; do
        read -p "Tem banco de dados? (s/n): " has_db
        case $has_db in
            [Ss]*)
                HAS_DATABASE=true
                select_database_type
                break
                ;;
            [Nn]*)
                HAS_DATABASE=false
                print_info "Sem monitoramento de banco de dados."
                break
                ;;
            *)
                print_error "Responda 's' para sim ou 'n' para não."
                ;;
        esac
    done
}

select_database_type() {
    echo ""
    print_info "Selecione o tipo de banco de dados:"
    echo ""
    echo -e "  ${CYAN}1)${NC} PostgreSQL"
    echo -e "  ${CYAN}2)${NC} MySQL/MariaDB"
    echo -e "  ${CYAN}3)${NC} MongoDB"
    echo -e "  ${CYAN}4)${NC} Redis"
    echo -e "  ${CYAN}5)${NC} SQL Server"
    echo -e "  ${CYAN}6)${NC} Oracle"
    echo ""
    
    while true; do
        read -p "Digite o número da opção: " db_choice
        
        case $db_choice in
            1)
                DB_TYPE="postgresql"
                DB_EXPORTER_PORT="9187"
                print_tip "Use o exporter: prometheuscommunity/postgres-exporter"
                break
                ;;
            2)
                DB_TYPE="mysql"
                DB_EXPORTER_PORT="9104"
                print_tip "Use o exporter: prom/mysqld-exporter"
                break
                ;;
            3)
                DB_TYPE="mongodb"
                DB_EXPORTER_PORT="9216"
                print_tip "Use o exporter: percona/mongodb_exporter"
                break
                ;;
            4)
                DB_TYPE="redis"
                DB_EXPORTER_PORT="9121"
                print_tip "Use o exporter: oliver006/redis_exporter"
                break
                ;;
            5)
                DB_TYPE="sqlserver"
                DB_EXPORTER_PORT="9399"
                print_tip "Use o exporter: prometheus-community/sql_exporter"
                break
                ;;
            6)
                DB_TYPE="oracle"
                DB_EXPORTER_PORT="9161"
                print_tip "Use o exporter: iamseth/oracledb_exporter"
                break
                ;;
            *)
                print_error "Opção inválida! Escolha entre 1 e 6."
                ;;
        esac
    done
    
    echo ""
    print_success "Banco de dados: $DB_TYPE"
    print_info "Porta do exporter: $DB_EXPORTER_PORT"
    echo ""
}

#########################################################
# Função de Coleta de Informações
#########################################################

collect_info() {
    echo ""
    print_header
    
    # Selecionar linguagem
    select_language
    
    # Verificar banco de dados
    check_database
    
    # Nome do Serviço
    while true; do
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "1. Nome do Serviço"
        echo -e "   Exemplo: ${YELLOW}Sistema de Vendas${NC}, ${YELLOW}API de Usuários${NC}"
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
        SUGGESTED_JOB=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
        echo -e "   Sugestão: ${YELLOW}${SUGGESTED_JOB}_${APP_LANGUAGE}_metrics${NC}"
        read -p "Digite o job_name da aplicação: " JOB_NAME_APP
        
        if [ -z "$JOB_NAME_APP" ]; then
            JOB_NAME_APP="${SUGGESTED_JOB}_${APP_LANGUAGE}_metrics"
            print_success "Usando sugestão: $JOB_NAME_APP"
            break
        fi
        
        if confirm_input "Job Name da Aplicação" "$JOB_NAME_APP"; then
            break
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
        echo -e "   Exemplo: ${YELLOW}3000${NC}, ${YELLOW}8080${NC}, ${YELLOW}5000${NC}"
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
        echo -e "   Padrão: ${YELLOW}http${NC}"
        echo -e "   ${GREEN}Pressione ENTER para usar 'http'${NC}"
        read -p "Digite o protocolo (http/https): " SCHEME
        
        if [ -z "$SCHEME" ]; then
            SCHEME="http"
            print_success "Usando protocolo padrão: http"
            break
        fi
        
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
    
    # Metrics Path (já sugerido pela linguagem)
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "6. Caminho das métricas"
        echo -e "   Sugerido para $APP_LANGUAGE: ${YELLOW}$METRICS_PATH${NC}"
        echo -e "   ${GREEN}Pressione ENTER para usar o padrão${NC}"
        read -p "Digite o caminho das métricas: " CUSTOM_METRICS_PATH
        
        if [ -z "$CUSTOM_METRICS_PATH" ]; then
            print_success "Usando caminho padrão: $METRICS_PATH"
            break
        fi
        
        METRICS_PATH="$CUSTOM_METRICS_PATH"
        
        if [[ ! $METRICS_PATH =~ ^/ ]]; then
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
        SUGGESTED_INSTANCE=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        echo -e "   Sugestão: ${YELLOW}${SUGGESTED_INSTANCE}-app${NC}"
        read -p "Digite o nome da instância: " INSTANCE_NAME_APP
        
        if [ -z "$INSTANCE_NAME_APP" ]; then
            INSTANCE_NAME_APP="${SUGGESTED_INSTANCE}-app"
            print_success "Usando sugestão: $INSTANCE_NAME_APP"
            break
        fi
        
        if confirm_input "Nome da Instância da Aplicação" "$INSTANCE_NAME_APP"; then
            break
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
        print_info "9. Job Name para métricas do SO"
        SUGGESTED_VM_JOB=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
        echo -e "   Sugestão: ${YELLOW}${SUGGESTED_VM_JOB}_vm_metrics${NC}"
        read -p "Digite o job_name do SO: " JOB_NAME_VM
        
        if [ -z "$JOB_NAME_VM" ]; then
            JOB_NAME_VM="${SUGGESTED_VM_JOB}_vm_metrics"
            print_success "Usando sugestão: $JOB_NAME_VM"
            break
        fi
        
        if confirm_input "Job Name do SO" "$JOB_NAME_VM"; then
            break
        fi
    done
    
    # Instance Name - VM
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "10. Nome da instância da VM"
        echo -e "   Sugestão: ${YELLOW}${SUGGESTED_INSTANCE}-vm${NC}"
        read -p "Digite o nome da instância da VM: " INSTANCE_NAME_VM
        
        if [ -z "$INSTANCE_NAME_VM" ]; then
            INSTANCE_NAME_VM="${SUGGESTED_INSTANCE}-vm"
            print_success "Usando sugestão: $INSTANCE_NAME_VM"
            break
        fi
        
        if confirm_input "Nome da Instância da VM" "$INSTANCE_NAME_VM"; then
            break
        fi
    done
    
    # Environment - VM
    while true; do
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "11. Ambiente da VM"
        echo -e "   Usar o mesmo da aplicação? ${YELLOW}$ENV_APP${NC}"
        echo -e "   ${GREEN}Pressione ENTER para usar o mesmo${NC}"
        read -p "Digite o ambiente (staging/production): " ENV_VM
        
        if [ -z "$ENV_VM" ]; then
            ENV_VM="$ENV_APP"
            print_success "Usando mesmo ambiente: $ENV_VM"
            break
        fi
        
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

#########################################################
# Função de Resumo
#########################################################

show_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}RESUMO DAS CONFIGURAÇÕES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Serviço:${NC} $SERVICE_NAME"
    echo -e "${YELLOW}Linguagem:${NC} $APP_LANGUAGE"
    echo -e "${YELLOW}Prefixo de Métricas:${NC} ${APP_METRICS_PREFIX}_*"
    echo ""
    echo -e "${MAGENTA}═══ Métricas da Aplicação ═══${NC}"
    echo "  Job Name: $JOB_NAME_APP"
    echo "  Target: ${APP_IP}:${APP_PORT}"
    echo "  Scheme: $SCHEME"
    echo "  Metrics Path: $METRICS_PATH"
    echo "  Instance: $INSTANCE_NAME_APP"
    echo "  Environment: $ENV_APP"
    echo ""
    echo -e "${MAGENTA}═══ Métricas do Sistema Operacional ═══${NC}"
    echo "  Job Name: $JOB_NAME_VM"
    echo "  Target: ${APP_IP}:9100"
    echo "  Instance: $INSTANCE_NAME_VM"
    echo "  Environment: $ENV_VM"
    
    if [ "$HAS_DATABASE" = true ]; then
        echo ""
        echo -e "${MAGENTA}═══ Métricas do Banco de Dados ═══${NC}"
        echo "  Tipo: $DB_TYPE"
        echo "  Job Name: ${SUGGESTED_JOB}_${DB_TYPE}_metrics"
        echo "  Target: ${APP_IP}:${DB_EXPORTER_PORT}"
        echo "  Instance: ${SUGGESTED_INSTANCE}-${DB_TYPE}"
        echo "  Environment: $ENV_APP"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

#########################################################
# Função para Adicionar Configuração
#########################################################

add_to_prometheus() {
    print_info "Adicionando configuração ao prometheus.yml..."
    
    # Adicionar comentário e métricas da aplicação
    cat >> "$PROMETHEUS_FILE" << EOF

  # --- Monitoramento do $SERVICE_NAME ($APP_LANGUAGE) ---
  - job_name: '$JOB_NAME_APP'
    metrics_path: '$METRICS_PATH'
    scheme: '$SCHEME'
    static_configs:
      - targets: ['${APP_IP}:${APP_PORT}']
        labels:
          instance: '$INSTANCE_NAME_APP'
          environment: '$ENV_APP'
          language: '$APP_LANGUAGE'
          service: '$SERVICE_NAME'
    metric_relabel_configs:
      # Remover métricas genéricas do Go se não for aplicação Go
EOF

    if [ "$APP_LANGUAGE" != "go" ]; then
        cat >> "$PROMETHEUS_FILE" << EOF
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop
      - source_labels: [__name__]
        regex: 'promhttp_.*'
        action: drop
EOF
    fi

    # Adicionar métricas da VM
    cat >> "$PROMETHEUS_FILE" << EOF

  - job_name: '$JOB_NAME_VM'
    static_configs:
      - targets: ['${APP_IP}:9100']
        labels:
          instance: '$INSTANCE_NAME_VM'
          environment: '$ENV_VM'
          service: '$SERVICE_NAME'
EOF

    # Adicionar métricas do banco de dados se existir
    if [ "$HAS_DATABASE" = true ]; then
        DB_JOB_NAME="${SUGGESTED_JOB}_${DB_TYPE}_metrics"
        DB_INSTANCE_NAME="${SUGGESTED_INSTANCE}-${DB_TYPE}"
        
        cat >> "$PROMETHEUS_FILE" << EOF

  - job_name: '$DB_JOB_NAME'
    static_configs:
      - targets: ['${APP_IP}:${DB_EXPORTER_PORT}']
        labels:
          instance: '$DB_INSTANCE_NAME'
          environment: '$ENV_APP'
          database_type: '$DB_TYPE'
          service: '$SERVICE_NAME'
EOF
    fi

    if [ $? -eq 0 ]; then
        print_success "Configuração adicionada com sucesso!"
        return 0
    else
        print_error "Falha ao adicionar configuração!"
        return 1
    fi
}

#########################################################
# Função para Validar YAML
#########################################################

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

#########################################################
# Função para Recarregar Prometheus
#########################################################

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
# Função para Mostrar Instruções Finais
#########################################################

show_final_instructions() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 PRÓXIMOS PASSOS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    case $APP_LANGUAGE in
        python)
            echo -e "${YELLOW}1. Adicione ao requirements.txt:${NC}"
            echo "   prometheus-flask-exporter==0.23.0"
            echo ""
            echo -e "${YELLOW}2. No seu app.py:${NC}"
            echo "   from prometheus_flask_exporter import PrometheusMetrics"
            echo "   metrics = PrometheusMetrics(app)"
            ;;
        nodejs|typescript)
            echo -e "${YELLOW}1. Instale a biblioteca:${NC}"
            echo "   npm install prom-client"
            echo ""
            echo -e "${YELLOW}2. No seu código:${NC}"
            echo "   const client = require('prom-client');"
            echo "   const register = new client.Registry();"
            ;;
        java)
            echo -e "${YELLOW}1. Adicione ao pom.xml:${NC}"
            echo "   <dependency>"
            echo "     <groupId>io.micrometer</groupId>"
            echo "     <artifactId>micrometer-registry-prometheus</artifactId>"
            echo "   </dependency>"
            ;;
    esac
    
    if [ "$HAS_DATABASE" = true ]; then
        echo ""
        echo -e "${YELLOW}3. Configure o exporter do banco de dados:${NC}"
        case $DB_TYPE in
            postgresql)
                echo "   docker run -d \\"
                echo "     --name postgres-exporter \\"
                echo "     -e DATA_SOURCE_NAME='postgresql://user:pass@${APP_IP}:5432/db?sslmode=disable' \\"
                echo "     -p ${DB_EXPORTER_PORT}:9187 \\"
                echo "     prometheuscommunity/postgres-exporter"
                ;;
            mysql)
                echo "   docker run -d \\"
                echo "     --name mysql-exporter \\"
                echo "     -e DATA_SOURCE_NAME='user:pass@(${APP_IP}:3306)/' \\"
                echo "     -p ${DB_EXPORTER_PORT}:9104 \\"
                echo "     prom/mysqld-exporter"
                ;;
        esac
    fi
    
    echo ""
    echo -e "${YELLOW}4. Instale o Node Exporter na VM:${NC}"
    echo "   docker run -d \\"
    echo "     --name node-exporter \\"
    echo "     --net=host \\"
    echo "     --pid=host \\"
    echo "     -v /:/host:ro,rslave \\"
    echo "     quay.io/prometheus/node-exporter:latest \\"
    echo "     --path.rootfs=/host"
    
    echo ""
    echo -e "${GREEN}5. Verifique as métricas:${NC}"
    echo "   curl http://${APP_IP}:${APP_PORT}${METRICS_PATH}"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
                    
                    # Mostrar instruções finais
                    show_final_instructions
                    
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
