#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: install_k3s_management.sh
#
# Descrição:
#   Este script automatiza a configuração de addons essenciais para um cluster
#   Kubernetes (K3s), incluindo a configuração do kubectl, a instalação do Helm,
#   K9s (Terminal UI) e a implantação de componentes como NFS Subdir External
#   Provisioner, MetalLB e Nginx Ingress Controller.
#
#   O script é interativo e solicita as informações necessárias, como IPs
#   do cluster K3s, IP do servidor NFS, caminho do compartilhamento NFS,
#   e caminhos de rede, para personalizar a instalação.
#
# Funcionalidades:
#   - Instalação do Kubectl e Helm.
#   - Configuração do acesso ao cluster (kubeconfig).
#   - Instalação e configuração do NFS Subdir External Provisioner.
#   - Instalação e configuração do MetalLB (Load Balancer).
#   - Instalação e configuração do Nginx Ingress Controller.
#   - Instalação do K9s (Terminal UI) para monitoramento.
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
#   - Um cluster K3s já deve estar instalado e em execução.
#   - O nó control-plane do K3s deve estar acessível via SSH a partir da máquina
#     onde este script será executado.
#   - Um servidor NFS deve estar configurado e acessível na rede.
#   - Acesso à internet para baixar as ferramentas e imagens.
#
# Como usar:
#   1. Dê permissão de execução ao script:
#      chmod +x install_k3s_management.sh
#   2. Execute o script:
#      ./install_k3s_management.sh (NÃO usar sudo, a menos que necessário)
#   3. Siga as instruções no terminal.
#
# Onde Utilizar:
#   - Este script deve ser executado em uma máquina de gerenciamento (como um
#     laptop ou um servidor de administração) que tenha acesso de rede ao
#     cluster Kubernetes e ao servidor NFS.
#
# -----------------------------------------------------------------------------

# --- Constantes ---
CONFIG_FILE="k3s_cluster_vars.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE_PATH="$SCRIPT_DIR/$CONFIG_FILE"

# --- Variáveis de Configuração ---
K3S_CONTROL_PLANE_1_IP=""
NFS_SERVER_IP=""
NFS_SHARE_PATH=""
METALLB_IP_RANGE=""
SSH_USER=""

# --- Funções Auxiliares ---

# Função para exibir mensagens de erro e sair
function error_exit {
    echo "ERRO: $1" >&2
    exit 1
}

# Função para verificar se um comando foi bem-sucedido
function check_command {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# Função para coletar entrada do usuário
function get_user_input {
    local prompt_message="$1"
    local default_value="$2"
    local var_name="$3"

    if [ -n "$default_value" ]; then
        prompt_message="$prompt_message (Padrão: $default_value)"
    fi

    while true; do
        read -p "$prompt_message: " input_value
        if [ -z "$input_value" ] && [ -n "$default_value" ]; then
            eval "$var_name=\"$default_value\""
            break
        elif [ -n "$input_value" ]; then
            eval "$var_name=\"$input_value\""
            break
        else
            echo "Entrada não pode ser vazia. Por favor, tente novamente."
            continue
        fi
    done
}

# --- Início do Script ---

echo -e "\e[34m--- Configuração de Addons do Kubernetes ---\e[0m"
echo "Este script irá configurar o kubectl e instalar o NFS Provisioner, MetalLB e Nginx Ingress Controller."

# Tenta carregar variáveis do arquivo de configuração
if [ -f "$CONFIG_FILE_PATH" ]; then
    echo -e "\e[32mArquivo de configuração encontrado: $CONFIG_FILE\e[0m"
    echo "Carregando variáveis..."
    source "$CONFIG_FILE_PATH"
else
    echo -e "\e[33mAviso: Arquivo de configuração '$CONFIG_FILE' não encontrado.\e[0m"
    echo "Você precisará fornecer as informações manualmente."
fi

# Solicita informações faltantes ou confirma as carregadas
if [ -z "$K3S_CONTROL_PLANE_1_IP" ]; then
    get_user_input "Digite o IP do Control Plane 1" "192.168.10.20" "K3S_CONTROL_PLANE_1_IP"
fi

if [ -z "$NFS_SERVER_IP" ]; then
    get_user_input "Digite o IP do Servidor NFS" "192.168.10.25" "NFS_SERVER_IP"
fi

if [ -z "$NFS_SHARE_PATH" ]; then
    get_user_input "Digite o Caminho do Compartilhamento NFS" "/mnt/k3s-share-nfs/" "NFS_SHARE_PATH"
fi

# MetalLB precisa de um range de IPs. Isso geralmente não está no config do cluster base.
if [ -z "$METALLB_IP_RANGE" ]; then
    echo -e "\e[33mAviso: A faixa de IP do MetalLB não está definida no arquivo de configuração.\e[0m"
    get_user_input "Digite a faixa de IPs para o MetalLB (ex: 10.10.3.200-10.10.3.250)" "10.10.3.200-10.10.3.250" "METALLB_IP_RANGE"
fi

# Usuário SSH para buscar o kubeconfig
get_user_input "Digite o usuário SSH do servidor K3s (para buscar o kubeconfig)" "ubuntu" "SSH_USER"

echo ""
echo "--- Resumo das Configurações ---"
echo "Control Plane IP: $K3S_CONTROL_PLANE_1_IP"
echo "NFS Server: $NFS_SERVER_IP:$NFS_SHARE_PATH"
echo "MetalLB Range: $METALLB_IP_RANGE"
echo "Usuário SSH: $SSH_USER"
echo ""
read -p "Confirma as informações? (s/n): " confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    exit 0
fi

# 1. Instalar Kubectl
echo -e "\n\e[34m--- 1. Instalando/Atualizando Kubectl ---\e[0m"
if ! command -v kubectl &> /dev/null; then
    echo "Baixando kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    check_command "Falha ao instalar kubectl."
else
    echo "kubectl já instalado."
fi

# 2. Configurar Kubeconfig
echo -e "\n\e[34m--- 2. Configurando Acesso ao Cluster ---\e[0m"
mkdir -p ~/.kube
echo "Buscando kubeconfig do servidor $K3S_CONTROL_PLANE_1_IP..."
scp "$SSH_USER@$K3S_CONTROL_PLANE_1_IP:/etc/rancher/k3s/k3s.yaml" ~/.kube/config
check_command "Falha ao copiar kubeconfig. Verifique o acesso SSH."

# Ajustar o IP no kubeconfig (de 127.0.0.1 para o IP real)
sed -i "s/127.0.0.1/$K3S_CONTROL_PLANE_1_IP/g" ~/.kube/config
chmod 600 ~/.kube/config
echo "Acesso configurado. Testando..."
kubectl get nodes
check_command "Falha ao conectar ao cluster."

# 3. Instalar Helm
echo -e "\n\e[34m--- 3. Instalando Helm ---\e[0m"
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    check_command "Falha ao instalar Helm."
else
    echo "Helm já instalado."
fi

# Adicionar repositórios Helm
echo "Adicionando repositórios Helm..."
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo add metallb https://metallb.github.io/metallb
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 4. Instalar NFS Provisioner
echo -e "\n\e[34m--- 4. Instalando NFS Provisioner ---\e[0m"
# Cria namespace se não existir
kubectl create namespace nfs-provisioner --dry-run=client -o yaml | kubectl apply -f -

echo "Instalando Chart NFS..."
helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace nfs-provisioner \
    --set nfs.server="$NFS_SERVER_IP" \
    --set nfs.path="$NFS_SHARE_PATH" \
    --set storageClass.onDelete="true" # Mantém dados se o PVC for deletado (opcional, mude para false para limpar)

check_command "Falha ao instalar NFS Provisioner."

# 5. Instalar MetalLB
echo -e "\n\e[34m--- 5. Instalando MetalLB ---\e[0m"
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install metallb metallb/metallb --namespace metallb-system
check_command "Falha ao instalar MetalLB."

echo "Aguardando MetalLB Controller ficar pronto..."
kubectl rollout status deployment/metallb-controller -n metallb-system --timeout=90s

echo "Configurando IP Address Pool do MetalLB..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
check_command "Falha ao aplicar configuração do MetalLB."


# 6. Instalar K9s
echo -e "\n\e[34m--- 6. Instalando K9s (Terminal UI) ---\e[0m"
if ! command -v k9s &> /dev/null; then
    echo "K9s não encontrado. Instalando K9s..."
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    echo "Baixando versão: $K9S_VERSION"
    
    # Usa um diretório temporário para evitar problemas de permissão no diretório atual
    TEMP_DIR=$(mktemp -d)
    
    curl -Lo "$TEMP_DIR/k9s.tar.gz" "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
    tar -xzf "$TEMP_DIR/k9s.tar.gz" -C "$TEMP_DIR"
    sudo install -o root -g root -m 0755 "$TEMP_DIR/k9s" /usr/local/bin/k9s
    
    # Limpeza
    rm -rf "$TEMP_DIR"
    
    if command -v k9s &> /dev/null; then
        echo "K9s instalado com sucesso!"
    else
        echo "ERRO: Falha ao instalar K9s."
    fi
else
    echo "K9s já instalado."
fi


# 7. Instalar Nginx Ingress
echo -e "\n\e[34m--- 7. Instalando Nginx Ingress Controller ---\e[0m"
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Instalação básica. O MetalLB vai atribuir um IP externo automaticamente ao serviço LoadBalancer do Ingress.
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --set controller.service.type=LoadBalancer

    --set controller.service.type=LoadBalancer

check_command "Falha ao instalar Nginx Ingress."

# > [!WARNING]
# > **Nota sobre o Ingress NGINX**: O projeto comunitário `ingress-nginx` anunciou o fim do suporte "best-effort" para março de 2026. Uma atualização futura deste projeto migrará para uma alternativa (como Traefik v3 ou Gateway API). Por enquanto, ele continua funcional e estável.

echo -e "\n\e[32m--- Configuração de Addons do Kubernetes concluída ---\e[0m"
echo "Use 'kubectl get pods -A' para verificar o status dos pods."
echo "Use 'kubectl get svc -n ingress-nginx' para ver o IP externo atribuído ao Ingress."
