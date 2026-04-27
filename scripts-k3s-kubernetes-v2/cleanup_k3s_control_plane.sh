#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: cleanup_k3s_control_plane.sh
#
# Descrição:
#   Este script realiza a limpeza completa de um nó que foi configurado como
#   control plane do K3s. Ele desinstala o K3s e reverte as configurações 
#   para um estado limpo.
#
# Funcionalidades:
#   - Executa o script oficial de desinstalação (k3s-uninstall.sh).
#   - Limpa diretórios residuais (/var/lib/rancher, etc).
#   - Remove o arquivo de variáveis de ambiente gerado (k3s_cluster_vars.sh).
#   - Remove entradas do /etc/hosts geradas pela instalação.
#   - Reverte configurações do Firewall (UFW) para o estado original.
#   - Reabilita o swap.
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
#   28/11/2025
#
# Pré-requisitos:
#   - Acesso root (sudo).
#   - Script deve ser executado no nó que deseja limpar.
#
# Como usar:
#   1. chmod +x cleanup_k3s_control_plane.sh
#   2. sudo ./cleanup_k3s_control_plane.sh
#
# Onde Utilizar:
#   - Diretamente no nó Control Plane (VM) que será desinstalado/limpo.
#
# -----------------------------------------------------------------------------

# --- Constantes ---
CONFIG_FILE="k3s_cluster_vars.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE_PATH="$SCRIPT_DIR/$CONFIG_FILE"

function error_exit { echo -e "\n\e[31mERRO: $1\e[0m" >&2; exit 1; }
function check_command { if [ $? -ne 0 ]; then error_exit "$1"; fi; }

if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, execute este script como root (sudo)."
fi

# Load variables if config exists to help with cleanup
if [ -f "$CONFIG_FILE_PATH" ]; then
    source "$CONFIG_FILE_PATH"
fi

echo -e "\e[34m--- Iniciando limpeza do nó Control Plane ---\e[0m"
read -p "TEM CERTEZA que deseja remover COMPLETAMENTE o K3s deste nó? (s/n): " confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    exit 0
fi

# 1. Desinstalar K3s
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    echo "Executando desinstalador do K3s..."
    /usr/local/bin/k3s-uninstall.sh
else
    echo "Desinstalador não encontrado. Tentando parar serviços manualmente..."
    systemctl stop k3s 2>/dev/null
    systemctl disable k3s 2>/dev/null
    rm -f /usr/local/bin/k3s
    rm -f /etc/systemd/system/k3s.service
    systemctl daemon-reload
fi

# 2. Limpeza de Arquivos
echo "Removendo diretórios e configurações residuais..."
rm -rf /etc/rancher/k3s
rm -rf /var/lib/rancher/k3s
rm -rf /var/lib/kubelet
rm -rf ~/.kube
rm -f /usr/local/bin/kubectl
rm -f /usr/local/bin/crictl
rm -f /etc/sysctl.d/99-kubernetes-cri.conf



# 3. Limpeza de Hosts
echo "Limpando /etc/hosts..."
sed -i '/k3s-control-plane/d' /etc/hosts
sed -i '/k3s-worker/d' /etc/hosts
sed -i '/k3s-storage-nfs/d' /etc/hosts

# 4. Limpeza de Firewall (UFW)
# Elimina regras específicas baseadas nas variáveis carregadas
if [ -n "$ADMIN_NETWORK_CIDRS" ]; then
    for cidr in $ADMIN_NETWORK_CIDRS; do
        ufw delete allow from "$cidr" to any port 22 proto tcp >/dev/null 2>&1
        ufw delete allow from "$cidr" to any port 6443 proto tcp >/dev/null 2>&1
    done
fi

if [ -n "$K3S_LAN_CIDR" ]; then
    ufw delete allow from "$K3S_LAN_CIDR" to any port 6443 proto tcp >/dev/null 2>&1
    ufw delete allow from "$K3S_LAN_CIDR" to any port 2379:2380 proto tcp >/dev/null 2>&1
    ufw delete allow from "$K3S_LAN_CIDR" to any port 10250 proto tcp >/dev/null 2>&1
    ufw delete allow from "$K3S_LAN_CIDR" to any port 8472 proto udp >/dev/null 2>&1
    ufw delete allow from "$K3S_LAN_CIDR" to any port 10251 proto tcp >/dev/null 2>&1
    ufw delete allow from "$K3S_LAN_CIDR" to any port 10252 proto tcp >/dev/null 2>&1
fi

# Limpeza genérica de backup
ufw delete allow 6443/tcp >/dev/null 2>&1
ufw delete allow 10250/tcp >/dev/null 2>&1
ufw delete allow 8472/udp >/dev/null 2>&1

# Reverte política de encaminhamento para DROP (padrão seguro)
if grep -q 'DEFAULT_FORWARD_POLICY="ACCEPT"' /etc/default/ufw; then
    sed -i 's/DEFAULT_FORWARD_POLICY="ACCEPT"/DEFAULT_FORWARD_POLICY="DROP"/g' /etc/default/ufw
    echo "Política de encaminhamento UFW revertida para DROP."
fi
ufw reload >/dev/null 2>&1

# Remove arquivo de variáveis por último
if [ -f "$CONFIG_FILE_PATH" ]; then
    echo "Removendo arquivo de variáveis ($CONFIG_FILE_PATH)..."
    rm -f "$CONFIG_FILE_PATH"
fi

# 5. Reabilitar Swap (Opcional, mas volta ao estado original)
# Descomenta linhas de swap no fstab
sed -i '/ swap / s/^#//' /etc/fstab

echo ""
echo "--------------------------------------------------------------------"
echo "Limpeza concluída."
echo "--------------------------------------------------------------------"
read -p "Deseja reiniciar o servidor agora para aplicar todas as mudanças de kernel/network? (s/n): " reboot_ans
if [[ "$reboot_ans" =~ ^[Ss]$ ]]; then
    echo "Reiniciando em 5 segundos..."
    sleep 5
    reboot
else
    echo "Reinicialização adiada. Lembre-se de reiniciar manualmente."
fi
