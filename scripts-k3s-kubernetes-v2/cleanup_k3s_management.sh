#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: cleanup_k3s_management.sh
#
# Descrição:
#   Este script reverte a configuração realizada pelo 'install_k3s_management.sh'.
#   Ele desinstala os addons (Nginx Ingress, MetalLB, NFS Provisioner) usando
#   o Helm, remove os namespaces associados e limpa a configuração local do
#   kubectl. O objetivo é deixar o cluster em um estado limpo, sem os addons.
#
# Funcionalidades:
#   - Desinstala os charts Helm do MetalLB e NFS Provisioner.
#   - Remove os namespaces 'metallb-system' e 'nfs-provisioner'.
#   - Remove os CRDs da Gateway API.
#   - Remove os repositórios Helm adicionados.
#   - Limpa o arquivo de configuração local do kubectl (~/.kube/config).
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
#   - Acesso a um cluster Kubernetes configurado via `kubectl`.
#   - Helm v3 instalado na máquina de gerenciamento.
#   - Permissões para desinstalar charts e deletar namespaces no cluster.
#
# Como usar:
#   1. Dê permissão de execução ao script:
#      chmod +x cleanup_k3s_management.sh
#   2. Execute o script na sua máquina de gerenciamento:
#      ./cleanup_k3s_management.sh
#   3. Confirme a ação quando solicitado.
#
# Onde Utilizar:
#   - EXCLUSIVAMENTE na máquina de gerenciamento (k3s-management) onde os addons foram instalados.
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
export KUBECONFIG="$REAL_HOME/.kube/config"

# --- Funções Auxiliares ---

function print_info {
    echo "INFO: $1"
}

function print_warning {
    echo "AVISO: $1"
}

function check_command_exists {
    if ! command -v $1 &> /dev/null; then
        print_warning "O comando '$1' não foi encontrado. Esta etapa será pulada, mas a limpeza pode ser incompleta."
        return 1
    fi
    return 0
}

# --- Início do Script ---

echo "--------------------------------------------------------------------"
echo "--- Script de Limpeza dos Addons do K3s ---"
echo "--------------------------------------------------------------------"
echo "Este script irá remover PERMANENTEMENTE os addons MetalLB,"
echo "NFS Provisioner e os CRDs da Gateway API, além de limpar"
echo "Esta ação não pode ser desfeita."
echo ""
read -p "Você tem certeza que deseja continuar? (s/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^([sS][iI][mM]|[sS])$ ]]; then
        echo "Limpeza cancelada pelo usuário."
        exit 0
    fi

echo ""
print_info "--- 1. Desinstalando Addons com Helm ---"

    if check_command_exists helm; then
        print_info "Desinstalando MetalLB..."
        helm uninstall metallb --namespace metallb-system || print_warning "Falha ao desinstalar metallb. Pode já ter sido removido."

        print_info "Desinstalando NFS Subdir External Provisioner..."
        helm uninstall nfs-subdir-external-provisioner --namespace nfs-provisioner || print_warning "Falha ao desinstalar nfs-subdir-external-provisioner. Pode já ter sido removido."
    else
        print_warning "Helm não encontrado. Pulando a desinstalação dos addons."
    fi

echo ""
print_info "--- 2. Removendo Namespaces ---"

    if check_command_exists kubectl; then
        print_info "Removendo namespace metallb-system..."
        kubectl delete namespace metallb-system --ignore-not-found

        print_info "Removendo namespace nfs-provisioner..."
        kubectl delete namespace nfs-provisioner --ignore-not-found
        print_info "Removendo Gateway API CRDs..."
        kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml --ignore-not-found || print_warning "Falha ao remover CRDs. Podem já ter sido removidos."
    else
        print_warning "Kubectl não encontrado. Pulando a remoção de namespaces."
    fi

echo ""
print_info "--- 3. Removendo Repositórios Helm ---"

    if check_command_exists helm; then
        helm repo remove metallb 2>/dev/null || true
        helm repo remove nfs-subdir-external-provisioner 2>/dev/null || true
        print_info "Repositórios removidos."
    fi

echo ""
print_info "--- 4. Limpando Configuração Local do Kubectl ---"
    
    
    if [ -f "$REAL_HOME/.kube/config" ]; then
        print_info "Removendo $REAL_HOME/.kube/config..."
        rm "$REAL_HOME/.kube/config"
    else
        print_info "Arquivo $REAL_HOME/.kube/config não encontrado."
    fi

    # Remove o arquivo k3s_cluster_vars.sh, se existir
    if [ -f "k3s_cluster_vars.sh" ]; then
        print_info "Removendo k3s_cluster_vars.sh..."
        rm k3s_cluster_vars.sh
    fi
    
    # Remove binário kubectl residual no diretório atual (se houver)
    # Remove binário kubectl residual no diretório atual (se houver)
    if [ -f "kubectl" ]; then
        print_info "Removendo binário kubectl do diretório atual..."
        rm kubectl
    fi

echo ""
print_info "--- 5. Removendo Ferramentas Instaladas (Opcional) ---"
    
    if [ -f "/usr/local/bin/k9s" ]; then
        print_info "Removendo K9s (/usr/local/bin/k9s)..."
        rm /usr/local/bin/k9s
    fi

    if [ -f "/usr/local/bin/kubectl" ]; then
        print_info "Removendo Kubectl (/usr/local/bin/kubectl)..."
        rm /usr/local/bin/kubectl
    fi

echo ""
echo "--------------------------------------------------------------------"
echo "Limpeza concluída com sucesso."
echo "--------------------------------------------------------------------"
