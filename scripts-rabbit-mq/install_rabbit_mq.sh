#!/bin/bash

# -----------------------------------------------------------------------------
# Script: install_rabbit_mq.sh
# Descrição: Instala e configura um servidor RabbitMQ dedicado em Ubuntu 24.04 LTS.
#            O script é interativo e configura o IP do servidor, usuário admin,
#            usuários de serviço com vhosts, firewall (UFW) e salva as
#            credenciais de forma segura.
# Autor: Hugllas Lima
# Data de Criação: 01/08/2024
# Versão: 2.2
# Licença: GPL-3.0
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./install_rabbit_mq.sh
#
# Pré-requisitos:
#   - Sistema Operacional: Ubuntu Server 24.04 LTS.
#   - Acesso root (sudo).
#   - Conexão com a internet para download de pacotes.
#
# Notas Importantes:
#   - O script é interativo e solicitará informações durante a execução.
#   - As credenciais geradas são salvas em /root/rabbitmq_credentials_*.txt.
#     É crucial fazer backup deste arquivo em um local seguro.
#   - Recomenda-se revisar o resumo da configuração antes de confirmar.
#
# -----------------------------------------------------------------------------


set -e  # Parar execução em caso de erro

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para exibir cabeçalho
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}║            Instalação RabbitMQ Server (Dedicado)           ║${NC}"
    echo -e "${BLUE}║                   Ubuntu Server 24.04 LTS                  ║${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

# Função para gerar senha aleatória
generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | fold -w 24 | head -n 1
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

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser executado como root (use sudo)${NC}" 
   exit 1
fi

print_header

echo -e "${CYAN}Este script irá instalar e configurar o RabbitMQ Server.${NC}"
echo -e "${CYAN}Você será guiado através de perguntas interativas.${NC}\n"

# ============================================================================
# COLETA DE INFORMAÇÕES
# ============================================================================

echo -e "${YELLOW}═══ Configuração do Servidor ═══${NC}\n"

# IP do servidor
while true; do
    read -p "Digite o IP deste servidor RabbitMQ: " RABBITMQ_IP
    if validate_ip "$RABBITMQ_IP"; then
        echo -e "${GREEN}✓ IP válido: ${RABBITMQ_IP}${NC}\n"
        break
    else
        echo -e "${RED}✗ IP inválido. Por favor, digite um IP válido (ex: 10.10.1.231)${NC}"
    fi
done

# ============================================================================
# USUÁRIO ADMINISTRADOR
# ============================================================================

echo -e "${YELLOW}═══ Usuário Administrador ═══${NC}"
echo -e "${CYAN}Este usuário terá acesso total ao RabbitMQ Management.${NC}\n"

read -p "Nome do usuário administrador [admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

if ask_yes_no "Deseja gerar uma senha aleatória para o admin?"; then
    ADMIN_PASS=$(generate_password)
    echo -e "${GREEN}Senha gerada automaticamente.${NC}"
else
    while true; do
        read -sp "Digite a senha para o usuário admin: " ADMIN_PASS
        echo
        read -sp "Confirme a senha: " ADMIN_PASS_CONFIRM
        echo
        if [ "$ADMIN_PASS" == "$ADMIN_PASS_CONFIRM" ]; then
            break
        else
            echo -e "${RED}As senhas não conferem. Tente novamente.${NC}"
        fi
    done
fi

# ============================================================================
# CONFIGURAÇÃO DE SERVIÇOS (VHOSTS E USUÁRIOS)
# ============================================================================

echo -e "\n${YELLOW}═══ Configuração de Serviços ═══${NC}"
echo -e "${CYAN}Você pode criar usuários e vhosts para seus serviços agora.${NC}"
echo -e "${CYAN}Exemplo: OnlyOffice, Home Assistant, etc.${NC}\n"

declare -a SERVICES
declare -a SERVICE_USERS
declare -a SERVICE_PASSES
declare -a SERVICE_VHOSTS

if ask_yes_no "Deseja criar usuários para serviços agora?"; then
    while true; do
        echo -e "\n${BLUE}--- Novo Serviço ---${NC}"

        read -p "Nome do serviço (ex: onlyoffice, homeassistant): " SERVICE_NAME

        read -p "Nome do usuário [$SERVICE_NAME]: " SERVICE_USER
        SERVICE_USER=${SERVICE_USER:-$SERVICE_NAME}

        if ask_yes_no "Deseja gerar uma senha aleatória para $SERVICE_USER?"; then
            SERVICE_PASS=$(generate_password)
            echo -e "${GREEN}Senha gerada automaticamente.${NC}"
        else
            while true; do
                read -sp "Digite a senha para $SERVICE_USER: " SERVICE_PASS
                echo
                read -sp "Confirme a senha: " SERVICE_PASS_CONFIRM
                echo
                if [ "$SERVICE_PASS" == "$SERVICE_PASS_CONFIRM" ]; then
                    break
                else
                    echo -e "${RED}As senhas não conferem. Tente novamente.${NC}"
                fi
            done
        fi

        read -p "Nome do vhost [${SERVICE_NAME}_vhost]: " SERVICE_VHOST
        SERVICE_VHOST=${SERVICE_VHOST:-${SERVICE_NAME}_vhost}

        SERVICES+=("$SERVICE_NAME")
        SERVICE_USERS+=("$SERVICE_USER")
        SERVICE_PASSES+=("$SERVICE_PASS")
        SERVICE_VHOSTS+=("$SERVICE_VHOST")

        echo -e "${GREEN}✓ Serviço '$SERVICE_NAME' adicionado${NC}"

        if ! ask_yes_no "Deseja adicionar outro serviço?"; then
            break
        fi
    done
fi

# ============================================================================
# CONFIRMAÇÃO
# ============================================================================

echo -e "\n${YELLOW}═══ Resumo da Configuração ═══${NC}"
echo -e "${BLUE}IP do Servidor:${NC} $RABBITMQ_IP"
echo -e "${BLUE}Usuário Admin:${NC} $ADMIN_USER"
echo -e "${BLUE}Porta AMQP:${NC} 5672"
echo -e "${BLUE}Porta Management:${NC} 15672"

if [ ${#SERVICES[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Serviços a serem criados:${NC}"
    for i in "${!SERVICES[@]}"; do
        echo -e "  ${CYAN}$((i+1)).${NC} ${SERVICES[$i]} (usuário: ${SERVICE_USERS[$i]}, vhost: ${SERVICE_VHOSTS[$i]})"
    done
fi

echo

if ! ask_yes_no "Confirma a instalação com estas configurações?"; then
    echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
    exit 0
fi

# ============================================================================
# INSTALAÇÃO
# ============================================================================

echo -e "\n${GREEN}Iniciando instalação...${NC}\n"

# 1. Atualizar sistema
echo -e "${GREEN}[1/6] Atualizando sistema...${NC}"
apt update && apt upgrade -y
apt install -y curl gnupg apt-transport-https

# 2. Instalar Erlang dos repositórios Ubuntu (mais confiável)
echo -e "${GREEN}[2/6] Instalando Erlang (repositórios Ubuntu)...${NC}"
apt install -y erlang-base \
               erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
               erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
               erlang-runtime-tools erlang-snmp erlang-ssl \
               erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

# 3. Adicionar chave GPG do RabbitMQ (método alternativo)
echo -e "${GREEN}[3/6] Adicionando chave GPG do RabbitMQ...${NC}"

# Método 1: Tentar via curl
if ! curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor > /usr/share/keyrings/com.rabbitmq.team.gpg 2>/dev/null; then
    echo -e "${YELLOW}Método 1 falhou, tentando método alternativo...${NC}"

    # Método 2: Usar o GitHub do RabbitMQ
    if ! curl -fsSL "https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc" | gpg --dearmor > /usr/share/keyrings/com.rabbitmq.team.gpg 2>/dev/null; then
        echo -e "${YELLOW}Método 2 falhou, tentando método 3...${NC}"

        # Método 3: Usar keyserver
        gpg --keyserver keyserver.ubuntu.com --recv-keys 0A9AF2115F4687BD29803A206B73A36E6026DFCA
        gpg --export 0A9AF2115F4687BD29803A206B73A36E6026DFCA > /usr/share/keyrings/com.rabbitmq.team.gpg
    fi
fi

echo -e "${GREEN}✓ Chave GPG adicionada com sucesso${NC}"

# 4. Adicionar repositório do RabbitMQ
echo -e "${GREEN}[4/6] Adicionando repositório RabbitMQ...${NC}"

# Usar repositório Cloudsmith (mais estável que packagecloud)
cat > /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides RabbitMQ
deb [signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
deb-src [signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
EOF

# 5. Instalar RabbitMQ Server
echo -e "${GREEN}[5/6] Instalando RabbitMQ Server...${NC}"
apt update
apt install -y rabbitmq-server

# 6. Configurar e iniciar serviços
echo -e "${GREEN}[6/6] Configurando RabbitMQ...${NC}"

# Habilitar e iniciar serviço
systemctl enable rabbitmq-server
systemctl start rabbitmq-server

# Aguardar serviço inicializar
echo -e "${CYAN}Aguardando RabbitMQ inicializar...${NC}"
sleep 15

# Verificar se está rodando
if ! systemctl is-active --quiet rabbitmq-server; then
    echo -e "${RED}Erro: RabbitMQ não iniciou corretamente${NC}"
    echo -e "${YELLOW}Verificando logs...${NC}"
    journalctl -u rabbitmq-server -n 50 --no-pager
    exit 1
fi

# Habilitar Management Plugin
echo -e "${CYAN}Habilitando Management Plugin...${NC}"
rabbitmq-plugins enable rabbitmq_management

# Aguardar plugin inicializar
sleep 5

# Remover usuário guest (segurança)
echo -e "${CYAN}Configurando segurança...${NC}"
rabbitmqctl delete_user guest 2>/dev/null || true

# Criar usuário admin
echo -e "${CYAN}Criando usuário administrador...${NC}"
rabbitmqctl add_user "$ADMIN_USER" "$ADMIN_PASS"
rabbitmqctl set_user_tags "$ADMIN_USER" administrator
rabbitmqctl set_permissions -p / "$ADMIN_USER" ".*" ".*" ".*"

# Criar usuários dos serviços
if [ ${#SERVICES[@]} -gt 0 ]; then
    echo -e "${CYAN}Criando usuários dos serviços...${NC}"
    for i in "${!SERVICES[@]}"; do
        SERVICE_USER="${SERVICE_USERS[$i]}"
        SERVICE_PASS="${SERVICE_PASSES[$i]}"
        SERVICE_VHOST="${SERVICE_VHOSTS[$i]}"

        echo -e "  ${BLUE}→${NC} Configurando ${SERVICES[$i]}..."

        # Criar usuário
        rabbitmqctl add_user "$SERVICE_USER" "$SERVICE_PASS"

        # Criar vhost
        rabbitmqctl add_vhost "$SERVICE_VHOST"

        # Dar permissões
        rabbitmqctl set_permissions -p "$SERVICE_VHOST" "$SERVICE_USER" ".*" ".*" ".*"
        rabbitmqctl set_permissions -p / "$SERVICE_USER" ".*" ".*" ".*"

        echo -e "  ${GREEN}✓${NC} ${SERVICES[$i]} configurado"
    done
fi

# ============================================================================
# CONFIGURAR FIREWALL
# ============================================================================

if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Configurando firewall UFW...${NC}"
    ufw allow 5672/tcp comment 'RabbitMQ AMQP'
    ufw allow 15672/tcp comment 'RabbitMQ Management'
    echo -e "${GREEN}✓ Firewall configurado${NC}"
fi

# ============================================================================
# SALVAR CREDENCIAIS
# ============================================================================

CREDENTIALS_FILE="/root/rabbitmq_credentials_$(date +%Y%m%d_%H%M%S).txt"

cat > "$CREDENTIALS_FILE" <<EOF
═══════════════════════════════════════════════════════════════
    CREDENCIAIS RABBITMQ SERVER
═══════════════════════════════════════════════════════════════

Data de Instalação: $(date '+%d/%m/%Y %H:%M:%S')
IP do Servidor: ${RABBITMQ_IP}
Porta AMQP: 5672
Porta Management: 15672

───────────────────────────────────────────────────────────────
USUÁRIO ADMINISTRADOR
───────────────────────────────────────────────────────────────
Usuário: ${ADMIN_USER}
Senha: ${ADMIN_PASS}

URLs de Acesso:
  Management Web: http://${RABBITMQ_IP}:15672
  AMQP URL: amqp://${ADMIN_USER}:${ADMIN_PASS}@${RABBITMQ_IP}:5672/

EOF

# Adicionar serviços ao arquivo
if [ ${#SERVICES[@]} -gt 0 ]; then
    cat >> "$CREDENTIALS_FILE" <<EOF
───────────────────────────────────────────────────────────────
SERVIÇOS CONFIGURADOS
───────────────────────────────────────────────────────────────

EOF

    for i in "${!SERVICES[@]}"; do
        cat >> "$CREDENTIALS_FILE" <<EOF
▸ ${SERVICES[$i]}
  Usuário: ${SERVICE_USERS[$i]}
  Senha: ${SERVICE_PASSES[$i]}
  VHost: ${SERVICE_VHOSTS[$i]}
  AMQP URL: amqp://${SERVICE_USERS[$i]}:${SERVICE_PASSES[$i]}@${RABBITMQ_IP}:5672/${SERVICE_VHOSTS[$i]}

EOF
    done
fi

cat >> "$CREDENTIALS_FILE" <<EOF
═══════════════════════════════════════════════════════════════
IMPORTANTE: Guarde este arquivo em local seguro!
═══════════════════════════════════════════════════════════════
EOF

chmod 600 "$CREDENTIALS_FILE"

# ============================================================================
# VERIFICAÇÃO FINAL
# ============================================================================

echo -e "\n${GREEN}═══ Verificando instalação ═══${NC}"

echo -e "\n${BLUE}Status do serviço:${NC}"
systemctl status rabbitmq-server --no-pager | grep Active

echo -e "\n${BLUE}Versão do RabbitMQ:${NC}"
rabbitmqctl version

echo -e "\n${BLUE}Versão do Erlang:${NC}"
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

echo -e "\n${BLUE}Plugins habilitados:${NC}"
rabbitmq-plugins list | grep enabled

echo -e "\n${BLUE}Usuários criados:${NC}"
rabbitmqctl list_users

echo -e "\n${BLUE}VHosts criados:${NC}"
rabbitmqctl list_vhosts

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║             Instalação Concluída com Sucesso! ✓            ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Credenciais salvas em:${NC} ${CREDENTIALS_FILE}\n"
cat "$CREDENTIALS_FILE"

echo -e "\n${YELLOW}═══ PRÓXIMOS PASSOS ═══${NC}"
echo -e "1. ${BLUE}Acesse o Management:${NC} http://${RABBITMQ_IP}:15672"
echo -e "2. ${BLUE}Faça login com:${NC} ${ADMIN_USER}"
echo -e "3. ${BLUE}Backup das credenciais:${NC} Copie o arquivo ${CREDENTIALS_FILE}"

if [ ${#SERVICES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}═══ INTEGRAÇÃO COM SERVIÇOS ═══${NC}"
    echo -e "Use as URLs AMQP acima para configurar seus serviços."
fi

echo -e "\n${GREEN}Instalação finalizada!${NC}\n"
