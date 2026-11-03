#!/bin/bash
set -Eeuo pipefail

# ==============================================================================
# SCRIPT PARA CRIAÇÃO DE TEMPLATE CLOUD-INIT DEBIAN 11 NO PROXMOX VE
# ==============================================================================
#
# Script: debian_11_template.sh
#
# Descrição:
#   Este script automatiza a criação de um template de máquina virtual (VM)
#   Debian 11 (Bullseye) utilizando Cloud-Init no Proxmox VE (versões 8.x.x e 9.x.x).
#
# Funcionalidades:
#   - Coleta e validação de dados em tempo real (ID, Nome, Storage, Tamanho do disco).
#   - Download e verificação da imagem Debian 11 Cloud-Init.
#   - Criação da estrutura base da VM (2 CPU, 2GB RAM).
#   - Importação e detecção dinâmica do disco no storage selecionado.
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
#   1.1
#
# Data:
#   09/04/2026
#
# Pré-requisitos:
#   - Acesso root no nó Proxmox VE (8.x.x ou 9.x.x).
#   - Conexão com a internet para baixar a imagem cloud-init do Debian.
#   - Espaço suficiente no storage de destino para o disco da VM.
#
# Como usar:
#   1. chmod +x debian_11_template.sh
#   2. ./debian_11_template.sh
#   3. Siga as instruções interativas para configurar o template.
#
# Onde Utilizar:
#   - Diretamente no nó Proxmox VE (Shell).
#
# Notas Importantes:
#   - A imagem baixada ('debian-11-generic-amd64.qcow2') será armazenada em
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

VM_ID=''
VM_CREATED=0
trap 'status=$?; printf "${RED}Erro: comando falhou na linha %s (código %s): %s${NC}\n" "$LINENO" "$status" "$BASH_COMMAND" >&2; if [[ "$VM_CREATED" -eq 1 ]]; then printf "${RED}A VM %s pode ter sido criada parcialmente; verifique-a no Proxmox antes de executar novamente.${NC}\n" "$VM_ID" >&2; fi; exit "$status"' ERR

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}Erro: execute este script como root no nó Proxmox VE.${NC}" >&2
    exit 1
fi

for command_name in qm pvesm pvesh wget awk grep perl sed; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo -e "${RED}Erro: comando obrigatório não encontrado: $command_name${NC}" >&2
        exit 1
    fi
done

echo -e "${GREEN}=== Proxmox Cloud-Init Template Creator (Debian 11) ===${NC}"

# 1. Pergunta o ID da VM
while true; do
    read -r -p "Digite o ID para a nova VM Template (ex: 9003): " VM_ID
    if [[ ! "$VM_ID" =~ ^[0-9]{1,9}$ ]]; then
        echo -e "${RED}Erro: informe um ID numérico entre 100 e 999999999.${NC}"
        continue
    fi

    VM_ID=$((10#$VM_ID))
    if (( VM_ID < 100 || VM_ID > 999999999 )); then
        echo -e "${RED}Erro: informe um ID numérico entre 100 e 999999999.${NC}"
        continue
    fi

    CLUSTER_RESOURCES=$(pvesh get /cluster/resources --type vm --output-format json)
    if grep -Eq "\"vmid\"[[:space:]]*:[[:space:]]*${VM_ID}([,}])" <<< "$CLUSTER_RESOURCES"; then
        echo -e "${RED}Erro: O ID $VM_ID já está em uso no cluster! Por favor, escolha outro ID.${NC}"
        continue
    fi
    break
done

# 2. Pergunta o Nome da VM
while true; do
    read -r -p "Digite o Nome para o Template (Tecle 'Enter' para \"debian-11-template\"): " VM_NAME
    VM_NAME="${VM_NAME:-debian-11-template}"
    if [[ ! "$VM_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]]; then
        echo -e "${RED}Erro: informe um nome de 1 a 63 caracteres, começando por letra ou número e usando apenas letras, números, ponto, hífen ou sublinhado.${NC}"
        continue
    fi
    break
done

# 3. Lista Storages disponíveis e pergunta onde alocar
echo -e "\nStorages disponíveis:"
STORAGE_STATUS=$(pvesm status)
awk 'NR>1 {printf "- %s (%s)\n", $1, $3}' <<< "$STORAGE_STATUS"
while true; do
    read -r -p "Em qual storage o disco será alocado? (ex: local-lvm): " STORAGE
    if ! awk -v storage="$STORAGE" 'NR>1 && $1 == storage && $3 == "active" {found=1} END {exit !found}' <<< "$STORAGE_STATUS"; then
        echo -e "${RED}Erro: storage '$STORAGE' inexistente ou inativo. Escolha um storage ativo da lista.${NC}"
        continue
    fi

    STORAGE_CONFIG=$(pvesh get "/storage/$STORAGE" --output-format json)
    STORAGE_CONTENT=$(perl -MJSON::PP -e 'local $/; $config = decode_json(<>); print $config->{content} // "";' <<< "$STORAGE_CONFIG")
    if [[ ! ",$STORAGE_CONTENT," =~ ,images, ]]; then
        echo -e "${RED}Erro: o storage '$STORAGE' não está configurado para armazenar discos de VM (conteúdo images). Escolha outro storage.${NC}"
        continue
    fi
    break
done

# 4. Pergunta o tamanho do disco
while true; do
    read -r -p "Qual o tamanho final do disco em GB? (ex: 20): " DISK_SIZE
    if [[ ! "$DISK_SIZE" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${RED}Erro: informe um tamanho inteiro maior que zero, em GB.${NC}"
        continue
    fi
    break
done

# --- Início do Processo ---

IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE_NAME="debian-11-generic-amd64.qcow2"

# URL da imagem Cloud-Init do Debian 11 (Bullseye).
IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"

echo -e "\n${GREEN}[1/6] Baixando/Verificando imagem Debian 11...${NC}"
mkdir -p "$IMAGE_DIR"
if [ ! -f "$IMAGE_DIR/$IMAGE_NAME" ]; then
    wget -O "$IMAGE_DIR/$IMAGE_NAME" "$IMAGE_URL" || { echo -e "${RED}Erro ao baixar imagem!${NC}"; exit 1; }
else
    echo "Imagem já existe no diretório."
fi

echo -e "${GREEN}[2/6] Criando a estrutura da VM (2 CPU, 2GB RAM)...${NC}"
qm create "$VM_ID" --name "$VM_NAME" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --ostype l26 --agent 1
VM_CREATED=1

echo -e "${GREEN}[3/6] Importando disco (isso pode demorar um pouco)...${NC}"
# Captura a saída para extrair o nome do arquivo criado se necessário
IMPORT_LOG=$(qm importdisk "$VM_ID" "$IMAGE_DIR/$IMAGE_NAME" "$STORAGE")
echo "$IMPORT_LOG"

# Identifica o caminho exato do volume importado (unused) diretamente da VM (compatível com Directory, LVM, ZFS, Ceph, etc.)
DISK_PATH=$(qm config "$VM_ID" | sed -nE 's/^unused[0-9]+:[[:space:]]*([^,[:space:]]+).*/\1/p' | head -n 1)

# Fallback 1: se não encontrar no qm config, extrai da mensagem do qm importdisk
if [[ -z "$DISK_PATH" ]]; then
    DISK_PATH=$(echo "$IMPORT_LOG" | sed -nE "s/.*'([^']+)'.*/\1/p" | sed -E 's/^unused[0-9]+://' | head -n 1)
fi

# Fallback 2: detecção baseada no tipo de storage
if [[ -z "$DISK_PATH" ]]; then
    STORAGE_TYPE=$(perl -MJSON::PP -e 'local $/; $config = decode_json(<>); print $config->{type} // "";' <<< "$STORAGE_CONFIG" 2>/dev/null || true)
    case "$STORAGE_TYPE" in
        dir|nfs|cifs|glusterfs|btrfs)
            DISK_PATH="$STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw"
            ;;
        *)
            DISK_PATH="$STORAGE:vm-$VM_ID-disk-0"
            ;;
    esac
fi

if [[ -z "$DISK_PATH" ]]; then
    echo -e "${RED}Erro: não foi possível identificar o disco importado para a VM $VM_ID.${NC}" >&2
    exit 1
fi

echo -e "${GREEN}[4/6] Configurando Hardware e Cloud-Init...${NC}"
qm set "$VM_ID" --virtio0 "$DISK_PATH" >/dev/null
qm set "$VM_ID" --ide2 "$STORAGE:cloudinit" >/dev/null
qm set "$VM_ID" --boot order=virtio0 >/dev/null
qm set "$VM_ID" --serial0 socket --vga serial0 >/dev/null

echo -e "${GREEN}[5/6] Redimensionando para ${DISK_SIZE}G...${NC}"
qm resize "$VM_ID" virtio0 "${DISK_SIZE}G" >/dev/null

echo -e "\n${GREEN}=== Revisão das Configurações ===${NC}"
qm config "$VM_ID"
echo -e "------------------------------------------------"

# 5. Confirmação Final
while true; do
    read -r -p "Deseja converter a VM em Template agora? (s/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sSnN]$ ]]; then
        break
    fi
    echo -e "${RED}Erro: responda somente s ou n.${NC}"
done

if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
    echo -e "${GREEN}[6/6] Convertendo para Template...${NC}"
    qm template "$VM_ID"
    echo -e "${GREEN}Sucesso! Template $VM_ID criado.${NC}"
else
    echo -e "\n${GREEN}A VM $VM_ID foi criada com sucesso, mas NÃO foi convertida em template.${NC}"
    echo -e "Para finalizar a configuração antes de converter, acesse a interface (GUI) do Proxmox:"
    echo -e "--------------------------------------------------------------------------------------"
    echo -e "1. Selecione a VM criada (${GREEN}$VM_ID${NC}) e vá até a aba ${GREEN}Cloud-Init${NC}."
    echo -e "2. Preencha os campos conforme necessário:"
    echo -e "   - ${GREEN}User${NC}: debian (O usuário padrão do Debian Cloud Image)"
    echo -e "   - ${GREEN}Password${NC}: sua_senha (Senha do Servidor)"
    echo -e "   - ${GREEN}SSH Public Key${NC}: Cole sua chave id_rsa.pub (Se for mais de uma, cole uma abaixo da outra)"
    echo -e "   - ${GREEN}IP Config${NC}: Geralmente deixamos em DHCP para o template"
    echo -e "3. ${GREEN}**ATENÇÃO**${NC} - Clique em ${GREEN}Regenerate Image${NC} para salvar as configurações do Cloud-Init."
    echo -e "4. Ligue a VM e acesse o console para rodar os comandos:"
    echo -e "   ${GREEN}$ sudo timedatectl set-timezone America/Sao_Paulo${NC}"
    echo -e "   ${GREEN}$ sudo apt update && sudo apt install qemu-guest-agent -y${NC}"
    echo -e "5. Limpe os logs e o histórico antes de desligar a VM:"
    echo -e "   ${GREEN}$ sudo truncate -s 0 /var/log/*log${NC}"
    echo -e "   ${GREEN}$ history -c && history -w${NC}"
    echo -e "6. Desligue a VM (poweroff)."
    echo -e "7. Clique com o botão direito na VM e selecione ${GREEN}Convert to Template${NC}."
    echo -e "--------------------------------------------------------------------------------------"
fi
