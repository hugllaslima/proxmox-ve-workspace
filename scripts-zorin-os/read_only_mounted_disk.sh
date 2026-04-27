#!/bin/bash
# ==============================================================================
# SCRIPT PARA CORREÇÃO DE DISCO NTFS EM DUAL BOOT (VERSÃO INTERATIVA)
# ==============================================================================
#
# Script: read_only_mounted_disk.sh
#
# Descrição:
#   Corrige problemas de permissão "somente leitura" em discos NTFS
#   causados pelo Fast Startup do Windows em sistemas dual boot.
#
# Funcionalidades:
#   - Lista as partições NTFS disponíveis.
#   - Pergunta qual partição deseja corrigir.
#   - Desmonta o disco NTFS forçadamente (se estiver montado).
#   - Remove o estado de hibernação deixado pelo Windows (ntfsfix).
#   - Remonta o disco com permissões corretas (mount -a).
#
# Autor:
#   Hugllas R. S. Lima
#
# Contato:
#   - https://www.linkedin.com/in/hugllas-r-s-lima/
#   - https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-zorin-os
#
# Versão:
#   1.0
#
# Data:
#   27/04/2026
#
# Pré-requisitos:
#   - Acesso root (sudo).
#   - Utilitários 'ntfs-3g' e 'fuser' instalados.
#
# Como usar:
#   1. chmod +x read_only_mounted_disk.sh
#   2. sudo ./read_only_mounted_disk.sh
#   3. Siga as instruções na tela para selecionar o disco.
#
# Onde Utilizar:
#   - Em distribuições Linux (Zorin OS, Ubuntu, etc.) em dual boot com Windows.
#
# Notas Importantes:
#   - É altamente recomendado desativar o "Fast Startup" no Windows
#     para evitar a necessidade frequente de rodar este script.
#
# ------------------------------------------------------------------------------

# ==============================================================================
# INICIO DO SCRIPT
# ==============================================================================

# Cores para o terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem cor

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, execute este script como root (usando sudo).${NC}"
  exit 1
fi

echo -e "${GREEN}=== Corretor de Disco NTFS (Dual Boot) ===${NC}\n"

# Lista apenas as partições formatadas em NTFS
echo -e "${YELLOW}Procurando partições NTFS no sistema...${NC}"
NTFS_PARTITIONS=$(blkid -t TYPE="ntfs" -o device)

if [ -z "$NTFS_PARTITIONS" ]; then
    echo -e "${RED}Nenhuma partição NTFS encontrada no sistema.${NC}"
    exit 1
fi

# Exibe as partições encontradas com seus respectivos tamanhos e rótulos
echo -e "\nPartições NTFS disponíveis:"
echo "------------------------------------------------"
lsblk -o NAME,SIZE,LABEL,MOUNTPOINT -p | grep -i "ntfs\|NAME" | grep -v "loop"
echo "------------------------------------------------"

# Pede para o usuário escolher a partição
echo ""
read -p "Digite o caminho da partição que deseja corrigir (Ex: /dev/sdb1): " SELECTED_PARTITION

# Verifica se a partição digitada é válida e é NTFS
if ! blkid -t TYPE="ntfs" -o device | grep -q "^$SELECTED_PARTITION$"; then
    echo -e "${RED}Erro: A partição '$SELECTED_PARTITION' não é válida ou não é NTFS.${NC}"
    exit 1
fi

# Descobre onde a partição está montada atualmente
MOUNT_POINT=$(lsblk -n -o MOUNTPOINT "$SELECTED_PARTITION")

echo -e "\n${GREEN}[1/3] Preparando para corrigir $SELECTED_PARTITION...${NC}"

if [ -n "$MOUNT_POINT" ]; then
    echo "A partição está montada em: $MOUNT_POINT"
    echo "Desmontando disco..."
    fuser -km "$MOUNT_POINT" 2>/dev/null
    umount "$MOUNT_POINT" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Falha ao desmontar a partição. Ela pode estar em uso.${NC}"
        exit 1
    fi
else
    echo "A partição não está montada no momento. Prosseguindo..."
fi

# Corrige o sistema de arquivos NTFS
echo -e "\n${GREEN}[2/3] Corrigindo erros do NTFS (removendo hibernação do Windows)...${NC}"
ntfsfix -d "$SELECTED_PARTITION"

# Remonta os discos (baseado no fstab)
echo -e "\n${GREEN}[3/3] Remontando discos (sudo mount -a)...${NC}"
mount -a

# Verifica o resultado
echo -e "\n${GREEN}=== Status do disco ===${NC}"
if [ -n "$MOUNT_POINT" ]; then
    mount | grep "$SELECTED_PARTITION" || echo -e "${YELLOW}Aviso: A partição não foi montada automaticamente. Verifique seu /etc/fstab.${NC}"
else
    # Se não estava montada antes, tenta achar onde foi montada agora
    NEW_MOUNT=$(lsblk -n -o MOUNTPOINT "$SELECTED_PARTITION")
    if [ -n "$NEW_MOUNT" ]; then
        echo "Partição montada com sucesso em: $NEW_MOUNT"
    else
        echo -e "${YELLOW}A partição foi corrigida, mas não está configurada para montar automaticamente no /etc/fstab.${NC}"
    fi
fi

echo -e "\n${GREEN}Pronto! A correção foi aplicada.${NC}"
