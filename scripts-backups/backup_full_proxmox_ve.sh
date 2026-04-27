#!/bin/bash

#==============================================================================
# Script: backup_full_proxmox_ve.sh
# Descrição: Backup completo das configurações do Proxmox VE
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-backups
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Criação do diretório de backup
# 2. Backup das configurações do Proxmox VE
# 3. Backup dos arquivos de configuração de VMs
# 4. Backup dos arquivos de configuração de containers LXC
# 5. Compactação dos arquivos de backup
# 6. Limpeza de backups antigos

# ============================================================================
# ETAPA 1: CONFIGURAÇÕES INICIAIS E CRIAÇÃO DO DIRETÓRIO
# ============================================================================

# strings de identificacao do host e data
NOME_ARQ=`date +'%d%m%y-%H%M'`
DIR_BK=/root/backup/$HOSTNAME.$NOME_ARQ
HOJE=$HOSTNAME.$NOME_ARQ

cd /root/backup/
mkdir -p $HOJE

# ============================================================================
# ETAPA 2: BACKUP DAS CONFIGURAÇÕES CRÍTICAS DO PROXMOX VE
# ============================================================================

#compacta os arquivos criticos de reconstrucao
tar -zcf $DIR_BK/pve-cluster-backup.tar.gz /var/lib/pve-cluster
tar -zcf $DIR_BK/ssh-backup.tar.gz /root/.ssh
tar -zcf $DIR_BK/corosync-backup.tar.gz /etc/corosync
tar -zcf $DIR_BK/iscsi-backup.tar.gz /etc/iscsi
tar -zcf $DIR_BK/etc-backup.tar.gz /etc

# ============================================================================
# ETAPA 3: BACKUP DOS REPOSITÓRIOS E CONFIGURAÇÕES DE REDE
# ============================================================================

#compacta repositorios ativos
tar -zcf $DIR_BK/apt-backup.tar.gz /etc/apt 

#salva configuracoes de rede
cp /etc/hosts $DIR_BK/hosts
cp /etc/network/interfaces $DIR_BK/interfaces

# ============================================================================
# ETAPA 4: BACKUP DA LISTA DE PACOTES INSTALADOS
# ============================================================================

#salva pacotes instalados
aptitude --display-format '%p' search '?installed!?automatic' > $DIR_BK/pkg.instalados

# ============================================================================
# ETAPA 5: COMPACTAÇÃO FINAL E LIMPEZA
# ============================================================================

#compacta pasta com a data corrente e apaga
tar -zcf $HOJE.tar.gz $HOJE
rm -rf $HOJE 

# ============================================================================
# INSTRUÇÕES PARA RESTAURAÇÃO
# ============================================================================

## pra reinstalar depois:
## sudo xargs aptitude --schedule-only install < instalados ; sudo aptitude install

## pra restaurar precisa destas, sugerida no wiki
#    /root/pve-cluster-backup.tar.gz
#    /root/ssh-backup.tar.gz
#    /root/corosync-backup.tar.gz
#    /root/hosts
#    /root/interfaces


# echo de resultado
#echo "Backup foi realizado com sucesso."
#echo "Diretório: $HOJE";
exit 0

#fin_script
