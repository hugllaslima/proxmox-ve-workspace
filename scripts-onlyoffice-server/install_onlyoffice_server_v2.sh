#!/bin/bash

# -----------------------------------------------------------------------------
# Script: install_onlyoffice_server_v2.sh
# Descrição: Instala e configura o OnlyOffice Document Server com RabbitMQ externo.
# Autor: Hugllas Lima
# Data de Criação: 20/10/2023
# Versão: 3.1
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./install_onlyoffice_server_v2.sh
#
# Pré-requisitos:
#   - Ubuntu Server 24.04 LTS.
#   - Permissões de root ou sudo.
#   - Servidor RabbitMQ externo já configurado e acessível.
#   - Servidor Nextcloud (opcional) para integração.
#
# Notas Importantes:
#   - Este script é interativo e solicitará informações como IPs e senhas.
#   - As credenciais geradas são salvas em /root/onlyoffice_credentials.txt.
#   - É a versão recomendada para novas instalações.
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
    echo -e "${BLUE}║            Instalação OnlyOffice Document Server           ║${NC}"
    echo -e "${BLUE}║           Ubuntu Server 24.04 LTS - v3.1 CORRIGIDA         ║${NC}"
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
    apt install -y netcat-openbsd >/dev/null 2>&1
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
echo -e "${GREEN}[1/10] Atualizando sistema...${NC}"
apt update && apt upgrade -y
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release netcat-openbsd software-properties-common

# 2. Instalar PostgreSQL
echo -e "${GREEN}[2/10] Instalando PostgreSQL...${NC}"
apt install -y postgresql postgresql-contrib

# Aguardar PostgreSQL inicializar COMPLETAMENTE
echo -e "${YELLOW}Aguardando PostgreSQL inicializar (15 segundos)...${NC}"
sleep 15

# Verificar se está rodando
if ! systemctl is-active --quiet postgresql; then
    echo -e "${YELLOW}PostgreSQL não iniciou automaticamente, tentando iniciar manualmente...${NC}"
    systemctl start postgresql
    sleep 5
fi

# Verificar novamente
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓ PostgreSQL está rodando${NC}"
else
    echo -e "${RED}✗ ERRO: PostgreSQL não está rodando!${NC}"
    echo -e "${YELLOW}Tentando diagnosticar...${NC}"
    systemctl status postgresql --no-pager
    exit 1
fi

# Configurar banco de dados
echo -e "${CYAN}Configurando banco de dados PostgreSQL...${NC}"

# Remover banco/usuário se existirem (para instalação limpa)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS onlyoffice;" 2>/dev/null
sudo -u postgres psql -c "DROP USER IF EXISTS onlyoffice;" 2>/dev/null

# Criar banco e usuário
sudo -u postgres psql -c "CREATE DATABASE onlyoffice;"
sudo -u postgres psql -c "CREATE USER onlyoffice WITH PASSWORD '${POSTGRES_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE onlyoffice TO onlyoffice;"
sudo -u postgres psql -c "ALTER DATABASE onlyoffice OWNER TO onlyoffice;"

# Dar permissões adicionais no PostgreSQL 15+
sudo -u postgres psql -d onlyoffice -c "GRANT ALL ON SCHEMA public TO onlyoffice;"
sudo -u postgres psql -d onlyoffice -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO onlyoffice;"
sudo -u postgres psql -d onlyoffice -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO onlyoffice;"

# Testar conexão
echo -e "${CYAN}Testando conexão com banco de dados...${NC}"
if sudo -u postgres psql -d onlyoffice -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexão com banco de dados OK${NC}"
else
    echo -e "${RED}✗ ERRO: Não foi possível conectar ao banco de dados${NC}"
    exit 1
fi

# 3. Instalar Erlang (necessário para comunicação com RabbitMQ)
echo -e "${GREEN}[3/10] Instalando Erlang...${NC}"
apt install -y erlang-base erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
               erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
               erlang-runtime-tools erlang-snmp erlang-ssl erlang-syntax-tools \
               erlang-tftp erlang-tools erlang-xmerl

# 4. Adicionar chave GPG do OnlyOffice
echo -e "${GREEN}[4/10] Adicionando chave GPG do OnlyOffice...${NC}"
mkdir -p /usr/share/keyrings

if ! curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --dearmor -o /usr/share/keyrings/onlyoffice.gpg 2>/dev/null; then
    echo -e "${YELLOW}Método 1 falhou, tentando alternativo...${NC}"
    gpg --keyserver keyserver.ubuntu.com --recv-keys CB2DE8E5
    gpg --export CB2DE8E5 > /usr/share/keyrings/onlyoffice.gpg
fi

# 5. Adicionar repositório OnlyOffice
echo -e "${GREEN}[5/10] Adicionando repositório OnlyOffice...${NC}"
echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list

# 6. Preparar variáveis de ambiente
echo -e "${GREEN}[6/10] Preparando ambiente...${NC}"
export DS_RABBITMQ_HOST=$RABBITMQ_HOST
export DS_RABBITMQ_USER=$RABBITMQ_USER
export DS_RABBITMQ_PWD=$RABBITMQ_PASS
export DS_RABBITMQ_VHOST=$RABBITMQ_VHOST

# 7. Instalar OnlyOffice
echo -e "${GREEN}[7/10] Instalando OnlyOffice Document Server...${NC}"
echo -e "${YELLOW}Nota: Avisos sobre RabbitMQ local são normais (estamos usando externo).${NC}"
echo -e "${YELLOW}Esta etapa pode demorar alguns minutos...${NC}"

apt update

# Configurar variáveis de ambiente para a instalação
export DEBIAN_FRONTEND=noninteractive
export DS_RABBITMQ_HOST=$RABBITMQ_HOST
export DS_RABBITMQ_USER=$RABBITMQ_USER
export DS_RABBITMQ_PWD=$RABBITMQ_PASS
export DS_RABBITMQ_VHOST=$RABBITMQ_VHOST

# Instalar OnlyOffice
apt install -y onlyoffice-documentserver

# Verificar se a instalação foi bem-sucedida
if dpkg -l | grep -q "ii  onlyoffice-documentserver"; then
    echo -e "${GREEN}✓ OnlyOffice instalado com sucesso${NC}"
else
    echo -e "${RED}✗ ERRO: Falha na instalação do OnlyOffice${NC}"
    echo -e "${YELLOW}Tentando corrigir...${NC}"

    # Tentar corrigir problemas de instalação
    apt-get install -f -y
    dpkg --configure -a

    if dpkg -l | grep -q "ii  onlyoffice-documentserver"; then
        echo -e "${GREEN}✓ OnlyOffice corrigido e instalado${NC}"
    else
        echo -e "${RED}✗ Não foi possível instalar o OnlyOffice${NC}"
        exit 1
    fi
fi

# 8. Configurar banco de dados
echo -e "${GREEN}[8/10] Aplicando schema do banco de dados...${NC}"

if [ -f "/var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql" ]; then
    sudo -u postgres psql -d onlyoffice -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql 2>/dev/null || echo "  Schema já aplicado ou erro ao aplicar"
else
    echo -e "${YELLOW}⚠ Arquivo de schema não encontrado, será criado na primeira execução${NC}"
fi

# 9. Parar RabbitMQ local se existir
echo -e "${GREEN}[9/10] Desabilitando RabbitMQ local...${NC}"
if systemctl is-active --quiet rabbitmq-server 2>/dev/null; then
    systemctl stop rabbitmq-server
    systemctl disable rabbitmq-server
    echo -e "${GREEN}✓ RabbitMQ local desabilitado${NC}"
else
    echo -e "${CYAN}⊘ RabbitMQ local não está instalado${NC}"
fi

# 10. Configurar OnlyOffice
echo -e "${GREEN}[10/10] Configurando OnlyOffice...${NC}"

# Criar diretório de configuração
mkdir -p /etc/onlyoffice/documentserver

# Backup de configurações existentes
if [ -f "/etc/onlyoffice/documentserver/local.json" ]; then
    cp /etc/onlyoffice/documentserver/local.json /etc/onlyoffice/documentserver/local.json.bak
fi

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

# Ajustar permissões
chown -R ds:ds /etc/onlyoffice/documentserver/ 2>/dev/null || true
chmod 600 /etc/onlyoffice/documentserver/local*.json

# Reiniciar serviços
echo -e "${BLUE}Reiniciando serviços OnlyOffice...${NC}"

if command -v supervisorctl &> /dev/null; then
    supervisorctl restart all 2>/dev/null || echo "Supervisor não disponível, usando systemctl"
fi

sleep 5

if systemctl is-active --quiet nginx; then
    systemctl restart nginx
else
    systemctl start nginx
fi

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
Password: ${RABBITMQ_PASS}
VHost: ${RABBITMQ_VHOST}
URL: amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}

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
if command -v supervisorctl &> /dev/null; then
    supervisorctl status 2>/dev/null || echo "Supervisor não disponível"
else
    echo "Supervisor não instalado"
fi

echo -e "\n${BLUE}Status Nginx:${NC}"
systemctl status nginx --no-pager | grep Active

echo -e "\n${BLUE}Status PostgreSQL:${NC}"
systemctl status postgresql --no-pager | grep Active

echo -e "\n${BLUE}Testando healthcheck:${NC}"
sleep 5
HEALTH=$(curl -s http://${ONLYOFFICE_IP}/healthcheck 2>/dev/null)
if [ "$HEALTH" == "true" ]; then
    echo -e "${GREEN}✓ Healthcheck OK: $HEALTH${NC}"
else
    echo -e "${YELLOW}⚠ Healthcheck: $HEALTH${NC}"
    echo -e "${YELLOW}Aguarde alguns minutos e teste novamente com:${NC}"
    echo -e "  ${CYAN}curl http://${ONLYOFFICE_IP}/healthcheck${NC}"
    echo -e "${YELLOW}Os serviços podem levar até 2 minutos para inicializar completamente.${NC}"
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
echo -e "1. ${BLUE}Aguarde 2-3 minutos para os serviços iniciarem completamente${NC}"
echo -e "2. ${BLUE}Teste o healthcheck:${NC} curl http://${ONLYOFFICE_IP}/healthcheck"
echo -e "3. ${BLUE}Acesse o Nextcloud:${NC} http://${NEXTCLOUD_IP}"
echo -e "4. ${BLUE}Vá em:${NC} Apps > Office & text"
echo -e "5. ${BLUE}Instale o app:${NC} ONLYOFFICE"
echo -e "6. ${BLUE}Configure em:${NC} Configurações > ONLYOFFICE"
echo -e "   ${CYAN}Document Server:${NC} http://${ONLYOFFICE_IP}/"
echo -e "   ${CYAN}JWT Secret:${NC} (conforme arquivo de configuração)"

echo -e "\n${YELLOW}═══ TROUBLESHOOTING ═══${NC}"
echo -e "Ver logs: ${CYAN}sudo tail -f /var/log/onlyoffice/documentserver/docservice/out.log${NC}"
echo -e "Reiniciar: ${CYAN}sudo supervisorctl restart all${NC}"
echo -e "Status: ${CYAN}sudo supervisorctl status${NC}"
echo -e "Nginx: ${CYAN}sudo systemctl status nginx${NC}"
echo -e "PostgreSQL: ${CYAN}sudo systemctl status postgresql${NC}"

echo -e "\n${GREEN}Instalação finalizada!${NC}\n"
