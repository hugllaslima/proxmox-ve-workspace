#!/bin/bash

#==============================================================================
# Script: install_pg.sh
# Descrição: Instalação e configuração do PostgreSQL 16 com TimescaleDB
# Autor: Hugllas Lima
# Data: 10/09/2026
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-postgres
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Atualização dos pacotes do sistema e instalação de pré-requisitos
# 2. Adição do repositório oficial do PostgreSQL (PGDG)
# 3. Adição do repositório oficial do TimescaleDB
# 4. Instalação do PostgreSQL 16 e TimescaleDB
# 5. Configuração de acessos de rede (listen_addresses e pg_hba.conf)
# 6. Otimização do banco de dados com timescaledb-tune
# 7. Reinicialização e ativação do serviço no boot
#==============================================================================

echo "=================================================="
echo " Instalador: PostgreSQL 16 + TimescaleDB (Ubuntu) "
echo "=================================================="

echo "[1/6] Atualizando pacotes do sistema..."
apt update && apt upgrade -y
apt install -y gnupg postgresql-common apt-transport-https lsb-release wget

echo "[2/6] Adicionando repositório do PostgreSQL..."
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

echo "[3/6] Adicionando repositório do TimescaleDB..."
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list

echo "[4/6] Instalando PostgreSQL 16 e TimescaleDB..."
apt update
apt install -y postgresql-16 timescaledb-2-postgresql-16

echo "[5/6] Configurando acessos de rede..."
read -p "Deseja liberar acesso externo (ex: pgAdmin) para este servidor? (s/n): " ALLOW_EXT
if [ "$ALLOW_EXT" = "s" ] || [ "$ALLOW_EXT" = "S" ]; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf
    echo "Acesso externo LIBERADO."
else
    echo "Acesso externo BLOQUEADO (Apenas localhost)."
fi

echo "[6/6] Otimizando o banco de dados com timescaledb-tune..."
timescaledb-tune --quiet --yes

systemctl restart postgresql
systemctl enable postgresql

echo "=================================================="
echo " Instalação concluída com sucesso! "
echo "=================================================="