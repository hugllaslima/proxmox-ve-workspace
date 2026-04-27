#!/bin/bash

# -----------------------------------------------------------------------------
# Script: install_onlyoffice_server.sh (LEGADO)
# Descrição: Instala e configura o OnlyOffice Document Server (versão legada).
# Autor: Hugllas Lima
# Data de Criação: 30/07/2024
# Versão: 2.0
# Licença: GPL-3.0
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./install_onlyoffice_server.sh
#
# ATENÇÃO:
#   Esta é uma versão legada. Para novas instalações, é altamente recomendável
#   utilizar o script `install_onlyoffice_server_v2.sh`, que contém melhorias
#   de estabilidade e um processo de instalação mais robusto.
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
    echo -e "${BLUE}║           Instalação OnlyOffice Document Server            ║${NC}"
    echo -e "${BLUE}║                  Ubuntu Server 24.04 LTS                   ║${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

# Função para gerar senha/token aleatório
generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
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

echo -e "${CYAN}Este script irá instalar e configurar o OnlyOffice Document Server.${NC}"
echo -e "${CYAN}Você será guiado através de perguntas interativas.${NC}\n"

# ============================================================================
# COLETA DE INFORMAÇÕES - SERVIDOR ONLYOFFICE
# ============================================================================

echo -e "${YELLOW}═══ Configuração do Servidor OnlyOffice ═══${NC}\n"

while true; do
    read -p "Digite o IP deste servidor OnlyOffice: " ONLYOFFICE_IP
    if validate_ip "$ONLYOFFICE_IP"; then
        echo -e "${GREEN}✓ IP válido: ${ONLYOFFICE_IP}${NC}\n"
        break
    else
        echo -e "${RED}✗ IP inválido. Por favor, digite um IP válido (ex: 10.10.1.228)${NC}"
    fi
done

while true; do
    read -p "Digite o IP do servidor Nextcloud: " NEXTCLOUD_IP
    if validate_ip "$NEXTCLOUD_IP"; then
        echo -e "${GREEN}✓ IP válido: ${NEXTCLOUD_IP}${NC}\n"
        break
    else
        echo -e "${RED}✗ IP inválido. Por favor, digite um IP válido (ex: 10.10.1.229)${NC}"
    fi
done

# ============================================================================
# COLETA DE INFORMAÇÕES - RABBITMQ
# ============================================================================

echo -e "${YELLOW}═══ Configuração do RabbitMQ (Servidor Externo) ═══${NC}"
echo -e "${CYAN}Informe os dados do servidor RabbitMQ dedicado.${NC}\n"

while true; do
    read -p "IP do servidor RabbitMQ: " RABBITMQ_HOST
    if validate_ip "$RABBITMQ_HOST"; then
        echo -e "${GREEN}✓ IP válido: ${RABBITMQ_HOST}${NC}"
        break
    else
        echo -e "${RED}✗ IP inválido. Por favor, digite um IP válido${NC}"
    fi
done

read -p "Porta do RabbitMQ [5672]: " RABBITMQ_PORT
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}

read -p "Usuário do RabbitMQ: " RABBITMQ_USER

while true; do
    read -sp "Senha do RabbitMQ: " RABBITMQ_PASS
    echo
    if [ -n "$RABBITMQ_PASS" ]; then
        break
    else
        echo -e "${RED}A senha não pode estar vazia.${NC}"
    fi
done

read -p "VHost do RabbitMQ [onlyoffice_vhost]: " RABBITMQ_VHOST
RABBITMQ_VHOST=${RABBITMQ_VHOST:-onlyoffice_vhost}

# ============================================================================
# TESTAR CONEXÃO COM RABBITMQ
# ============================================================================

echo -e "\n${BLUE}Testando conexão com RabbitMQ...${NC}"

if ! command -v nc &> /dev/null; then
    apt install -y netcat-openbsd
fi

if nc -zv $RABBITMQ_HOST $RABBITMQ_PORT 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓ Conexão com RabbitMQ OK${NC}\n"
else
    echo -e "${RED}✗ ERRO: Não foi possível conectar ao RabbitMQ em ${RABBITMQ_HOST}:${RABBITMQ_PORT}${NC}"
    echo -e "${YELLOW}Verifique se:${NC}"
    echo -e "  1. O RabbitMQ está rodando"
    echo -e "  2. O firewall está liberado"
    echo -e "  3. O IP e porta estão corretos"

    if ! ask_yes_no "Deseja continuar mesmo assim?"; then
        exit 1
    fi
fi

# ============================================================================
# CONFIGURAÇÃO DO POSTGRESQL
# ============================================================================

echo -e "${YELLOW}═══ Configuração do PostgreSQL (Local) ═══${NC}"
echo -e "${CYAN}O OnlyOffice usa PostgreSQL localmente para armazenar metadados.${NC}\n"

if ask_yes_no "Deseja gerar uma senha aleatória para o PostgreSQL?"; then
    POSTGRES_PASS=$(generate_password)
    echo -e "${GREEN}Senha gerada automaticamente.${NC}"
else
    while true; do
        read -sp "Digite a senha para o usuário PostgreSQL 'onlyoffice': " POSTGRES_PASS
        echo
        read -sp "Confirme a senha: " POSTGRES_PASS_CONFIRM
        echo
        if [ "$POSTGRES_PASS" == "$POSTGRES_PASS_CONFIRM" ]; then
            break
        else
            echo -e "${RED}As senhas não conferem. Tente novamente.${NC}"
        fi
    done
fi

# ============================================================================
# JWT SECRET
# ============================================================================

echo -e "\n${YELLOW}═══ JWT Secret (Segurança) ═══${NC}"
echo -e "${CYAN}O JWT Secret é usado para autenticação entre Nextcloud e OnlyOffice.${NC}\n"

if ask_yes_no "Deseja gerar um JWT Secret automaticamente?"; then
    JWT_SECRET=$(generate_password)
    echo -e "${GREEN}JWT Secret gerado automaticamente.${NC}"
else
    while true; do
        read -p "Digite o JWT Secret (mínimo 20 caracteres): " JWT_SECRET
        if [ ${#JWT_SECRET} -ge 20 ]; then
            break
        else
            echo -e "${RED}JWT Secret muito curto. Use no mínimo 20 caracteres.${NC}"
        fi
    done
fi

# ============================================================================
# CONFIRMAÇÃO
# ============================================================================

echo -e "\n${YELLOW}═══ Resumo da Configuração ═══${NC}"
echo -e "${BLUE}IP OnlyOffice:${NC} $ONLYOFFICE_IP"
echo -e "${BLUE}IP Nextcloud:${NC} $NEXTCLOUD_IP"
echo -e "${BLUE}RabbitMQ Host:${NC} $RABBITMQ_HOST:$RABBITMQ_PORT"
echo -e "${BLUE}RabbitMQ User:${NC} $RABBITMQ_USER"
echo -e "${BLUE}RabbitMQ VHost:${NC} $RABBITMQ_VHOST"
echo -e "${BLUE}PostgreSQL User:${NC} onlyoffice"
echo -e "${BLUE}JWT Secret:${NC} ${JWT_SECRET:0:10}... (${#JWT_SECRET} caracteres)"

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
echo -e "${GREEN}[1/9] Atualizando sistema...${NC}"
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release netcat-openbsd software-properties-common

# 2. Instalar PostgreSQL
echo -e "${GREEN}[2/9] Instalando PostgreSQL...${NC}"
apt install -y postgresql postgresql-contrib

# Aguardar PostgreSQL iniciar
sleep 3

# Configurar banco
sudo -u postgres psql -c "CREATE DATABASE onlyoffice;" 2>/dev/null || echo "Database já existe"
sudo -u postgres psql -c "CREATE USER onlyoffice WITH PASSWORD '${POSTGRES_PASS}';" 2>/dev/null || echo "Usuário já existe"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE onlyoffice TO onlyoffice;"

# 3. Adicionar repositório OnlyOffice
echo -e "${GREEN}[3/9] Adicionando repositório OnlyOffice...${NC}"
mkdir -p /usr/share/keyrings
curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --dearmor -o /usr/share/keyrings/onlyoffice.gpg

echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list

# 4. Preparar variáveis de ambiente para instalação
echo -e "${GREEN}[4/9] Preparando ambiente...${NC}"

export DS_RABBITMQ_HOST=$RABBITMQ_HOST
export DS_RABBITMQ_USER=$RABBITMQ_USER
export DS_RABBITMQ_PWD=$RABBITMQ_PASS
export DS_RABBITMQ_VHOST=$RABBITMQ_VHOST

# 5. Instalar OnlyOffice
echo -e "${GREEN}[5/9] Instalando OnlyOffice Document Server...${NC}"
echo -e "${YELLOW}Nota: Avisos sobre RabbitMQ local são normais (estamos usando externo).${NC}"

apt update
DEBIAN_FRONTEND=noninteractive apt install -y onlyoffice-documentserver

# 6. Configurar banco de dados
echo -e "${GREEN}[6/9] Configurando banco de dados...${NC}"
sudo -u postgres psql -d onlyoffice -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql 2>/dev/null || echo "Schema já aplicado"

# 7. Parar RabbitMQ local se existir
echo -e "${GREEN}[7/9] Desabilitando RabbitMQ local...${NC}"
if systemctl is-active --quiet rabbitmq-server; then
    systemctl stop rabbitmq-server
    systemctl disable rabbitmq-server
fi

# 8. Configurar OnlyOffice
echo -e "${GREEN}[8/9] Configurando OnlyOffice...${NC}"

# Criar diretório de configuração se não existir
mkdir -p /etc/onlyoffice/documentserver

# Configuração principal
cat > /etc/onlyoffice/documentserver/local.json <<EOF
{
  "services": {
    "CoAuthoring": {
      "sql": {
        "type": "postgres",
        "dbHost": "localhost",
        "dbPort": "5432",
        "dbName": "onlyoffice",
        "dbUser": "onlyoffice",
        "dbPass": "${POSTGRES_PASS}"
      },
      "secret": {
        "inbox": {
          "string": "${JWT_SECRET}"
        },
        "outbox": {
          "string": "${JWT_SECRET}"
        },
        "session": {
          "string": "${JWT_SECRET}"
        }
      },
      "token": {
        "enable": {
          "request": {
            "inbox": true,
            "outbox": true
          },
          "browser": true
        }
      }
    }
  },
  "rabbitmq": {
    "url": "amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}"
  },
  "storage": {
    "fs": {
      "secretString": "${JWT_SECRET}"
    }
  }
}
EOF

# Configuração adicional
cat > /etc/onlyoffice/documentserver/local-production-linux.json <<EOF
{
  "rabbitmq": {
    "url": "amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}",
    "login": "${RABBITMQ_USER}",
    "password": "${RABBITMQ_PASS}",
    "host": "${RABBITMQ_HOST}",
    "port": ${RABBITMQ_PORT},
    "vhost": "${RABBITMQ_VHOST}"
  }
}
EOF

# 9. Reiniciar serviços
echo -e "${GREEN}[9/9] Reiniciando serviços...${NC}"
supervisorctl restart all
sleep 5
systemctl restart nginx

# ============================================================================
# SALVAR CONFIGURAÇÕES
# ============================================================================

CONFIG_FILE="/root/onlyoffice_config_$(date +%Y%m%d_%H%M%S).txt"

cat > "$CONFIG_FILE" <<EOF
═══════════════════════════════════════════════════════════════
    CONFIGURAÇÃO ONLYOFFICE DOCUMENT SERVER
═══════════════════════════════════════════════════════════════

Data de Instalação: $(date '+%d/%m/%Y %H:%M:%S')

───────────────────────────────────────────────────────────────
SERVIDORES
───────────────────────────────────────────────────────────────
OnlyOffice IP: ${ONLYOFFICE_IP}
Nextcloud IP: ${NEXTCLOUD_IP}
RabbitMQ IP: ${RABBITMQ_HOST}:${RABBITMQ_PORT}

───────────────────────────────────────────────────────────────
JWT SECRET (use no Nextcloud)
───────────────────────────────────────────────────────────────
${JWT_SECRET}

───────────────────────────────────────────────────────────────
RABBITMQ CONNECTION
───────────────────────────────────────────────────────────────
Host: ${RABBITMQ_HOST}
Port: ${RABBITMQ_PORT}
User: ${RABBITMQ_USER}
VHost: ${RABBITMQ_VHOST}
URL: amqp://${RABBITMQ_USER}:****@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}

───────────────────────────────────────────────────────────────
POSTGRESQL (Local)
───────────────────────────────────────────────────────────────
Database: onlyoffice
User: onlyoffice
Password: ${POSTGRES_PASS}

───────────────────────────────────────────────────────────────
CONFIGURAÇÃO NO NEXTCLOUD
───────────────────────────────────────────────────────────────
1. Instale o app "ONLYOFFICE" no Nextcloud
2. Vá em: Configurações > ONLYOFFICE
3. Configure:
   Document Server: http://${ONLYOFFICE_IP}/
   JWT Secret: ${JWT_SECRET}

═══════════════════════════════════════════════════════════════
IMPORTANTE: Guarde este arquivo em local seguro!
═══════════════════════════════════════════════════════════════
EOF

chmod 600 "$CONFIG_FILE"

# ============================================================================
# VERIFICAÇÃO FINAL
# ============================================================================

echo -e "\n${GREEN}═══ Verificando instalação ═══${NC}"

echo -e "\n${BLUE}Status dos serviços OnlyOffice:${NC}"
supervisorctl status

echo -e "\n${BLUE}Status Nginx:${NC}"
systemctl status nginx --no-pager | grep Active

echo -e "\n${BLUE}Status PostgreSQL:${NC}"
systemctl status postgresql --no-pager | grep Active

echo -e "\n${BLUE}Testando healthcheck:${NC}"
sleep 3
HEALTH=$(curl -s http://${ONLYOFFICE_IP}/healthcheck)
if [ "$HEALTH" == "true" ]; then
    echo -e "${GREEN}✓ Healthcheck OK: $HEALTH${NC}"
else
    echo -e "${RED}✗ Healthcheck falhou: $HEALTH${NC}"
    echo -e "${YELLOW}Aguarde alguns segundos e teste novamente com:${NC}"
    echo -e "  curl http://${ONLYOFFICE_IP}/healthcheck"
fi

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║             Instalação Concluída com Sucesso! ✓            ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Configurações salvas em:${NC} ${CONFIG_FILE}\n"
cat "$CONFIG_FILE"

echo -e "\n${YELLOW}═══ PRÓXIMOS PASSOS ═══${NC}"
echo -e "1. ${BLUE}Acesse o Nextcloud:${NC} http://${NEXTCLOUD_IP}"
echo -e "2. ${BLUE}Vá em:${NC} Apps > Office & text"
echo -e "3. ${BLUE}Instale o app:${NC} ONLYOFFICE"
echo -e "4. ${BLUE}Configure em:${NC} Configurações > ONLYOFFICE"
echo -e "   ${CYAN}Document Server:${NC} http://${ONLYOFFICE_IP}/"
echo -e "   ${CYAN}JWT Secret:${NC} (conforme arquivo de configuração)"

echo -e "\n${YELLOW}═══ TROUBLESHOOTING ═══${NC}"
echo -e "Ver logs: ${CYAN}sudo tail -f /var/log/onlyoffice/documentserver/docservice/out.log${NC}"
echo -e "Reiniciar: ${CYAN}sudo supervisorctl restart all${NC}"
echo -e "Status: ${CYAN}sudo supervisorctl status${NC}"

echo -e "\n${GREEN}Instalação finalizada!${NC}\n"
