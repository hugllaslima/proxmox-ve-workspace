#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: install_k3s_worker.sh
#
# Descrição:
#   Este script automatiza a instalação e configuração de um nó worker do K3s.
#   Ele prepara o sistema operacional, configura a resolução de nomes, ajusta
#   o firewall (UFW) e junta o nó a um cluster K3s existente.
#
# Funcionalidades:
#   - Prepara o sistema operacional (Update, Swap, Sysctl).
#   - Configura /etc/hosts e resolução de nomes.
#   - Gerencia automaticamente firewall (UFW) para permitir comunicação do cluster.
#   - Instala o K3s como um nó worker, conectando-o ao master especificado.
#
# Autor:
#   Hugllas R. S. Lima
#
# Contato:
#   - https://www.linkedin.com/in/hugllas-r-s-lima/
#   - https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-k3s-kubernetes
#
# Versão:
#   1.0
#
# Data:
#   23/11/2025
#
# Pré-requisitos:
#   - Ubuntu 22.04/24.04 LTS.
#   - Acesso root/sudo.
#   - Conectividade de rede com o nó master do K3s.
#   - IP estático para o nó worker.
#   - Token de acesso do cluster K3s (gerado no nó master).
#
# Como usar:
#   1. Copie o arquivo 'k3s_cluster_vars.sh' do master para o diretório deste script.
#   2. chmod +x install_k3s_worker.sh
#   3. sudo ./install_k3s_worker.sh
#
# Onde Utilizar:
#   - Diretamente na VM que será configurada como Worker Node.
#
# -----------------------------------------------------------------------------

# --- Constantes ---
CONFIG_FILE="k3s_cluster_vars.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE_PATH="$SCRIPT_DIR/$CONFIG_FILE"

# --- Variáveis de Configuração ---
K3S_CONTROL_PLANE_1_IP=""
K3S_TOKEN=""
NFS_SERVER_IP=""
NFS_SHARE_PATH=""
ADMIN_NETWORK_CIDRS=""

# --- Funções Auxiliares ---

function error_exit { echo -e "\n\e[31mERRO: $1\e[0m" >&2; exit 1; }
function success_message { echo -e "\e[32mSUCESSO: $1\e[0m"; }
function warning_message { echo -e "\e[33mAviso: $1\e[0m"; }
function check_command { if [ $? -ne 0 ]; then error_exit "$1"; fi; }

# Função para confirmar as informações
function confirm_info {
    echo -e "\n\e[34m--- Por favor, revise as informações fornecidas ---\e[0m"
    echo "Endpoints do Cluster (HA):"
    echo "  - CP1: $K3S_CONTROL_PLANE_1_IP"
    echo "  - CP2: ${K3S_CONTROL_PLANE_2_IP:-N/A}"
    echo "  - CP3: ${K3S_CONTROL_PLANE_3_IP:-N/A}"
    echo "Token do Cluster: $(if [ -n "$K3S_TOKEN" ]; then echo "(definido)"; else echo "(não definido)"; fi)"
    echo "IP do Servidor NFS: $NFS_SERVER_IP"
    echo "Caminho do Compartilhamento NFS: $NFS_SHARE_PATH"
    echo "IP deste Nó Worker: $CURRENT_NODE_IP"
    echo -e "\e[34m---------------------------------------------------\e[0m"

    while true; do
        read -p "As informações acima estão corretas e deseja prosseguir com a instalação? (s/n): " confirm
        case $confirm in
            [Ss]* ) break;;
            [Nn]* ) error_exit "Instalação cancelada. Por favor, ajuste as configurações e tente novamente.";;
            * ) echo "Por favor, responda 's' ou 'n'.";;
        esac
    done
}

# --- Início do Script ---

echo "--- Instalação do K3s Worker Node ---"
echo "Este script irá configurar um nó K3s Worker."

# Tenta carregar o arquivo de configuração
if [ -f "$CONFIG_FILE_PATH" ]; then
    echo -e "\e[32mArquivo de configuração encontrado: $CONFIG_FILE\e[0m"
    echo "Carregando variáveis..."
    source "$CONFIG_FILE_PATH"
    
    # Validação básica
    if [ -z "$K3S_CONTROL_PLANE_1_IP" ] || [ -z "$K3S_TOKEN" ]; then
        error_exit "Variáveis essenciais (K3S_CONTROL_PLANE_1_IP ou K3S_TOKEN) estão vazias no arquivo de configuração."
    fi
    success_message "Variáveis de ambiente carregadas."
else
    error_exit "Arquivo de configuração '$CONFIG_FILE' não encontrado. Por favor, copie este arquivo do k3s-control-plane-1 para este diretório antes de executar o script."
fi

# Detectar IP atual
CURRENT_NODE_IP=$(hostname -I | awk '{print $1}')

# Confirmação
confirm_info

# Verificação de root
if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, execute este script como root (sudo)."
fi

# 1. Preparação do Sistema
echo -e "\e[34m--- 1. Preparando o Sistema ---\e[0m"
apt update && apt upgrade -y
check_command "Falha ao atualizar o sistema."

# Instalar dependências comuns e NFS Client
apt install -y curl ufw nfs-common
check_command "Falha ao instalar dependências."

# Configurar /etc/hosts
echo "Configurando /etc/hosts..."
sed -i '/k3s-control-plane/d' /etc/hosts
sed -i '/k3s-worker/d' /etc/hosts
sed -i '/k3s-storage-nfs/d' /etc/hosts

cat >> /etc/hosts <<EOF
$K3S_CONTROL_PLANE_1_IP k3s-control-plane-1
$K3S_CONTROL_PLANE_2_IP k3s-control-plane-2
$K3S_CONTROL_PLANE_3_IP k3s-control-plane-3
$K3S_WORKER_1_IP k3s-worker-1
$K3S_WORKER_2_IP k3s-worker-2
$NFS_SERVER_IP k3s-storage-nfs
EOF
success_message "/etc/hosts atualizado."

# Desabilitar Swap
echo "Desabilitando Swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
success_message "Swap desabilitado."

# Configurar Sysctl
echo "Aplicando configurações de Kernel (sysctl)..."
cat >> /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
success_message "Configurações de Kernel aplicadas."

# 2. Configuração de Firewall (UFW)
echo -e "\e[34m--- 2. Configurando Firewall (UFW) ---\e[0m"
ufw default deny incoming
ufw default allow outgoing

# Permitir SSH das redes administrativas
if [ -n "$ADMIN_NETWORK_CIDRS" ]; then
    for cidr in $ADMIN_NETWORK_CIDRS; do
        ufw allow from "$cidr" to any port 22 proto tcp comment 'SSH Admin Access'
    done
else
    # Fallback se a variável não estiver definida: permite de qualquer lugar (menos seguro, mas funcional)
    ufw allow ssh comment 'SSH Access'
fi

# Kubelet (10250)
ufw allow from "$K3S_LAN_CIDR" to any port 10250 proto tcp comment 'Kubelet Metrics'

# Flannel/VXLAN (8472 UDP)
ufw allow from "$K3S_LAN_CIDR" to any port 8472 proto udp comment 'K3s Flannel VXLAN'

# NodePort Services (opcional, se você for expor serviços diretamente via NodePort)
# ufw allow 30000:32767/tcp

echo "Habilitando UFW..."
echo "y" | ufw enable
success_message "Firewall configurado."

# 3. Instalação do K3s Agent
echo -e "\e[34m--- 3. Instalando K3s Agent (Worker) ---\e[0m"

echo "Ingressando no cluster..."
curl -sfL https://get.k3s.io | K3S_URL="https://$K3S_CONTROL_PLANE_1_IP:6443" K3S_TOKEN="$K3S_TOKEN" sh -
check_command "Falha ao instalar o K3s Agent."

# 4. Verificação Final
echo -e "\n\e[32mInstalação concluída neste nó Worker.\e[0m"
echo "Aguarde alguns instantes e verifique no nó Master se este worker aparece como 'Ready' executando 'kubectl get nodes'."
