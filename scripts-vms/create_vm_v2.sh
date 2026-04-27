#!/bin/bash

#==============================================================================
# Script: create_vm_v2.sh
# Descrição: Criação interativa de VMs no Proxmox VE com validações avançadas
#            e suporte a ISO opcional. Versão aprimorada com melhor tratamento
#            de storages e listagem de ISOs disponíveis.
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 2.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Verificação de privilégios e dependências (jq opcional)
# 2. Coleta interativa de configurações da VM (ID, nome, RAM, CPU, disco)
# 3. Seleção de storage para disco (listagem automática de storages com 'images')
# 4. Seleção do tipo de OS (Linux, Windows, Outro)
# 5. Anexo opcional de ISO (listagem automática de ISOs disponíveis)
# 6. Resumo e confirmação final das configurações
# 7. Criação da VM via comando 'qm create'

# MELHORIAS DA V2:
# - Listagem inteligente de storages por tipo de conteúdo
# - Listagem automática de ISOs disponíveis em cada storage
# - Melhor tratamento de erros e validações
# - Interface mais amigável com confirmações em cada etapa
# - Suporte a diferentes tipos de OS com nomes amigáveis
# - Validação de formato de tamanho de disco (G/M)

# Uso:
#   chmod +x create_vm_v2.sh
#   sudo ./create_vm_v2.sh

# Pré-requisitos:
# - Proxmox VE com ferramentas CLI: pvesh, pvesm, qm
# - Execução como root ou com sudo
# - jq (opcional, mas recomendado para melhor performance)
# - Storages configurados no Proxmox para 'images' e 'iso'

#==============================================================================
# FUNÇÕES AUXILIARES
#==============================================================================

# Função para exibir uma mensagem de erro e sair
error_exit() {
    echo "Erro: $1" >&2
    exit 1
}

#==============================================================================
# ETAPA 1: VERIFICAÇÃO DE PRIVILÉGIOS E DEPENDÊNCIAS
#==============================================================================

# Verifica se o script está sendo executado como root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "Este script precisa ser executado como root (ou com sudo)."
fi

echo "--- Criador de Máquina Virtual Proxmox VE v2.0 ---"

# Verificação e instalação opcional do 'jq'
# O 'jq' é útil para processamento JSON, mas o script funciona sem ele
if ! command -v jq &> /dev/null; then
    echo ""
    echo "O pacote 'jq' não foi encontrado no seu sistema."
    echo "Ele é recomendado para processar informações JSON, mas o script tentará funcionar sem ele para listagem de storages."
    read -p "Deseja instalar 'jq' agora? (s/N): " INSTALL_JQ
    if [[ "$INSTALL_JQ" =~ ^[Ss]$ ]]; then
        echo "Atualizando listas de pacotes e instalando 'jq'..."
        apt update && apt install jq -y || error_exit "Falha ao instalar 'jq'. Por favor, instale-o manualmente e tente novamente."
        echo "'jq' instalado com sucesso!"
    else
        echo "Continuando sem 'jq'. Algumas funcionalidades podem ser limitadas ou menos eficientes."
    fi
fi

# --- Funções Auxiliares ---

#==============================================================================
# ETAPA 2: FUNÇÕES PARA LISTAGEM DE RECURSOS DO PROXMOX
#==============================================================================

# Função para obter o próximo ID de VM disponível
get_next_vmid() {
    pvesh get /cluster/nextid
}

# Função para listar storages que suportam um tipo de conteúdo específico
# Parâmetro: $1 = tipo de conteúdo (ex: "images", "iso")
list_storages_by_content() {
    local content_type="$1"
    local storages=()
    # pvesm status | awk 'NR > 1 {print $1, $NF}' -> Pega o nome do storage e a última coluna (Content)
    # grep -q "$content_type" -> Verifica se o tipo de conteúdo está na string da coluna Content
    while IFS= read -r line; do
        local storage_name=$(echo "$line" | awk '{print $1}')
        local content_column=$(echo "$line" | awk '{print $NF}') # A última coluna é o 'Content'
        if echo "$content_column" | grep -q "\<$content_type\>"; then # Usa \< \> para match de palavra inteira
            storages+=("$storage_name")
        fi
    done < <(pvesm status | awk 'NR > 1 {print $1, $NF}') # Processa a saída de pvesm status, ignorando o cabeçalho
    echo "${storages[@]}"
}

# Função para listar ISOs em um determinado storage
list_isos_on_storage() {
    local storage_name="$1"
    local isos=()
    # Obtém o Volid da saída de 'pvesm list', ignorando o cabeçalho, e extrai o nome do arquivo
    # A saída de 'pvesm list <storage> --content iso' tem o formato 'storage:content/filename'
    for volid_line in $(pvesm list "$storage_name" --content iso | awk 'NR > 1 {print $1}'); do
        # Extrai a parte após 'iso/'
        local iso_filename=$(echo "$volid_line" | sed 's/^.*iso\///')
        isos+=("$iso_filename")
    done
    echo "${isos[@]}"
}

# --- Variáveis de Configuração da VM ---

#==============================================================================
# ETAPA 3: INICIALIZAÇÃO DE VARIÁVEIS DE CONFIGURAÇÃO
#==============================================================================
VMID=""
VM_NAME=""
RAM_MB=""
CPU_CORES=""
DISK_SIZE=""
STORAGE_POOL=""
OS_TYPE="l26" # Padrão para Linux 2.6/3.x/4.x/5.x/6.x
NETWORK_BRIDGE="vmbr0" # Bridge de rede padrão
ISO_PATH=""
ISO_STORAGE=""
DISPLAY_OS_TYPE="" # Para exibir o nome amigável do OS

# --- 1. Obter e confirmar o ID da VM ---

#==============================================================================
# ETAPA 4: COLETA INTERATIVA DE CONFIGURAÇÕES DA VM
#==============================================================================

# Subetapa 4.1: Configuração do ID da VM
while true; do
    NEXT_ID=$(get_next_vmid)
    read -p "Digite o ID da VM (sugestão: $NEXT_ID): " VMID_INPUT
    VMID=${VMID_INPUT:-$NEXT_ID} # Usa o sugerido se a entrada estiver vazia

    if ! [[ "$VMID" =~ ^[0-9]+$ ]] || [ "$VMID" -lt 100 ] || [ "$VMID" -gt 999999999 ]; then
        echo "Erro: O ID da VM deve ser um número inteiro entre 100 e 999999999. Por favor, tente novamente."
        continue
    fi

    # Verifica se o VMID já existe
    if qm status "$VMID" &>/dev/null; then
        echo "Erro: Já existe uma VM com o ID '$VMID'. Por favor, escolha outro ID."
        continue
    fi

    echo "Você informou o ID da VM: '$VMID'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_VMID
    if [[ "$CONFIRM_VMID" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, insira o ID da VM novamente."
    fi
done

# --- 2. Obter e confirmar o Nome da VM ---
# Subetapa 4.2: Configuração do nome da VM
while true; do
    read -p "Digite o nome da VM: " VM_NAME_INPUT
    VM_NAME=${VM_NAME_INPUT}

    if [ -z "$VM_NAME" ]; then
        echo "Erro: O nome da VM não pode ser vazio. Por favor, tente novamente."
        continue
    fi

    echo "Você informou o nome da VM: '$VM_NAME'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_VM_NAME
    if [[ "$CONFIRM_VM_NAME" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, insira o nome da VM novamente."
    fi
done

# --- 3. Obter e confirmar a quantidade de RAM ---
# Subetapa 4.3: Configuração da memória RAM
while true; do
    read -p "Digite a quantidade de RAM em MB (Ex: 2048 para 2GB): " RAM_INPUT
    RAM_MB=${RAM_INPUT}

    if ! [[ "$RAM_MB" =~ ^[0-9]+$ ]] || [ "$RAM_MB" -lt 128 ]; then
        echo "Erro: A RAM deve ser um número inteiro maior ou igual a 128 MB. Por favor, tente novamente."
        continue
    fi

    echo "Você informou a RAM: '$RAM_MB MB'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_RAM
    if [[ "$CONFIRM_RAM" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, insira a RAM novamente."
    fi
done

# --- 4. Obter e confirmar o número de núcleos de CPU ---
# Subetapa 4.4: Configuração dos núcleos de CPU
while true; do
    read -p "Digite o número de núcleos de CPU (Ex: 2): " CPU_INPUT
    CPU_CORES=${CPU_INPUT}

    if ! [[ "$CPU_CORES" =~ ^[0-9]+$ ]] || [ "$CPU_CORES" -lt 1 ]; then
        echo "Erro: O número de núcleos de CPU deve ser um número inteiro maior ou igual a 1. Por favor, tente novamente."
        continue
    fi

    echo "Você informou os núcleos de CPU: '$CPU_CORES'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_CPU
    if [[ "$CONFIRM_CPU" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, insira os núcleos de CPU novamente."
    fi
done

# --- 5. Obter e confirmar o tamanho do disco ---
# Subetapa 4.5: Configuração do tamanho do disco
while true; do
    read -p "Digite o tamanho do disco (Ex: 32G para 32GB, 500M para 500MB): " DISK_SIZE_INPUT
    DISK_SIZE=${DISK_SIZE_INPUT}

    # Validação básica para o formato do tamanho do disco (ex: 32G, 500M)
    if ! echo "$DISK_SIZE" | grep -Eq "^[0-9]+[GM]$"; then
        echo "Erro: O tamanho do disco deve ser um número seguido de 'G' (Gigabytes) ou 'M' (Megabytes). Ex: 32G, 500M. Por favor, tente novamente."
        continue
    fi

    echo "Você informou o tamanho do disco: '$DISK_SIZE'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_DISK_SIZE
    if [[ "$CONFIRM_DISK_SIZE" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, insira o tamanho do disco novamente."
    fi
done

# --- 6. Obter e confirmar o Storage Pool ---
# Subetapa 4.6: Seleção do storage para o disco
while true; do
    echo ""
    echo "Storages disponíveis para imagens de disco:"
    AVAILABLE_STORAGES=($(list_storages_by_content "images"))
    
    if [ ${#AVAILABLE_STORAGES[@]} -eq 0 ]; then
        error_exit "Nenhum storage configurado para armazenar imagens de disco ('images'). Por favor, configure um no Proxmox."
    fi

    for i in "${!AVAILABLE_STORAGES[@]}"; do
        echo "$((i+1)). ${AVAILABLE_STORAGES[$i]}"
    done

    read -p "Selecione o número do storage para alocar o disco: " STORAGE_CHOICE
    
    if ! [[ "$STORAGE_CHOICE" =~ ^[0-9]+$ ]] || [ "$STORAGE_CHOICE" -lt 1 ] || [ "$STORAGE_CHOICE" -gt ${#AVAILABLE_STORAGES[@]} ]; then
        echo "Erro: Seleção inválida. Por favor, digite um número da lista."
        continue
    fi

    STORAGE_POOL=${AVAILABLE_STORAGES[$((STORAGE_CHOICE-1))]}

    echo "Você selecionou o storage: '$STORAGE_POOL'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_STORAGE
    if [[ "$CONFIRM_STORAGE" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, selecione o storage novamente."
    fi
done

# --- 7. Obter e confirmar o Tipo de OS ---
# Subetapa 4.7: Seleção do tipo de sistema operacional
while true; do
    echo ""
    echo "Tipos de OS disponíveis:"
    echo "1. Linux (l26 - padrão)"
    echo "2. Windows (win10)"
    echo "3. Outro (other)"
    read -p "Selecione o tipo de OS (1-3, padrão: 1): " OS_TYPE_CHOICE
    OS_TYPE_CHOICE=${OS_TYPE_CHOICE:-1}

    case "$OS_TYPE_CHOICE" in
        1) OS_TYPE="l26"; DISPLAY_OS_TYPE="Linux";;
        2) OS_TYPE="win10"; DISPLAY_OS_TYPE="Windows";;
        3) OS_TYPE="other"; DISPLAY_OS_TYPE="Outro";;
        *) echo "Erro: Seleção inválida. Usando padrão 'Linux'."; OS_TYPE="l26"; DISPLAY_OS_TYPE="Linux";;
    esac

    echo "Você selecionou o tipo de OS: '$DISPLAY_OS_TYPE' ($OS_TYPE)"
    read -p "Esta informação está correta? (s/N): " CONFIRM_OS_TYPE
    if [[ "$CONFIRM_OS_TYPE" =~ ^[Ss]$ ]]; then
        break
    else
        echo "Por favor, selecione o tipo de OS novamente."
    fi
done

# --- 8. Perguntar sobre Imagem ISO (Opcional) ---
# Subetapa 4.8: Anexo opcional de imagem ISO para instalação
read -p "Deseja anexar uma imagem ISO para instalação? (s/N): " ATTACH_ISO_CHOICE
if [[ "$ATTACH_ISO_CHOICE" =~ ^[Ss]$ ]]; then
    while true; do
        echo ""
        echo "Storages disponíveis para ISOs:"
        ISO_STORAGES=($(list_storages_by_content "iso"))

        if [ ${#ISO_STORAGES[@]} -eq 0 ]; then
            echo "Aviso: Nenhum storage configurado para ISOs. Não será possível anexar uma ISO."
            ISO_PATH=""
            break # Sai do loop interno, nenhuma ISO será anexada
        fi

        for i in "${!ISO_STORAGES[@]}"; do
            echo "$((i+1)). ${ISO_STORAGES[$i]}"
        done

        read -p "Selecione o número do storage onde a ISO está localizada: " ISO_STORAGE_CHOICE
        if ! [[ "$ISO_STORAGE_CHOICE" =~ ^[0-9]+$ ]] || [ "$ISO_STORAGE_CHOICE" -lt 1 ] || [ "$ISO_STORAGE_CHOICE" -gt ${#ISO_STORAGES[@]} ]; then
            echo "Erro: Seleção inválida. Por favor, digite um número da lista."
            continue
        fi
        ISO_STORAGE=${ISO_STORAGES[$((ISO_STORAGE_CHOICE-1))]}

        echo ""
        echo "ISOs disponíveis no storage '$ISO_STORAGE':"
        AVAILABLE_ISOS=($(list_isos_on_storage "$ISO_STORAGE"))

        if [ ${#AVAILABLE_ISOS[@]} -eq 0 ]; then
            echo "Aviso: Nenhuma ISO encontrada no storage '$ISO_STORAGE'. Por favor, selecione outro storage ou adicione uma ISO."
            read -p "Deseja tentar selecionar outro storage de ISO? (s/N): " RETRY_ISO_STORAGE
            if [[ ! "$RETRY_ISO_STORAGE" =~ ^[Ss]$ ]]; then
                ISO_PATH=""
                break # Sai do loop interno, nenhuma ISO será anexada
            fi
            continue # Volta para a seleção do storage de ISO
        fi

        for i in "${!AVAILABLE_ISOS[@]}"; do
            echo "$((i+1)). ${AVAILABLE_ISOS[$i]}"
        done

        read -p "Selecione o número da imagem ISO para anexar: " ISO_CHOICE
        if ! [[ "$ISO_CHOICE" =~ ^[0-9]+$ ]] || [ "$ISO_CHOICE" -lt 1 ] || [ "$ISO_CHOICE" -gt ${#AVAILABLE_ISOS[@]} ]; then
            echo "Erro: Seleção inválida. Por favor, digite um número da lista."
            continue
        fi
        ISO_PATH="${ISO_STORAGE}:iso/${AVAILABLE_ISOS[$((ISO_CHOICE-1))]}"

        echo "Você selecionou a ISO: '${AVAILABLE_ISOS[$((ISO_CHOICE-1))]}' no storage '$ISO_STORAGE'"
        read -p "Esta informação está correta? (s/N): " CONFIRM_ISO
        if [[ "$CONFIRM_ISO" =~ ^[Ss]$ ]]; then
            break # Sai do loop interno se confirmado
        else
            echo "Por favor, selecione a ISO novamente."
        fi
    done
fi

# --- 9. Exibir Resumo e Confirmação Final ---

#==============================================================================
# ETAPA 5: RESUMO E CONFIRMAÇÃO FINAL
#==============================================================================
echo ""
echo "--- Resumo da Configuração da VM ---"
echo "ID da VM: $VMID"
echo "Nome da VM: $VM_NAME"
echo "RAM: $RAM_MB MB"
echo "CPU Cores: $CPU_CORES"
echo "Tamanho do Disco: $DISK_SIZE"
echo "Storage do Disco: $STORAGE_POOL"
echo "Tipo de OS: $DISPLAY_OS_TYPE ($OS_TYPE)"
echo "Bridge de Rede: $NETWORK_BRIDGE"
if [ -n "$ISO_PATH" ]; then
    echo "Imagem ISO: $ISO_PATH"
else
    echo "Imagem ISO: Nenhuma"
fi
echo "------------------------------------"

read -p "Confirma a criação da VM com estas configurações? (s/N): " FINAL_CONFIRMATION
if [[ ! "$FINAL_CONFIRMATION" =~ ^[Ss]$ ]]; then
    error_exit "Criação da VM cancelada pelo usuário."
fi

# --- 10. Criar a VM ---

#==============================================================================
# ETAPA 6: CRIAÇÃO DA MÁQUINA VIRTUAL
#==============================================================================
echo ""
echo "Criando a VM com ID $VMID e nome '$VM_NAME'..."

# Comando base para qm create
CREATE_CMD="qm create $VMID --name \"$VM_NAME\" --memory $RAM_MB --cores $CPU_CORES --ostype $OS_TYPE --net0 virtio,bridge=$NETWORK_BRIDGE --scsihw virtio-scsi-pci --boot order=scsi0 --cpu host --scsi0 $STORAGE_POOL:$DISK_SIZE,format=qcow2"

# Adiciona ISO se selecionada
if [ -n "$ISO_PATH" ]; then
    CREATE_CMD="$CREATE_CMD --cdrom $ISO_PATH"
fi

echo "Executando: $CREATE_CMD"
eval "$CREATE_CMD" || error_exit "Falha ao criar a VM. Verifique os logs do Proxmox para mais detalhes."

echo ""
echo "VM '$VM_NAME' (ID: $VMID) criada com sucesso!"
echo "Você pode iniciar a VM com: qm start $VMID"
echo "Ou acessá-la via interface web do Proxmox."
echo ""
echo "Script concluído."
