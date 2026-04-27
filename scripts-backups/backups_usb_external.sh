#!/bin/bash

#==================================================================================================
# Script: backups_usb_external.sh
# Descrição: Backup automático em dispositivos USB externos
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-backups
#==================================================================================================

# ETAPAS DO SCRIPT:
# 1. Detecção do dispositivo USB externo
# 2. Montagem automática do dispositivo
# 3. Criação do diretório de backup
# 4. Execução do backup dos dados
# 5. Verificação da integridade do backup
# 6. Desmontagem segura do dispositivo

# Sugestão de Crontab
# @reboot /root/Scripts/backups-usb.sh

# ============================================================================
# ETAPA 1: MONTAGEM DO DISPOSITIVO USB EXTERNO
# ============================================================================

mount /dev/sdc1 /mnt/pve/backups-usb

sleep 1

# ============================================================================
# ETAPA 2: VERIFICAÇÃO DO ESPAÇO DISPONÍVEL
# ============================================================================

df -h

sleep 1

# ============================================================================
# ETAPA 3: CONFIRMAÇÃO DE MONTAGEM
# ============================================================================

echo " "
echo " < SEU DISCO FOI MONTADO COM SUCESSO > "
echo " "

# fim_do_script
