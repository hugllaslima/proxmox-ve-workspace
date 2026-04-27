#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: cluster_maintenance_tool.sh
#
# Descrição:
#   Ferramenta interativa para manutenção do cluster Kubernetes (K3s).
#   Permite visualizar e remover recursos "presos" ou obsoletos de forma segura.
#
# Funcionalidades:
#   - Listar e Excluir Nós (Nodes) - útil para remover workers antigos.
#   - Listar e Excluir Pods (Forçar exclusão) - útil para pods em 'Terminating'.
#   - Listar e Excluir Namespaces.
#   - Drenar Nós (Drain) - prepara um nó para manutenção.
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
#   28/11/2025
#
# Pré-requisitos:
#   - Acesso kubectl configurado (executar no Control Plane ou máquina com kubeconfig).
#   - Permissões de administrador no cluster.
#
# Como usar:
#   1. chmod +x cluster_maintenance_tool.sh
#   2. ./cluster_maintenance_tool.sh
#   3. Escolha as opções no menu interativo.
#
# Onde Utilizar:
#   - Pode ser executado no nó Control Plane ou na máquina de gerenciamento,
#     desde que o `kubectl` esteja configurado e acessível.
#
# -----------------------------------------------------------------------------

# --- Cores e Formatação ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_header {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

function success_message {
    echo -e "${GREEN}SUCESSO: $1${NC}"
}

function warning_message {
    echo -e "${YELLOW}AVISO: $1${NC}"
}

function error_message {
    echo -e "${RED}ERRO: $1${NC}"
}

# --- Checagem Inicial ---
if ! command -v kubectl &> /dev/null; then
    error_message "kubectl não encontrado. Execute este script em um nó Control Plane ou máquina gerenciadora."
    exit 1
fi

# --- Funções de Operação ---

function manage_nodes {
    while true; do
        print_header "Gerenciamento de Nós"
        echo "Listando nós atuais..."
        kubectl get nodes -o wide
        echo ""
        echo "Opções:"
        echo "1) Excluir um nó (Delete Node)"
        echo "2) Drenar um nó (Drain Node)"
        echo "3) Desmarcar nó como não agendável (Uncordon)"
        echo "0) Voltar ao menu principal"
        
        read -p "Escolha uma opção: " opt_node
        case $opt_node in
            1)
                read -p "Digite o NOME do nó para excluir: " node_name
                if [ -z "$node_name" ]; then continue; fi
                
                warning_message "Isso removerá o nó '$node_name' do registro do Kubernetes."
                warning_message "Se o servidor físico ainda estiver rodando o agente K3s, ele pode tentar voltar."
                read -p "Tem certeza? (s/n): " confirm
                if [[ "$confirm" =~ ^[Ss]$ ]]; then
                    kubectl delete node "$node_name"
                fi
                ;;
            2)
                read -p "Digite o NOME do nó para drenar: " node_name
                if [ -z "$node_name" ]; then continue; fi
                
                echo "Drenando nó (ignorando DaemonSets)..."
                kubectl drain "$node_name" --ignore-daemonsets --delete-emptydir-data
                ;;
            3)
                read -p "Digite o NOME do nó para liberar (Uncordon): " node_name
                kubectl uncordon "$node_name"
                ;;
            0) break ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

function manage_pods {
    while true; do
        print_header "Gerenciamento de Pods"
        echo "1) Listar todos os pods (All Namespaces)"
        echo "2) Listar pods com erro (não Running)"
        echo "3) Forçar exclusão de um pod (Force Delete)"
        echo "0) Voltar ao menu principal"
        
        read -p "Escolha uma opção: " opt_pod
        case $opt_pod in
            1) kubectl get pods -A ;;
            2) kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded ;;
            3)
                read -p "Digite o NAMESPACE do pod: " pod_ns
                read -p "Digite o NOME do pod: " pod_name
                if [ -n "$pod_ns" ] && [ -n "$pod_name" ]; then
                    warning_message "Forçando exclusão do pod '$pod_name' no namespace '$pod_ns'..."
                    kubectl delete pod "$pod_name" -n "$pod_ns" --grace-period=0 --force
                fi
                ;;
            0) break ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

function manage_namespaces {
    while true; do
        print_header "Gerenciamento de Namespaces"
        kubectl get namespaces
        echo ""
        echo "1) Excluir um namespace"
        echo "0) Voltar ao menu principal"
        
        read -p "Escolha uma opção: " opt_ns
        case $opt_ns in
            1)
                read -p "Digite o NOME do namespace para excluir: " ns_name
                if [ -z "$ns_name" ]; then continue; fi
                
                warning_message "Isso excluirá TODOS os recursos dentro do namespace '$ns_name'."
                read -p "Tem certeza absoluta? (s/n): " confirm
                if [[ "$confirm" =~ ^[Ss]$ ]]; then
                    kubectl delete namespace "$ns_name"
                fi
                ;;
            0) break ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

# --- Menu Principal ---

while true; do
    print_header "Ferramenta de Manutenção K3s"
    echo "1) Gerenciar Nós (Nodes)"
    echo "2) Gerenciar Pods"
    echo "3) Gerenciar Namespaces"
    echo "0) Sair"
    
    read -p "Escolha uma opção: " main_opt
    case $main_opt in
        1) manage_nodes ;;
        2) manage_pods ;;
        3) manage_namespaces ;;
        0) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
done
