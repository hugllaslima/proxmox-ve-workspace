#!/bin/bash

# -----------------------------------------------------------------------------
# Script: reconfigure_rabbit_mq.sh
# Descrição: Reconfigura a conexão do OnlyOffice Document Server com um servidor
#            RabbitMQ externo. Este script é útil para corrigir problemas de
#            comunicação ou para atualizar as credenciais do RabbitMQ.
# Autor: Hugllas Lima
# Data de Criação: 01/08/2024
# Versão: 1.0
# Licença: GPL-3.0
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
# -----------------------------------------------------------------------------
#
# Uso:
#   sudo ./reconfigure_rabbit_mq.sh
#
# Pré-requisitos:
#   - OnlyOffice Document Server deve estar instalado.
#   - Acesso root (sudo) é necessário para modificar os arquivos de configuração
#     e reiniciar os serviços.
#
# Notas Importantes:
#   - Este script fará um backup automático dos arquivos de configuração
#     existentes em /root/onlyoffice_config_backup_<timestamp>.
#   - O script é interativo e solicitará as informações do RabbitMQ (IP, porta,
#     usuário, senha e vhost).
#   - Todos os serviços do OnlyOffice serão reiniciados durante o processo.
#
# -----------------------------------------------------------------------------


# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Correção de Configuração RabbitMQ - OnlyOffice        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser executado como root (use sudo)${NC}" 
   exit 1
fi

# Solicitar informações do RabbitMQ
echo -e "${YELLOW}Informe os dados do RabbitMQ:${NC}\n"

read -p "IP do RabbitMQ [10.10.1.231]: " RABBITMQ_HOST
RABBITMQ_HOST=${RABBITMQ_HOST:-10.10.1.231}

read -p "Porta [5672]: " RABBITMQ_PORT
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}

read -p "Usuário: " RABBITMQ_USER

read -sp "Senha: " RABBITMQ_PASS
echo

read -p "VHost [onlyoffice_vhost]: " RABBITMQ_VHOST
RABBITMQ_VHOST=${RABBITMQ_VHOST:-onlyoffice_vhost}

# Testar conexão
echo -e "\n${CYAN}Testando conexão com RabbitMQ...${NC}"
if nc -zv $RABBITMQ_HOST $RABBITMQ_PORT 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓ Conexão OK${NC}\n"
else
    echo -e "${RED}✗ Não foi possível conectar ao RabbitMQ!${NC}"
    exit 1
fi

# Parar serviços
echo -e "${CYAN}[1/5] Parando serviços OnlyOffice...${NC}"
systemctl stop ds-* 2>/dev/null || true
pkill -f "documentserver" 2>/dev/null || true
sleep 3

# Fazer backup das configurações
echo -e "${CYAN}[2/5] Fazendo backup das configurações...${NC}"
BACKUP_DIR="/root/onlyoffice_config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/onlyoffice/documentserver/*.json "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✓ Backup salvo em: $BACKUP_DIR${NC}"

# Obter JWT_SECRET e POSTGRES_PASS das configurações antigas
JWT_SECRET=$(grep -oP '"string":\s*"\K[^"]+' /etc/onlyoffice/documentserver/local.json 2>/dev/null | head -1)
POSTGRES_PASS=$(grep -oP '"dbPass":\s*"\K[^"]+' /etc/onlyoffice/documentserver/local.json 2>/dev/null)

if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo -e "${YELLOW}⚠ JWT_SECRET não encontrado, gerando novo...${NC}"
fi

if [ -z "$POSTGRES_PASS" ]; then
    echo -e "${RED}✗ Senha do PostgreSQL não encontrada!${NC}"
    read -sp "Digite a senha do PostgreSQL: " POSTGRES_PASS
    echo
fi

# Recriar configurações
echo -e "${CYAN}[3/5] Recriando arquivos de configuração...${NC}"

# Arquivo principal
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

# Arquivo de produção
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

# Arquivo default (sobrescrever configurações padrão)
cat > /etc/onlyoffice/documentserver/default.json <<EOF
{
  "rabbitmq": {
    "url": "amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}"
  }
}
EOF

# Ajustar permissões
chown -R ds:ds /etc/onlyoffice/documentserver/ 2>/dev/null || true
chmod 600 /etc/onlyoffice/documentserver/*.json

echo -e "${GREEN}✓ Configurações atualizadas${NC}"

# Verificar se supervisor está instalado
echo -e "${CYAN}[4/5] Verificando Supervisor...${NC}"
if ! command -v supervisorctl &> /dev/null; then
    echo -e "${YELLOW}Supervisor não encontrado, instalando...${NC}"
    apt install -y supervisor
    systemctl enable supervisor
    systemctl start supervisor
    sleep 3
fi

# Reiniciar serviços
echo -e "${CYAN}[5/5] Reiniciando serviços...${NC}"

# Tentar com supervisor
if command -v supervisorctl &> /dev/null; then
    supervisorctl reread 2>/dev/null
    supervisorctl update 2>/dev/null
    supervisorctl restart all 2>/dev/null
    sleep 10
else
    # Tentar com systemctl
    for service in ds-docservice ds-converter ds-metrics ds-example; do
        systemctl restart $service 2>/dev/null || true
    done
    sleep 10
fi

# Reiniciar Nginx
systemctl restart nginx

echo -e "\n${GREEN}═══ Verificação Final ═══${NC}\n"

# Verificar configuração
echo -e "${CYAN}Configuração RabbitMQ aplicada:${NC}"
grep -A 3 '"rabbitmq"' /etc/onlyoffice/documentserver/local.json | grep -v password

# Aguardar inicialização
echo -e "\n${YELLOW}Aguardando serviços inicializarem (30 segundos)...${NC}"
sleep 30

# Verificar logs
echo -e "\n${CYAN}Últimas linhas do log:${NC}"
tail -10 /var/log/onlyoffice/documentserver/docservice/out.log

# Testar healthcheck
echo -e "\n${CYAN}Testando healthcheck...${NC}"
HEALTH=$(curl -s http://localhost/healthcheck 2>/dev/null)
if [ "$HEALTH" == "true" ]; then
    echo -e "${GREEN}✓ Healthcheck OK!${NC}"
else
    echo -e "${YELLOW}⚠ Healthcheck: $HEALTH${NC}"
    echo -e "${YELLOW}Aguarde mais alguns minutos e teste novamente.${NC}"
fi

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Correção Concluída!                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "1. Aguarde 2-3 minutos para inicialização completa"
echo -e "2. Acesse: http://$(hostname -I | awk '{print $1}')/welcome/"
echo -e "3. Monitore os logs: ${CYAN}sudo tail -f /var/log/onlyoffice/documentserver/docservice/out.log${NC}"

echo -e "\n${CYAN}Backup das configurações antigas:${NC} $BACKUP_DIR"
