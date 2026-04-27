#!/bin/bash
################################################################################

# Script: Correção de Disco NTFS em Dual Boot
# Descrição: Corrige problemas de permissão "somente leitura" em discos NTFS
#            causados pelo Fast Startup do Windows em sistemas dual boot.
# Autor: Hugllas
# Data: 18/11/2025
# Uso: ./read_only_mounted_disk.sh
#
# O que faz:
# 1. Desmonta o disco NTFS forçadamente
# 2. Remove o estado de hibernação deixado pelo Windows
# 3. Remonta o disco com permissões corretas
#
# Disco: /dev/sdb1 → /media/hugllas-lima/Documentos

################################################################################

# CONFIGURAÇÃO DO /etc/fstab (caso precise reconfigurar):
# --------------------------------------------------------
# 1. Obter o UUID do disco:
#    sudo blkid /dev/sdb1   # Substitua /dev/sdb1 pelo seu disco local
#
# 2. Editar o arquivo fstab:
#    sudo nano /etc/fstab
#
# 3. Adicionar a linha (substituir UUID pelo valor obtido):
#    UUID=FCEC347BEC34326E  /media/hugllas-lima/Documentos  ntfs-3g  uid=1000,gid=1000,umask=0022,defaults  0  0
#
# 4. Testar a configuração:
#    sudo mount -a
#
################################################################################

echo "=== Corrigindo disco NTFS ==="
echo ""

# Força o desmonte matando processos que estão usando
echo "1. Desmontando disco..."
sudo fuser -km /media/hugllas-lima/Documentos 2>/dev/null
sudo umount /media/hugllas-lima/Documentos 2>/dev/null

# Corrige o sistema de arquivos NTFS
echo "2. Corrigindo erros do NTFS..."
sudo ntfsfix /dev/sdb1

# Remonta o disco
echo "3. Remontando disco..."
sudo mount -a

# Verifica o resultado
echo ""
echo "=== Status do disco ==="
mount | grep Documentos

echo ""
echo "Pronto! Tente salvar arquivos agora."
