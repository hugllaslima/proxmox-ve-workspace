#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: verify_k3s_cluster_health.sh
#
# Descrição:
#   Este script realiza uma verificação de saúde (Health Check) no cluster K3s,
#   validando o status dos nós, pods do sistema e a consistência do Etcd.
#
# Funcionalidades:
#   - Verifica o status de todos os nós (Ready/NotReady).
#   - Valida se os Control Planes estão operacionais.
#   - Checa se os pods do namespace kube-system estão rodando corretamente.
#   - Verifica membros do Etcd (apenas se executado localmente em um Control Plane).
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
#   19/12/2025
#
# Pré-requisitos:
#   - Cluster K3s instalado.
#   - Acesso root/sudo (para comandos k3s/kubectl).
#
# Como usar:
#   1. chmod +x verify_k3s_cluster_health.sh
#   2. ./verify_k3s_cluster_health.sh (Não requer sudo se o kubectl estiver configurado para o usuário)
#
# Onde Utilizar:
#   - Pode ser executado em qualquer nó do cluster ou na máquina de gerenciamento
#     (para verificações básicas). Para verificação profunda do Etcd, execute
#     em um nó Control Plane.
#
# -----------------------------------------------------------------------------

# Determina o usuário real se estiver rodando com sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER=$(whoami)
    REAL_HOME=$HOME
fi

# Define o KUBECONFIG correto para que root consiga usar o arquivo do usuário
if [ -f "$REAL_HOME/.kube/config" ]; then
    export KUBECONFIG="$REAL_HOME/.kube/config"
fi

# Função para imprimir cabeçalhos coloridos
function print_header {
    echo -e "\n\e[34m=== $1 ===\e[0m"
}

function check_command {
    if ! command -v $1 &> /dev/null; then
        echo -e "\e[31mErro: Comando '$1' não encontrado. Verifique se o ambiente tem as ferramentas necessárias.\e[0m"
        exit 1
    fi
}

# Verifica se o kubectl está disponível
check_command kubectl

print_header "1. Status dos Nós (Nodes)"
kubectl get nodes -o wide
echo -e "\nVerificando contagem de nós..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "Total de nós detectados: $NODE_COUNT"

print_header "2. Status dos Control Planes"
# Filtra apenas os nós que são control-plane/master
CP_NODES=$(kubectl get nodes --selector='node-role.kubernetes.io/control-plane' --no-headers)
echo "$CP_NODES"
echo ""
if echo "$CP_NODES" | grep -q "NotReady"; then
    echo -e "\e[31mALERTA: Um ou mais nós Control Plane estão com status 'NotReady'!\e[0m"
else
    echo -e "\e[32mOK: Todos os nós Control Plane estão 'Ready'.\e[0m"
fi

print_header "3. Status dos Pods do Sistema (kube-system)"
kubectl get pods -n kube-system -o wide
echo ""
NOT_RUNNING=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null)
if [ -n "$NOT_RUNNING" ]; then
    echo -e "\e[33mAtenção: Existem pods no namespace kube-system que não estão 'Running' ou 'Completed':\e[0m"
    echo "$NOT_RUNNING"
else
    echo -e "\e[32mOK: Todos os pods do sistema parecem estar rodando corretamente.\e[0m"
fi

print_header "4. Membros do Etcd (Alta Disponibilidade)"
# Verifica se o comando k3s está disponível para checar o etcd
if command -v k3s &> /dev/null; then
    # Etcd maintenance command requires root
    sudo k3s etcd-snapshot list 2>/dev/null
    echo -e "\nNota: Se você configurou HA com Etcd embarcado, todos os 3 nós devem estar sincronizados."
    echo "Você pode verificar logs detalhados com: journalctl -u k3s | grep etcd"
else
    echo "Comando 'k3s' não encontrado para verificação profunda do etcd."
fi

echo -e "\n\e[32m=== Verificação Concluída ===\e[0m"
