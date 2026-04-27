#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: install_k3s_control_plane.sh
#
# Descrição:
#   Este script automatiza a instalação e configuração de um nó Control Plane (Master)
#   do K3s com Datastore embutido (Etcd) para Alta Disponibilidade (HA).
#   Suporta 3 nós de controle:
#    - O primeiro nó inicializa o cluster (--cluster-init).
#    - Os nós subsequentes (2 e 3) ingressam no cluster existente.
#
# Funcionalidades:
#   - Prepara o sistema operacional (Update, Swap, Sysctl).
#   - Configura /etc/hosts e resolução de nomes.
#   - Instala o K3s server com Etcd embarcado.
#   - Gerencia automaticamente firewall (UFW) para API e Etcd.
#   - Configura o arquivo de configuração do cluster.
#   - Adiciona o token do K3s ao arquivo de configuração.
#   - Adiciona o token do K3s ao arquivo de configuração.
#   - Mantém o Traefik habilitado (nativo) para uso com Gateway API.
#
# Autor:
#   Hugllas R. S. Lima
#
# Contato:
#   - https://www.linkedin.com/in/hugllas-r-s-lima/
#   - https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-k3s-kubernetes-v2
#
# Versão:
#   2.0
#
# Data:
#   23/11/2025
#
# Pré-requisitos:
#   - Ubuntu 22.04/24.04 LTS.
#   - Acesso root/sudo.
#   - IPs estáticos definidos para todos os nós.
#
# Como usar:
#   1. chmod +x install_k3s_control_plane.sh
#   2. sudo ./install_k3s_control_plane.sh
#   3. Siga as instruções interativas.
#
# Onde Utilizar:
#   - Diretamente na VM que será configurada como Control Plane.
#
# -----------------------------------------------------------------------------

# --- Constantes ---
CONFIG_FILE="k3s_cluster_vars.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE_PATH="$SCRIPT_DIR/$CONFIG_FILE"

# --- Funções Auxiliares ---
function error_exit { echo -e "\n\e[31mERRO: $1\e[0m" >&2; exit 1; }
function success_message { echo -e "\e[32mSUCESSO: $1\e[0m"; }
function warning_message { echo -e "\e[33mAviso: $1\e[0m"; }
function check_command { if [ $? -ne 0 ]; then error_exit "$1"; fi; }

# --- Lógica de Configuração ---

# Função para gerar o arquivo de configuração
function generate_config_file() {
    echo "Gerando arquivo de configuração: $CONFIG_FILE..."
    cat > "$CONFIG_FILE_PATH" <<EOF
# Arquivo de configuração gerado pela instalação do K3s
# NÃO adicione este arquivo ao Git.

# --- IPs da Infraestrutura ---
export K3S_CONTROL_PLANE_1_IP="$K3S_CONTROL_PLANE_1_IP"
export K3S_CONTROL_PLANE_2_IP="$K3S_CONTROL_PLANE_2_IP"
export K3S_CONTROL_PLANE_3_IP="$K3S_CONTROL_PLANE_3_IP"
export K3S_WORKER_1_IP="$K3S_WORKER_1_IP"
export K3S_WORKER_2_IP="$K3S_WORKER_2_IP"
export NFS_SERVER_IP="$NFS_SERVER_IP"

# --- Configurações do Cluster ---
export K3S_POD_CIDR="$K3S_POD_CIDR"
export K3S_LAN_CIDR="$K3S_LAN_CIDR"
export NFS_SHARE_PATH="$NFS_SHARE_PATH"

# --- Segredos (NÃO FAÇA COMMIT DESTE ARQUIVO) ---
export K3S_TOKEN="" # Será preenchido após a instalação do primeiro control-plane

# --- Redes de Acesso Permitidas ---
export ADMIN_NETWORK_CIDRS="$ADMIN_NETWORK_CIDRS"
EOF
    chmod 600 "$CONFIG_FILE_PATH"
    success_message "Arquivo de configuração '$CONFIG_FILE' gerado com sucesso."
}

# Função para adicionar o token ao arquivo de configuração
function add_token_to_config() {
    local token="$1"
    # Usa sed com um delimitador diferente para evitar problemas com caracteres especiais no token
    sed -i "s|export K3S_TOKEN=.*|export K3S_TOKEN=\"$token\"|" "$CONFIG_FILE_PATH"
    check_command "Falha ao adicionar o token ao arquivo de configuração."
    success_message "Token do K3s salvo no arquivo de configuração."
}

# Função para coletar informações do usuário (usada apenas na primeira execução)
function gather_initial_info() {
    echo -e "\n\e[33m--- INFORMAÇÕES NECESSÁRIAS PARA A PRIMEIRA INSTALAÇÃO (ETCD HA) ---\e[0m"
    get_user_input "Digite o IP do k3s-control-plane-1" "192.168.10.20" "K3S_CONTROL_PLANE_1_IP"
    get_user_input "Digite o IP do k3s-control-plane-2" "192.168.10.21" "K3S_CONTROL_PLANE_2_IP"
    get_user_input "Digite o IP do k3s-control-plane-3" "192.168.10.22" "K3S_CONTROL_PLANE_3_IP"
    
    get_user_input "Digite o IP do k3s-worker-1" "192.168.10.23" "K3S_WORKER_1_IP"
    get_user_input "Digite o IP do k3s-worker-2" "192.168.10.24" "K3S_WORKER_2_IP"
    
    get_user_input "Digite o IP do servidor NFS" "192.168.10.25" "NFS_SERVER_IP"
    get_user_input "Digite o caminho do compartilhamento NFS" "/mnt/k3s-share-nfs/" "NFS_SHARE_PATH"
    
    get_user_input "Digite o CIDR dos PODs do K3s" "10.42.0.0/16" "K3S_POD_CIDR"
    get_user_input "Digite o CIDR da sua rede LAN (para liberar firewall)" "192.168.10.0/24" "K3S_LAN_CIDR"
    
    echo -e "\n\e[33m--- Segurança (Acesso SSH/API) ---\e[0m"
    ADMIN_NETWORK_CIDRS="$K3S_LAN_CIDR"
    echo "A rede local ($K3S_LAN_CIDR) já será incluída nas permissões de acesso SSH/API."
    
    read -p "Deseja adicionar outras redes (VPN, Jump Server) para acesso administrativo? [s/N]: " add_extra_nets
    if [[ "$add_extra_nets" =~ ^[Ss]$ ]]; then
        echo "Exemplo: 10.8.0.0/24 (VPN Wireguard) ou 203.0.113.10/32 (IP Público)."
        get_user_input "Digite os CIDRs ADICIONAIS (separados por espaço)" "" "EXTRA_CIDRS"
        if [ -n "$EXTRA_CIDRS" ]; then
            ADMIN_NETWORK_CIDRS="$ADMIN_NETWORK_CIDRS $EXTRA_CIDRS"
        fi
    fi
}

# Função para exibir resumo e solicitar confirmação
function confirm_info() {
    echo -e "\n\e[34m--- Resumo da Configuração ---\e[0m"
    echo "Control Plane 1 : $K3S_CONTROL_PLANE_1_IP"
    echo "Control Plane 2 : $K3S_CONTROL_PLANE_2_IP"
    echo "Control Plane 3 : $K3S_CONTROL_PLANE_3_IP"
    echo "Worker 1        : $K3S_WORKER_1_IP"
    echo "Worker 2        : $K3S_WORKER_2_IP"
    echo "NFS Server      : $NFS_SERVER_IP"
    echo "NFS Share Path  : $NFS_SHARE_PATH"
    echo "Pod CIDR        : $K3S_POD_CIDR"
    echo "LAN CIDR        : $K3S_LAN_CIDR"
    echo "Admin CIDRs     : $ADMIN_NETWORK_CIDRS"
    echo "--------------------------------------------------"
    
    read -p "As informações estão corretas? [S/n]: " confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return 1 || return 0
}

# Função para coletar entrada do usuário
function get_user_input {
    local prompt_message="$1"
    local default_value="$2"
    local var_name="$3"
    
    if [ -n "$default_value" ]; then
        prompt_message="$prompt_message (Padrão: $default_value)"
    fi
    
    read -p "$prompt_message: " input_value
    if [ -z "$input_value" ] && [ -n "$default_value" ]; then
        eval "$var_name=\"$default_value\""
    elif [ -n "$input_value" ]; then
        eval "$var_name=\"$input_value\""
    else
        error_exit "Valor inválido."
    fi
}

# --- Início do Script ---

# Verificação de root
if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, execute este script como root (sudo)."
fi

echo " "
echo -e "\e[34m--- Instalação do K3s Control Plane (HA) ---\e[0m"

# Verifica se o arquivo de configuração existe
if [ -f "$CONFIG_FILE_PATH" ]; then
    echo -e "\e[32mArquivo de configuração encontrado: $CONFIG_FILE\e[0m"
    source "$CONFIG_FILE_PATH"
    
    echo -e "\e[34mConfigurações carregadas do arquivo:\e[0m"
    if ! confirm_info; then
        echo "Instalação cancelada pelo usuário."
        exit 0
    fi
else
    echo -e "\e[33mArquivo de configuração não encontrado.\e[0m"
    echo "Iniciando assistente de configuração..."
    while true; do
        gather_initial_info
        if confirm_info; then
            break
        else
            echo -e "\n\e[33mReiniciando assistente...\e[0m\n"
        fi
    done
    generate_config_file
fi

# Identifica qual nó está sendo configurado
CURRENT_IP=$(hostname -I | awk '{print $1}') # Pega o primeiro IP
echo "IP detectado neste servidor: $CURRENT_IP"

NODE_TYPE=""
if [ "$CURRENT_IP" == "$K3S_CONTROL_PLANE_1_IP" ]; then
    NODE_TYPE="INIT"
    echo -e "\e[34mConfigurando: Control Plane 1 (Inicializador do Cluster)\e[0m"
elif [ "$CURRENT_IP" == "$K3S_CONTROL_PLANE_2_IP" ] || [ "$CURRENT_IP" == "$K3S_CONTROL_PLANE_3_IP" ]; then
    NODE_TYPE="JOIN"
    echo -e "\e[34mConfigurando: Control Plane Secundário (Join Cluster)\e[0m"
else
    error_exit "O IP deste servidor ($CURRENT_IP) não corresponde a nenhum dos IPs de Control Plane definidos ($K3S_CONTROL_PLANE_1_IP, $K3S_CONTROL_PLANE_2_IP, $K3S_CONTROL_PLANE_3_IP). Verifique suas configurações de rede ou o arquivo $CONFIG_FILE."
fi

# 1. Preparação do Sistema (Comum a todos)
echo " " 
echo -e "\e[34m--- 1. Preparando o Sistema ---\e[0m"
apt update && apt upgrade -y
check_command "Falha ao atualizar o sistema."

# Instalar dependências comuns e NFS Client
apt install -y curl ufw nfs-common
check_command "Falha ao instalar dependências."

# Configurar Hostname (Opcional, mas recomendado garantir consistência)
# Vamos assumir que o usuário já definiu o hostname corretamente no OS, mas adicionamos no hosts

# Configurar /etc/hosts
echo "Configurando /etc/hosts..."
# Remove entradas antigas para evitar duplicidade
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

# Desabilitar Swap (Recomendado para K8s, embora K3s tolere, melhor desativar)
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
echo " "
echo -e "\e[34m--- 2. Configurando Firewall (UFW) ---\e[0m"
ufw default deny incoming
ufw default allow outgoing

# Permitir SSH apenas das redes administrativas
for cidr in $ADMIN_NETWORK_CIDRS; do
    ufw allow from "$cidr" to any port 22 proto tcp comment 'SSH Admin Access'
done

# Regras do Kubernetes (Control Plane)
# API Server
for cidr in $ADMIN_NETWORK_CIDRS; do
    ufw allow from "$cidr" to any port 6443 proto tcp comment 'K3s API Access'
done
# Permitir comunicação entre nós do cluster (API Server interno)
ufw allow from "$K3S_LAN_CIDR" to any port 6443 proto tcp comment 'K3s Node API Traffic'

# Etcd (2379-2380) - Apenas entre Control Planes
ufw allow from "$K3S_LAN_CIDR" to any port 2379:2380 proto tcp comment 'K3s Etcd Traffic'

# Kubelet (10250)
ufw allow from "$K3S_LAN_CIDR" to any port 10250 proto tcp comment 'Kubelet Metrics'

# Flannel/VXLAN (8472 UDP)
ufw allow from "$K3S_LAN_CIDR" to any port 8472 proto udp comment 'K3s Flannel VXLAN'

# Metrics Server (opcional, mas comum)
ufw allow from "$K3S_LAN_CIDR" to any port 10251 proto tcp comment 'Kube-scheduler'
ufw allow from "$K3S_LAN_CIDR" to any port 10252 proto tcp comment 'Kube-controller-manager'

echo "Habilitando UFW..."
echo "y" | ufw enable
success_message "Firewall configurado."


# 3. Instalação do K3s
echo " "
echo -e "\e[34m--- 3. Instalando K3s ---\e[0m"

if [ "$NODE_TYPE" == "INIT" ]; then
    # Instalação do Primeiro Nó (Cluster Init)
    echo "Inicializando o Cluster no Control Plane 1..."
    
    # Adicionadas flags --disable traefik e --disable servicelb para evitar conflitos com MetalLB/Nginx
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --tls-san $K3S_CONTROL_PLANE_1_IP --node-ip $K3S_CONTROL_PLANE_1_IP --disable servicelb" sh -
    check_command "Falha na instalação do K3s (Init)."
    
    # Aguardar o token ser gerado
    echo "Aguardando token do K3s..."
    sleep 10
    K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
    
    # Salvar token no arquivo de configuração
    add_token_to_config "$K3S_TOKEN"
    
    echo -e "\e[32mCLUSTER INICIALIZADO COM SUCESSO!\e[0m"
    echo "Copie o arquivo '$CONFIG_FILE' para os outros nós (Control Planes e Workers) para continuar a instalação."

elif [ "$NODE_TYPE" == "JOIN" ]; then
    # Instalação dos Nós Secundários (Join)
    
    # Verifica se o token está disponível
    if [ -z "$K3S_TOKEN" ]; then
        error_exit "Token do K3s não encontrado no arquivo de configuração. Certifique-se de ter copiado o '$CONFIG_FILE' atualizado do Control Plane 1."
    fi
    
    echo "Ingressando no Cluster existente..."
    
    # Adicionadas flags --disable traefik e --disable servicelb para consistência
    curl -sfL https://get.k3s.io | K3S_TOKEN="$K3S_TOKEN" INSTALL_K3S_EXEC="server --server https://$K3S_CONTROL_PLANE_1_IP:6443 --tls-san $CURRENT_IP --node-ip $CURRENT_IP --disable servicelb" sh -
    check_command "Falha ao ingressar no cluster."
    
    echo -e "\e[32mNÓ ADICIONADO AO CLUSTER COM SUCESSO!\e[0m"
fi

# 4. Verificação Final
echo " "
echo -e "\e[34m--- 4. Verificação de Status ---\e[0m"
sleep 5
/usr/local/bin/kubectl get nodes
echo -e "\n\e[32mInstalação concluída neste nó.\e[0m"