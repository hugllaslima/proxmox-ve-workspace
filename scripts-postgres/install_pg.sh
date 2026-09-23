#!/bin/bash

#==============================================================================
# Script: install_pg.sh
# Descrição: Instalação e configuração do PostgreSQL 16 com TimescaleDB
# Autor: Hugllas Lima
# Data: 10/09/2026
# Versão: 1.2 (Melhorado com gerenciamento de redes)
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

echo "=================================================="
echo " Instalador: PostgreSQL 16 + TimescaleDB (Ubuntu) "
echo "=================================================="

echo "[1/8] Atualizando pacotes do sistema..."
apt update && apt upgrade -y
apt install -y gnupg postgresql-common apt-transport-https lsb-release wget

echo "[2/8] Adicionando repositório do PostgreSQL..."
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

echo "[3/8] Adicionando repositório do TimescaleDB..."
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list

echo "[4/8] Instalando PostgreSQL 16 e TimescaleDB..."
apt update
apt install -y postgresql-16 timescaledb-2-postgresql-16

echo "[5/8] Definindo senha do usuário 'postgres'..."
read -s -p "Digite a SENHA para o usuário 'postgres': " PG_PASSWORD
echo ""
read -s -p "Confirme a SENHA: " PG_PASSWORD_CONFIRM
echo ""

if [ "$PG_PASSWORD" != "$PG_PASSWORD_CONFIRM" ]; then
    echo "❌ ERRO: As senhas não conferem!"
    exit 1
fi

# Define a senha do usuário postgres
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';"
echo "✓ Senha do usuário 'postgres' definida com sucesso."

echo "[6/8] Configurando acessos de rede..."
read -p "Deseja liberar acesso externo (ex: pgAdmin) para este servidor? (s/n): " ALLOW_EXT

if [ "$ALLOW_EXT" = "s" ] || [ "$ALLOW_EXT" = "S" ]; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf

    echo ""
    echo "Configurando redes autorizadas para acesso..."
    echo "Exemplos:"
    echo "  - 0.0.0.0/0 (Qualquer IP - Use com cuidado!)"
    echo "  - 10.10.0.0/16 (Rede 10.10.x.x)"
    echo "  - 192.168.1.0/24 (Rede 192.168.1.x)"
    echo "  - 10.10.1.160/32 (IP específico)"
    echo ""

    # Array para armazenar as redes
    declare -a NETWORKS
    NETWORK_COUNT=0

    while true; do
        read -p "Digite a rede/IP que deseja liberar (ou 'pronto' para finalizar): " NETWORK_INPUT

        if [ "$NETWORK_INPUT" = "pronto" ] || [ "$NETWORK_INPUT" = "PRONTO" ]; then
            if [ $NETWORK_COUNT -eq 0 ]; then
                echo "❌ Você precisa adicionar pelo menos uma rede!"
                continue
            fi
            break
        fi

        # Validação básica de CIDR
        if [[ $NETWORK_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
            NETWORKS+=("$NETWORK_INPUT")
            ((NETWORK_COUNT++))
            echo "✓ Rede adicionada: $NETWORK_INPUT"
        else
            echo "❌ Formato inválido! Use o formato CIDR (ex: 10.10.0.0/16 ou 10.10.1.160/32)"
        fi
    done

    # Adiciona as redes ao pg_hba.conf
    echo ""
    echo "Adicionando redes ao pg_hba.conf..."
    for NETWORK in "${NETWORKS[@]}"; do
        echo "host    all             all             $NETWORK               scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf
        echo "✓ Rede liberada: $NETWORK"
    done

    echo "✓ Acesso externo LIBERADO para ${NETWORK_COUNT} rede(s)."
else
    echo "✓ Acesso externo BLOQUEADO (Apenas localhost)."
fi

echo "[7/8] Otimizando o banco de dados com timescaledb-tune..."
timescaledb-tune --quiet --yes

echo "[8/8] Reiniciando serviço PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

echo ""
echo "=================================================="
echo " ✓ Instalação concluída com sucesso! "
echo "=================================================="
echo ""
echo "📝 Informações de Acesso:"
echo "   Usuário: postgres"
echo "   Porta: 5432"
echo "   Acesso Local: psql -U postgres"
echo "   Acesso Remoto: psql -h <IP_DO_SERVIDOR> -U postgres"
echo ""