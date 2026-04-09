#!/bin/bash
# ==============================================================================
# SCRIPT PARA CRIAÇÃO DE TEMPLATE CLOUD-INIT UBUNTU 24.04 NO PROXMOX VE
# ==============================================================================
#
# Script: ubuntu_24_04_template.sh
#
# Descrição:
#   Este script automatiza a criação de um template de máquina virtual (VM)
#   Ubuntu 24.04 utilizando Cloud-Init no Proxmox VE.
#
# Funcionalidades:
#   - Coleta de dados (ID, Nome, Storage, Tamanho do disco).
#   - Download e verificação da imagem Ubuntu 24.04 Cloud-Init.
#   - Criação da estrutura base da VM.
#   - Importação do disco para o storage selecionado.
#   - Configuração de Hardware e Cloud-Init (virtio, boot, serial).
#   - Redimensionamento do disco.
#   - Revisão das configurações e conversão para Template.
#
# Autor:
#   Hugllas R. S. Lima
#
# Contato:
#   - https://www.linkedin.com/in/hugllas-r-s-lima/
#   - https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-template-cloud-init
#
# Versão:
#   1.0
#
# Data:
#   09/04/2026
#
# Pré-requisitos:
#   - Acesso root no nó Proxmox VE.
#   - Conexão com a internet para baixar a imagem cloud-init do Ubuntu.
#   - Espaço suficiente no storage de destino para o disco da VM.
#
# Como usar:
#   1. chmod +x ubuntu_24_04_template.sh
#   2. ./ubuntu_24_04_template.sh
#   3. Siga as instruções interativas para configurar o template.
#
# Onde Utilizar:
#   - Diretamente no nó Proxmox VE (Shell).
#
# Notas Importantes:
#   - A imagem baixada ('noble-server-cloudimg-amd64.img') será armazenada em
#     '/var/lib/vz/template/iso'.
#   - A VM resultante será convertida em template e não poderá ser iniciada
#     diretamente.
#
# ------------------------------------------------------------------------------

# ==============================================================================
# INICIO DO SCRIPT
# ==============================================================================

# Cores para facilitar a leitura
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Proxmox Cloud-Init Template Creator ===${NC}"

# 1. Pergunta o ID da VM
read -p "Digite o ID para a nova VM Template (ex: 9000): " VM_ID
if qm status $VM_ID >/dev/null 2>&1; then
    echo -e "${RED}Erro: O ID $VM_ID já está em uso!${NC}"
    exit 1
fi

# 2. Pergunta o Nome da VM
read -p "Digite o Nome para o Template (ex: ubuntu-24.04-template): " VM_NAME

# 3. Lista Storages disponíveis e pergunta onde alocar
echo -e "\nStorages disponíveis:"
pvesm status | awk 'NR>1 {print "- " $1}'
read -p "Em qual storage o disco será alocado? (ex: local): " STORAGE

# 4. Pergunta o tamanho do disco
read -p "Qual o tamanho final do disco em GB? (ex: 20): " DISK_SIZE

# --- Início do Processo ---

IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE_NAME="noble-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/$IMAGE_NAME"

echo -e "\n${GREEN}[1/6] Baixando/Verificando imagem Ubuntu 24.04...${NC}"
mkdir -p $IMAGE_DIR
if [ ! -f "$IMAGE_DIR/$IMAGE_NAME" ]; then
    wget -P $IMAGE_DIR $IMAGE_URL || { echo -e "${RED}Erro ao baixar imagem!${NC}"; exit 1; }
else
    echo "Imagem já existe no diretório."
fi

echo -e "${GREEN}[2/6] Criando a estrutura da VM...${NC}"
qm create $VM_ID --name "$VM_NAME" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --ostype l26 --agent 1 || exit 1

echo -e "${GREEN}[3/6] Importando disco (isso pode demorar um pouco)...${NC}"
# Captura a saída para extrair o nome do arquivo criado se necessário
IMPORT_LOG=$(qm importdisk $VM_ID "$IMAGE_DIR/$IMAGE_NAME" $STORAGE)
echo "$IMPORT_LOG"

# Tratativa para storage tipo diretório (local) ou LVM
if [[ "$STORAGE" == "local" ]]; then
    DISK_EXT=".raw"
    DISK_PATH="$STORAGE:$VM_ID/vm-$VM_ID-disk-0$DISK_EXT"
else
    DISK_PATH="$STORAGE:vm-$VM_ID-disk-0"
fi

echo -e "${GREEN}[4/6] Configurando Hardware e Cloud-Init...${NC}"
qm set $VM_ID --virtio0 "$DISK_PATH" >/dev/null
qm set $VM_ID --ide2 "$STORAGE:cloudinit" >/dev/null
qm set $VM_ID --boot order=virtio0 >/dev/null
qm set $VM_ID --serial0 socket --vga serial0 >/dev/null

echo -e "${GREEN}[5/6] Redimensionando para ${DISK_SIZE}G...${NC}"
qm resize $VM_ID virtio0 ${DISK_SIZE}G >/dev/null

echo -e "\n${GREEN}=== Revisão das Configurações ===${NC}"
qm config $VM_ID
echo -e "------------------------------------------------"

# 5. Confirmação Final
read -p "As configurações estão corretas? Digite 's' para concluir e converter em Template: " CONFIRM

if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
    echo -e "${GREEN}[6/6] Convertendo para Template...${NC}"
    qm template $VM_ID
    echo -e "${GREEN}Sucesso! Template $VM_ID criado.${NC}"
else
    echo -e "${RED}Processo interrompido. A VM $VM_ID foi criada mas NÃO foi convertida em template.${NC}"
fi