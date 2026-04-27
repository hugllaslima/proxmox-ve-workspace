#!/bin/bash

################################################################################
#                                                                              #
#                   INSTALAÇÃO AUTOMATIZADA DO ZABBIX AGENT 7.2                #
#                          Proxmox VE Automation Suite                         #
#                                                                              #
################################################################################
#
# Script: install_zabbix_agent_7.2_ubuntu.sh
# Versão: 1.1
# Autor: Hugllas Lima
# Data: 2025-10-24
# Licença: MIT
#
# DESCRIÇÃO:
#   Automatiza a instalação e configuração completa do Zabbix Agent 7.2 em
#   sistemas Ubuntu 24.04 LTS para ambientes híbridos (Cloud + On-Premise).
#   
# FUNCIONALIDADES:
#   ✓ Instalação automatizada do Zabbix Agent 7.2 oficial
#   ✓ Configuração interativa com validação de dados
#   ✓ Suporte para ambientes híbridos (Cloud/On-Premise)
#   ✓ Validação de conectividade com Zabbix Server
#   ✓ Backup automático de configurações
#   ✓ Logs detalhados de instalação
#   ✓ Verificação de sistema operacional
#   ✓ Configuração de hostname personalizado
#   ✓ Suporte para redes adicionais/gateways
#   ✓ Exemplos práticos para cada campo
#   ✓ Tratamento robusto de erros
#
# COMPATIBILIDADE:
#   - Ubuntu 24.04 LTS (recomendado)
#   - Outras versões Ubuntu (com aviso)
#   - Zabbix Server 7.2+
#
# PRÉ-REQUISITOS:
#   - Sistema Ubuntu com acesso root (sudo)
#   - Conexão com internet ativa
#   - Zabbix Server configurado e acessível
#   - Portas de firewall liberadas (10050/10051)
#
# AMBIENTE HÍBRIDO - REQUISITOS:
#   On-Premise:
#     - Firewall local configurado
#     - IP público disponível
#     - Port Forwarding configurado (porta 10060 recomendada)
#     - Políticas de segurança aplicadas
#   
#   Cloud (Zabbix Server):
#     - Zabbix Server 7.2 instalado
#     - Security Groups configurados
#     - Regras de entrada liberadas
#     - Port Forwarding configurado
#
# USO:
#   sudo bash install_zabbix_agent_7.2_ubuntu.sh
#
# PARÂMETROS COLETADOS INTERATIVAMENTE:
#   - IP do Zabbix Server
#   - Porta do Zabbix Server (padrão: 10051)
#   - Hostname do Agent
#   - Subnet/Gateway adicional (opcional)
#
# ARQUIVOS GERADOS:
#   - /var/log/zabbix_agent_install_YYYYMMDD_HHMMSS.log
#   - /root/zabbix_agent_install_summary_YYYYMMDD_HHMMSS.txt
#   - /etc/zabbix/zabbix_agentd.conf.backup.YYYYMMDD_HHMMSS
#
# PRÓXIMOS PASSOS PÓS-INSTALAÇÃO:
#   1. Adicionar host no Zabbix Server Dashboard
#      Caminho: Data Collection > Hosts > Create Host
#   2. Configurar parâmetros do host:
#      - Host Name: [mesmo hostname configurado]
#      - Templates: Linux by Zabbix agent
#      - Host Groups: Linux Servers
#      - Interfaces: [IP_PUBLICO]:10060
#   3. Verificar conectividade e monitoramento
#   4. Validar coleta de métricas
#
# TROUBLESHOOTING:
#   - Logs do Agent: /var/log/zabbix/zabbix_agentd.log
#   - Status do serviço: systemctl status zabbix-agent
#   - Teste de configuração: zabbix_agentd -t agent.ping
#   - Verificar conectividade: telnet [IP_SERVER] [PORTA]
#   - Validar configuração: cat /etc/zabbix/zabbix_agentd.conf | grep -E "^Server=|^ServerActive=|^Hostname="
#
# REPOSITÓRIO:
#   https://github.com/hugllaslima/proxmox-ve-workspace
#
# CHANGELOG:
#   v1.1 (2025-10-24):
#     - Corrigido erro de sintaxe com parênteses em prompts
#     - Adicionados exemplos práticos para cada campo
#     - Melhorada validação de entrada de dados
#     - Separação de echo e read para evitar conflitos
#     - Documentação expandida no cabeçalho
#
#   v1.0 (2025-10-24):
#     - Versão inicial do script
#
################################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Arquivo de log
LOG_FILE="/var/log/zabbix_agent_install_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Funções Auxiliares
################################################################################

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para mensagens de sucesso
success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

# Função para mensagens de erro
error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

# Função para mensagens de aviso
warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

# Função para mensagens de informação
info() {
    echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"
}

# Função para exemplos
example() {
    echo -e "${CYAN}[Exemplo]${NC} $1"
}

# Função para validar se está rodando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script deve ser executado como root (sudo)"
        exit 1
    fi
    success "Verificação de privilégios: OK"
}

# Função para validar IP
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Função para validar subnet/CIDR
validate_subnet() {
    local subnet=$1
    if [[ $subnet =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Função para validar hostname
validate_hostname() {
    local hostname=$1
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Função para confirmar informação
confirm() {
    local message=$1
    local response
    
    while true; do
        read -p "$(echo -e "${YELLOW}$message [S/n]:${NC} ")" response
        case $response in
            [Ss]* | "" ) return 0;;
            [Nn]* ) return 1;;
            * ) warning "Por favor, responda S (sim) ou N (não).";;
        esac
    done
}

# Função para backup de arquivo
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        success "Backup criado: ${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Função para verificar conectividade
check_connectivity() {
    local host=$1
    local port=$2
    
    info "Verificando conectividade com $host:$port..."
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        success "Conectividade com $host:$port estabelecida"
        return 0
    else
        warning "Não foi possível conectar com $host:$port"
        return 1
    fi
}

################################################################################
# Início do Script
################################################################################

clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║     INSTALAÇÃO AUTOMATIZADA DO ZABBIX AGENT 7.2                 ║
║     Ambiente Híbrido (Cloud + On-Premise)                       ║
║                                                                  ║
║     Proxmox VE Automation Suite                                 ║
║     Autor: Hugllas Lima | v1.1                                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log "========== Início da Instalação do Zabbix Agent 7.2 =========="

# Verificar se está rodando como root
check_root

# Verificar sistema operacional
info "Verificando sistema operacional..."
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "24.04" ]]; then
        warning "Este script foi desenvolvido para Ubuntu 24.04 LTS"
        warning "Sistema detectado: $OS $VER"
        if ! confirm "Deseja continuar mesmo assim?"; then
            error "Instalação cancelada pelo usuário"
            exit 1
        fi
    else
        success "Sistema operacional: Ubuntu 24.04 LTS"
    fi
else
    error "Não foi possível identificar o sistema operacional"
    exit 1
fi

################################################################################
# Coleta de Informações
################################################################################

echo ""
info "========== COLETA DE INFORMAÇÕES =========="
echo ""
info "Por favor, forneça as informações solicitadas abaixo."
info "Exemplos serão mostrados para ajudar no preenchimento."
echo ""

# IP do Zabbix Server
while true; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1/4] IP do Zabbix Server${NC}"
    echo ""
    example "138.199.171.248"
    example "192.168.1.100"
    echo ""
    read -p "Digite o IP do Zabbix Server: " ZABBIX_SERVER_IP
    
    if validate_ip "$ZABBIX_SERVER_IP"; then
        info "IP informado: $ZABBIX_SERVER_IP"
        if confirm "O IP $ZABBIX_SERVER_IP está correto?"; then
            success "IP do Zabbix Server confirmado: $ZABBIX_SERVER_IP"
            break
        fi
    else
        error "IP inválido. Por favor, digite um IP válido."
        echo ""
    fi
done

# Subnet/Gateway adicional (opcional)
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}[2/4] Subnet ou Gateway Adicional (OPCIONAL)${NC}"
echo ""
info "Esta configuração permite que o Agent aceite conexões de uma rede adicional."
info "Útil quando você tem múltiplas redes ou proxies."
echo ""
example "10.10.10.0/24 (subnet da rede local)"
example "192.168.1.0/16 (subnet ampla)"
example "172.16.0.1 (IP de gateway específico)"
echo ""
echo -e "${YELLOW}Pressione ENTER para pular esta etapa${NC}"
echo ""
read -p "Digite a Subnet ou Gateway adicional: " ADDITIONAL_NETWORK

if [[ -n "$ADDITIONAL_NETWORK" ]]; then
    if validate_subnet "$ADDITIONAL_NETWORK" || validate_ip "$ADDITIONAL_NETWORK"; then
        info "Rede adicional informada: $ADDITIONAL_NETWORK"
        if confirm "A rede $ADDITIONAL_NETWORK está correta?"; then
            success "Rede adicional confirmada: $ADDITIONAL_NETWORK"
            SERVER_PARAM="$ZABBIX_SERVER_IP,$ADDITIONAL_NETWORK"
        else
            warning "Rede adicional descartada"
            ADDITIONAL_NETWORK=""
            SERVER_PARAM="$ZABBIX_SERVER_IP"
        fi
    else
        warning "Formato inválido. Usando apenas o IP do Zabbix Server."
        ADDITIONAL_NETWORK=""
        SERVER_PARAM="$ZABBIX_SERVER_IP"
    fi
else
    info "Nenhuma rede adicional configurada"
    SERVER_PARAM="$ZABBIX_SERVER_IP"
fi

# Hostname do Agent
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}[3/4] Hostname do Agent${NC}"
echo ""
info "Este será o nome identificador do host no Zabbix Server."
info "IMPORTANTE: Use o mesmo nome ao criar o host no Dashboard do Zabbix."
echo ""
example "ansible-server"
example "web-server-01"
example "db-mysql-prod"
example "proxmox-node1"
echo ""

while true; do
    read -p "Digite o Hostname do Agent: " AGENT_HOSTNAME
    
    if validate_hostname "$AGENT_HOSTNAME"; then
        info "Hostname informado: $AGENT_HOSTNAME"
        if confirm "O hostname '$AGENT_HOSTNAME' está correto?"; then
            success "Hostname confirmado: $AGENT_HOSTNAME"
            break
        fi
    else
        error "Hostname inválido."
        warning "Use apenas letras, números e hífens."
        warning "Não pode começar ou terminar com hífen."
        echo ""
    fi
done

# Porta do Zabbix Server (padrão 10051)
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}[4/4] Porta do Zabbix Server${NC}"
echo ""
info "Porta padrão do Zabbix Server para comunicação ativa."
echo ""
example "10051 (padrão)"
example "10061 (customizada)"
echo ""
echo -e "${YELLOW}Pressione ENTER para usar a porta padrão (10051)${NC}"
echo ""
read -p "Digite a porta do Zabbix Server: " ZABBIX_SERVER_PORT
ZABBIX_SERVER_PORT=${ZABBIX_SERVER_PORT:-10051}

if [[ ! "$ZABBIX_SERVER_PORT" =~ ^[0-9]+$ ]] || [[ "$ZABBIX_SERVER_PORT" -lt 1 ]] || [[ "$ZABBIX_SERVER_PORT" -gt 65535 ]]; then
    warning "Porta inválida. Usando porta padrão 10051"
    ZABBIX_SERVER_PORT=10051
fi

success "Porta do Zabbix Server: $ZABBIX_SERVER_PORT"

# Resumo das configurações
echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                    RESUMO DAS CONFIGURAÇÕES                      ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}┌─ Zabbix Server${NC}"
echo -e "${CYAN}│${NC}  IP: ${GREEN}$ZABBIX_SERVER_IP${NC}"
echo -e "${CYAN}│${NC}  Porta: ${GREEN}$ZABBIX_SERVER_PORT${NC}"
echo -e "${CYAN}└─${NC}"
echo ""
echo -e "${CYAN}┌─ Configuração do Agent${NC}"
echo -e "${CYAN}│${NC}  Hostname: ${GREEN}$AGENT_HOSTNAME${NC}"
echo -e "${CYAN}│${NC}  Server Parameter: ${GREEN}$SERVER_PARAM${NC}"
if [[ -n "$ADDITIONAL_NETWORK" ]]; then
    echo -e "${CYAN}│${NC}  Rede Adicional: ${GREEN}$ADDITIONAL_NETWORK${NC}"
fi
echo -e "${CYAN}└─${NC}"
echo ""

if ! confirm "Confirma as configurações acima para prosseguir com a instalação?"; then
    error "Instalação cancelada pelo usuário"
    exit 1
fi

################################################################################
# Instalação do Zabbix Agent
################################################################################

echo ""
info "========== INICIANDO INSTALAÇÃO =========="
echo ""

# Passo 1: Download do repositório
info "[1/8] Baixando repositório oficial do Zabbix 7.2..."
cd /tmp || exit 1

if wget -q --show-progress https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu24.04_all.deb 2>&1 | tee -a "$LOG_FILE"; then
    success "Repositório baixado com sucesso"
else
    error "Falha ao baixar o repositório do Zabbix"
    error "Verifique sua conexão com a internet"
    exit 1
fi

# Passo 2: Instalar o pacote de repositório
info "[2/8] Instalando pacote de repositório do Zabbix..."
if dpkg -i zabbix-release_latest_7.2+ubuntu24.04_all.deb >> "$LOG_FILE" 2>&1; then
    success "Pacote de repositório instalado com sucesso"
else
    error "Falha ao instalar o pacote de repositório"
    exit 1
fi

# Passo 3: Atualizar repositórios
info "[3/8] Atualizando lista de pacotes..."
if apt update >> "$LOG_FILE" 2>&1; then
    success "Lista de pacotes atualizada"
else
    error "Falha ao atualizar lista de pacotes"
    exit 1
fi

# Passo 4: Instalar Zabbix Agent
info "[4/8] Instalando Zabbix Agent 7.2..."
if DEBIAN_FRONTEND=noninteractive apt install zabbix-agent -y >> "$LOG_FILE" 2>&1; then
    success "Zabbix Agent instalado com sucesso"
else
    error "Falha ao instalar o Zabbix Agent"
    exit 1
fi

# Passo 5: Verificar instalação
info "[5/8] Verificando instalação do Zabbix Agent..."
if systemctl is-active --quiet zabbix-agent; then
    success "Zabbix Agent está ativo"
elif systemctl is-enabled --quiet zabbix-agent; then
    warning "Zabbix Agent instalado mas não está ativo ainda"
else
    error "Problema na instalação do Zabbix Agent"
    exit 1
fi

# Passo 6: Configurar o Zabbix Agent
info "[6/8] Configurando Zabbix Agent..."

CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

if [[ ! -f "$CONF_FILE" ]]; then
    error "Arquivo de configuração não encontrado: $CONF_FILE"
    exit 1
fi

# Fazer backup do arquivo original
backup_file "$CONF_FILE"

# Configurar Server
info "Configurando parâmetro 'Server'..."
if sed -i "s/^Server=.*/Server=$SERVER_PARAM/" "$CONF_FILE"; then
    success "Parâmetro 'Server' configurado: $SERVER_PARAM"
else
    error "Falha ao configurar parâmetro 'Server'"
    exit 1
fi

# Configurar ServerActive
info "Configurando parâmetro 'ServerActive'..."
if sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_IP:$ZABBIX_SERVER_PORT/" "$CONF_FILE"; then
    success "Parâmetro 'ServerActive' configurado: $ZABBIX_SERVER_IP:$ZABBIX_SERVER_PORT"
else
    error "Falha ao configurar parâmetro 'ServerActive'"
    exit 1
fi

# Configurar Hostname
info "Configurando parâmetro 'Hostname'..."
if sed -i "s/^Hostname=.*/Hostname=$AGENT_HOSTNAME/" "$CONF_FILE"; then
    success "Parâmetro 'Hostname' configurado: $AGENT_HOSTNAME"
else
    error "Falha ao configurar parâmetro 'Hostname'"
    exit 1
fi

# Verificar configurações aplicadas
info "Verificando configurações aplicadas..."
echo ""
echo -e "${YELLOW}┌─ Configurações no arquivo $CONF_FILE${NC}"
grep -E "^Server=|^ServerActive=|^Hostname=" "$CONF_FILE" | while read line; do
    echo -e "${YELLOW}│${NC}  $line"
done
echo -e "${YELLOW}└─${NC}"
echo ""

if ! confirm "As configurações acima estão corretas?"; then
    error "Configuração rejeitada. Restaurando backup..."
    BACKUP_FILE=$(ls -t "${CONF_FILE}.backup."* 2>/dev/null | head -n1)
    if [[ -f "$BACKUP_FILE" ]]; then
        mv "$BACKUP_FILE" "$CONF_FILE"
        success "Backup restaurado"
    fi
    exit 1
fi

# Passo 7: Reiniciar e habilitar o serviço
info "[7/8] Reiniciando e habilitando o Zabbix Agent..."

if systemctl restart zabbix-agent >> "$LOG_FILE" 2>&1; then
    success "Zabbix Agent reiniciado"
else
    error "Falha ao reiniciar o Zabbix Agent"
    exit 1
fi

if systemctl enable zabbix-agent >> "$LOG_FILE" 2>&1; then
    success "Zabbix Agent habilitado para iniciar no boot"
else
    warning "Falha ao habilitar o Zabbix Agent no boot"
fi

sleep 2

# Verificar status final
if systemctl is-active --quiet zabbix-agent; then
    success "Zabbix Agent está rodando corretamente"
else
    error "Zabbix Agent não está rodando"
    info "Verificando logs..."
    tail -n 20 /var/log/zabbix/zabbix_agentd.log 2>/dev/null || journalctl -u zabbix-agent -n 20
    exit 1
fi

# Passo 8: Teste de conectividade
info "[8/8] Testando conectividade com o Zabbix Server..."

if check_connectivity "$ZABBIX_SERVER_IP" "$ZABBIX_SERVER_PORT"; then
    success "Conectividade com Zabbix Server OK"
else
    warning "Não foi possível conectar ao Zabbix Server"
    warning "Verifique:"
    warning "  • Firewall local"
    warning "  • Port Forwarding"
    warning "  • Security Groups na Cloud"
    warning "  • IP público configurado corretamente"
fi

################################################################################
# Finalização
################################################################################

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}║          INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✓                    ║${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

info "========== PRÓXIMOS PASSOS =========="
echo ""
echo -e "${CYAN}┌─ No Dashboard do Zabbix Server${NC}"
echo -e "${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${YELLOW}1.${NC} Acesse: ${BLUE}Data Collection > Hosts > Create Host${NC}"
echo -e "${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${YELLOW}2.${NC} Configure o Host:"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Host Name: ${GREEN}$AGENT_HOSTNAME${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Visible Name: ${GREEN}$AGENT_HOSTNAME${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Templates: ${GREEN}Linux by Zabbix agent${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Host Groups: ${GREEN}Linux Servers${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Interfaces: ${GREEN}[SEU_IP_PUBLICO]:10060${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Monitored by: ${GREEN}Server${NC}"
echo -e "${CYAN}│${NC}     ${MAGENTA}•${NC} Enabled: ${GREEN}Sim${NC}"
echo -e "${CYAN}│${NC}"
echo -e "${CYAN}└─${NC}"
echo ""

info "========== INFORMAÇÕES IMPORTANTES =========="
echo ""
echo -e "${CYAN}┌─ Arquivos${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Configuração: ${BLUE}$CONF_FILE${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Log da instalação: ${BLUE}$LOG_FILE${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Logs do Agent: ${BLUE}/var/log/zabbix/zabbix_agentd.log${NC}"
echo -e "${CYAN}└─${NC}"
echo ""

info "========== COMANDOS ÚTEIS =========="
echo ""
echo -e "${CYAN}┌─ Gerenciamento do Serviço${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Status: ${BLUE}systemctl status zabbix-agent${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Reiniciar: ${BLUE}systemctl restart zabbix-agent${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Parar: ${BLUE}systemctl stop zabbix-agent${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Iniciar: ${BLUE}systemctl start zabbix-agent${NC}"
echo -e "${CYAN}└─${NC}"
echo ""
echo -e "${CYAN}┌─ Diagnóstico${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Ver logs: ${BLUE}tail -f /var/log/zabbix/zabbix_agentd.log${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Testar ping: ${BLUE}zabbix_agentd -t agent.ping${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Ver config: ${BLUE}cat $CONF_FILE | grep -E '^Server=|^ServerActive=|^Hostname='${NC}"
echo -e "${CYAN}│${NC}  ${MAGENTA}•${NC} Testar conectividade: ${BLUE}telnet $ZABBIX_SERVER_IP $ZABBIX_SERVER_PORT${NC}"
echo -e "${CYAN}└─${NC}"
echo ""

# Criar arquivo de resumo
SUMMARY_FILE="/root/zabbix_agent_install_summary_$(date +%Y%m%d_%H%M%S).txt"
cat > "$SUMMARY_FILE" << EOF
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║          RESUMO DA INSTALAÇÃO DO ZABBIX AGENT 7.2               ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

Data da Instalação: $(date '+%Y-%m-%d %H:%M:%S')
Script: install_zabbix_agent_7.2_ubuntu.sh v1.1
Autor: Hugllas Lima

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONFIGURAÇÕES APLICADAS:

  • IP do Zabbix Server: $ZABBIX_SERVER_IP
  • Porta do Zabbix Server: $ZABBIX_SERVER_PORT
  • Server Parameter: $SERVER_PARAM
  • Hostname do Agent: $AGENT_HOSTNAME
EOF

if [[ -n "$ADDITIONAL_NETWORK" ]]; then
    echo "  • Rede Adicional: $ADDITIONAL_NETWORK" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ARQUIVOS IMPORTANTES:

  • Configuração: $CONF_FILE
  • Log da instalação: $LOG_FILE
  • Logs do Agent: /var/log/zabbix/zabbix_agentd.log
  • Backup da config: ${CONF_FILE}.backup.*

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRÓXIMOS PASSOS NO ZABBIX SERVER:

1. Acessar Dashboard
   Caminho: Data Collection > Hosts > Create Host

2. Configurar Host:
   • Host Name: $AGENT_HOSTNAME
   • Visible Name: $AGENT_HOSTNAME
   • Templates: Linux by Zabbix agent
   • Host Groups: Linux Servers
   • Interfaces: [IP_PUBLICO]:10060
   • Monitored by: Server
   • Enabled: Sim

3. Verificar Monitoramento:
   • Aguardar alguns minutos para coleta de dados
   • Verificar status do host (deve ficar verde)
   • Validar métricas em Latest Data

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMANDOS ÚTEIS:

Gerenciamento:
  systemctl status zabbix-agent
  systemctl restart zabbix-agent
  systemctl stop zabbix-agent
  systemctl start zabbix-agent

Diagnóstico:
  tail -f /var/log/zabbix/zabbix_agentd.log
  zabbix_agentd -t agent.ping
  cat $CONF_FILE | grep -E '^Server=|^ServerActive=|^Hostname='
  telnet $ZABBIX_SERVER_IP $ZABBIX_SERVER_PORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TROUBLESHOOTING:

Se o host não aparecer no Zabbix Server:
  1. Verificar logs: tail -f /var/log/zabbix/zabbix_agentd.log
  2. Testar conectividade: telnet $ZABBIX_SERVER_IP $ZABBIX_SERVER_PORT
  3. Verificar firewall local
  4. Validar Port Forwarding
  5. Checar Security Groups na Cloud
  6. Confirmar hostname no Zabbix Server

Se métricas não aparecerem:
  1. Verificar se o host está "Enabled"
  2. Aguardar 2-3 minutos para primeira coleta
  3. Verificar templates aplicados
  4. Checar Latest Data no Dashboard

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUPORTE:

Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
Documentação Zabbix: https://www.zabbix.com/documentation/7.2/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

success "Resumo da instalação salvo em: $SUMMARY_FILE"

echo ""
info "Para visualizar o resumo completo:"
echo -e "  ${BLUE}cat $SUMMARY_FILE${NC}"
echo ""

log "========== Instalação Finalizada com Sucesso =========="

exit 0
