#!/bin/bash

#==============================================================================
# Script: create_db.sh
# Descrição: Assistente de criação de banco de dados, usuário e extensão TimescaleDB
# Autor: Hugllas Lima
# Data: 10/09/2026
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Coleta interativa de parâmetros (Banco, Usuário e Senha segura)
# 2. Criação de usuário e banco de dados com ownership atribuído
# 3. Concessão de todos os privilégios ao usuário na base
# 4. Habilitação opcional da extensão TimescaleDB
# 5. Detecção do IP do servidor e exibição da URL de conexão (Connection String)
#==============================================================================

echo "=================================================="
echo " Assistente de Criação de Banco de Dados e Usuário"
echo "=================================================="

read -p "Digite o nome do NOVO BANCO DE DADOS (ex: zabbix): " DBNAME
read -p "Digite o nome do NOVO USUÁRIO (ex: zabbix): " DBUSER
read -s -p "Digite a SENHA para este usuário: " DBPASS
echo ""

echo "Criando usuário e banco de dados..."
sudo -u postgres psql -c "CREATE USER $DBUSER WITH PASSWORD '$DBPASS';"
sudo -u postgres psql -c "CREATE DATABASE $DBNAME OWNER $DBUSER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DBNAME TO $DBUSER;"

echo ""
read -p "Deseja habilitar a extensão TimescaleDB neste banco? (Recomendado para Zabbix) (s/n): " ENABLE_TS
if [ "$ENABLE_TS" = "s" ] || [ "$ENABLE_TS" = "S" ]; then
    echo "Habilitando a extensão TimescaleDB no banco $DBNAME..."
    sudo -u postgres psql -d $DBNAME -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
    TS_STATUS="Ativada"
else
    TS_STATUS="Desativada"
fi

# Captura o IP principal do container automaticamente
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "=================================================="
echo " SUCESSO! "
echo " Banco: $DBNAME "
echo " Usuário: $DBUSER "
echo " Extensão TimescaleDB: $TS_STATUS "
echo " "
echo " String de Conexão (URL):"
echo " postgresql://$DBUSER:$DBPASS@$SERVER_IP:5432/$DBNAME"
echo "=================================================="