#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: verify_k3s_management_addons.sh
#
# Descrição:
#   Este script realiza testes funcionais automatizados para validar se os
#   Addons essenciais do cluster (NFS Provisioner, MetalLB e Ingress Nginx)
#   estão operando corretamente na prática.
#
# Funcionalidades:
#   - Valida se os pods dos addons estão com status 'Running'.
#   - Testa o MetalLB verificando se o Ingress Controller recebe um IP externo.
#   - Testa o NFS Provisioner criando um PVC e um Pod de teste que escreve dados reais.
#   - Diagnostica problemas comuns de conexão (kubeconfig) e dependências (nfs-common).
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
#   19/12/2025
#
# Pré-requisitos:
#   - Cluster K3s instalado e Addons configurados (via install_k3s_management.sh).
#   - Acesso à máquina de gerenciamento com kubectl configurado.
#   - Pacote 'nfs-common' instalado em todos os nós do cluster (já incluído nos scripts de instalação).
#
# Como usar:
#   1. chmod +x verify_k3s_management_addons.sh
#   2. ./verify_k3s_management_addons.sh (NÃO use sudo se o kubectl for do usuário)
#
# Onde Utilizar:
#   - Execute este script EXCLUSIVAMENTE na máquina de gerenciamento (k3s-management).
#
# -----------------------------------------------------------------------------

echo -e "\e[34m--- Verificação de Addons do K3s ---\e[0m"

# Verifica se o kubectl está disponível e configurado
if ! command -v kubectl &> /dev/null; then
    echo -e "\e[31mErro: kubectl não encontrado. Execute este script na máquina de gerenciamento onde o kubectl foi instalado.\e[0m"
    exit 1
fi

# Verifica a conexão com o cluster
if ! kubectl get nodes &> /dev/null; then
    echo -e "\e[31mERRO: Não foi possível conectar ao cluster Kubernetes.\e[0m"
    echo "Diagnóstico:"
    echo "1. O arquivo de configuração (~/.kube/config) pode não existir ou estar incorreto."
    echo "2. O serviço K3s pode estar parado no control-plane."
    
    # Tentativa de recuperação para uso com sudo
    if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -f "$USER_HOME/.kube/config" ]; then
             echo -e "\n\e[33mALERTA: Você executou como root (sudo), mas a configuração está no usuário '$SUDO_USER'.\e[0m"
             echo "Tentando usar a configuração em: $USER_HOME/.kube/config"
             export KUBECONFIG="$USER_HOME/.kube/config"
             
             if kubectl get nodes &> /dev/null; then
                 echo -e "\e[32mConexão estabelecida com sucesso!\e[0m"
                 echo "Dica: Para evitar isso, execute o script SEM sudo: ./verify_k3s_management_addons.sh"
             else
                 echo -e "\e[31mFalha mesmo usando o arquivo de configuração do usuário.\e[0m"
                 exit 1
             fi
        else
            echo "Dica: Tente rodar este script SEM sudo."
            exit 1
        fi
    else
        echo "Dica: Verifique se o arquivo ~/.kube/config existe."
        exit 1
    fi
fi

# 1. Verificação Visual dos Pods
echo -e "\n\e[34m--- 1. Status dos Pods ---\e[0m"
ALL_HEALTHY=true
for ns in nfs-provisioner metallb-system ingress-nginx; do
    echo "Verificando namespace: $ns"
    # Conta linhas que não sejam cabeçalho e não estejam Running ou Completed
    PROBLEMATIC_PODS=$(kubectl get pods -n "$ns" --no-headers | grep -v "Running\|Completed")
    
    if [ -n "$PROBLEMATIC_PODS" ]; then
        echo -e "\e[33mALERTA: Há pods com problemas em $ns:\e[0m"
        echo "$PROBLEMATIC_PODS"
        ALL_HEALTHY=false
    else
        echo -e "\e[32mOK: Todos os pods em $ns parecem saudáveis.\e[0m"
    fi
    echo ""
done

# 2. Teste do Ingress/MetalLB
echo -e "\e[34m--- 2. Verificando MetalLB e Ingress IP ---\e[0m"
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo -e "\e[31mFALHA: O Ingress Controller não recebeu um IP externo do MetalLB.\e[0m"
    echo "Verifique se o range de IPs do MetalLB está correto e se não há conflitos."
    ALL_HEALTHY=false
else
    echo -e "\e[32mSUCESSO: Ingress Controller recebeu o IP: $INGRESS_IP\e[0m"
fi

# 3. Teste Funcional do NFS
echo -e "\n\e[34m--- 3. Teste Funcional de Armazenamento (NFS) ---\e[0m"
echo "Criando PVC de teste..."

# Limpa teste anterior se existir
kubectl delete pod nfs-test-pod --ignore-not-found &> /dev/null
kubectl delete pvc nfs-test-pvc --ignore-not-found &> /dev/null

# Cria PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-test-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Mi
EOF

if [ $? -eq 0 ]; then
    echo "PVC criado. Aguardando Bound..."
    sleep 3
    PVC_STATUS=$(kubectl get pvc nfs-test-pvc -o jsonpath='{.status.phase}')
    
    if [ "$PVC_STATUS" == "Bound" ]; then
        echo -e "\e[32mSUCESSO: PVC 'nfs-test-pvc' está Bound (Vinculado).\e[0m"
        
        echo "Criando Pod para testar escrita..."
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nfs-test-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "echo 'Teste NFS K3s' > /mnt/test.txt && cat /mnt/test.txt && sleep 3600"]
    volumeMounts:
    - name: nfs-test-vol
      mountPath: "/mnt"
  volumes:
  - name: nfs-test-vol
    persistentVolumeClaim:
      claimName: nfs-test-pvc
EOF
        echo "Aguardando Pod iniciar..."
        kubectl wait --for=condition=Ready pod/nfs-test-pod --timeout=60s &> /dev/null
        
        if [ $? -eq 0 ]; then
             echo -e "\e[32mSUCESSO: Pod de teste iniciou e montou o volume.\e[0m"
             echo "Limpando teste..."
             kubectl delete pod nfs-test-pod --force &> /dev/null
             kubectl delete pvc nfs-test-pvc --force &> /dev/null
        else
             echo -e "\e[31mTIMEOUT: O Pod de teste demorou muito para responder.\e[0m"
             echo "Verifique os logs com: kubectl describe pod nfs-test-pod"
             echo "Possível causa: Falta do pacote 'nfs-common' nos nós workers."
             ALL_HEALTHY=false
        fi
        
    else
        echo -e "\e[31mFALHA: O PVC não obteve status Bound. Status atual: $PVC_STATUS\e[0m"
        echo "Verifique os logs do provisioner: kubectl logs -l app=nfs-subdir-external-provisioner -n nfs-provisioner"
        ALL_HEALTHY=false
    fi
else
    echo -e "\e[31mFALHA: Não foi possível criar o PVC.\e[0m"
    ALL_HEALTHY=false
fi

echo -e "\n\e[34m--- Resultado Final ---\e[0m"
if [ "$ALL_HEALTHY" = true ]; then
    echo -e "\e[32mTODOS OS TESTES PASSARAM! O cluster está pronto para uso.\e[0m"
else
    echo -e "\e[33mHOUVE FALHAS nos testes. Verifique as mensagens acima.\e[0m"
fi
