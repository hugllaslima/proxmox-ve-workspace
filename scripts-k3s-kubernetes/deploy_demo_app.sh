#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: deploy_demo_app.sh
#
# Descrição:
#   Implanta uma aplicação de demonstração ("Hello World") para validar o funcionamento
#   completo do cluster: Deployment -> Service -> Ingress -> MetalLB -> Navegador.
#
# Funcionalidades:
#   - Cria um Deployment do Nginx (nginxdemos/hello).
#   - Cria um Service ClusterIP para expor os pods.
#   - Cria um Ingress Resource para roteamento externo via Nginx Ingress Controller.
#   - Exibe a URL final de acesso (baseada no IP do MetalLB).
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
#   26/12/2025
#
# Pré-requisitos:
#   - Cluster K3s funcional com Ingress Nginx e MetalLB configurados.
#   - kubectl configurado e acessível.
#
# Como usar:
#   1. chmod +x deploy_demo_app.sh
#   2. ./deploy_demo_app.sh
#
# Onde Utilizar:
#   - Máquina de gerenciamento ou qualquer nó com kubectl configurado.
#
# -----------------------------------------------------------------------------

echo -e "\e[34m--- Implantando Aplicação de Demonstração (Hello World) ---\e[0m"

# Verifica kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Erro: kubectl não encontrado."
    exit 1
fi

NAMESPACE="default"
APP_NAME="hello-world-demo"

echo "Criando recursos no namespace '$NAMESPACE'..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: nginx
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-svc
  namespace: $NAMESPACE
spec:
  type: ClusterIP
  selector:
    app: $APP_NAME
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $APP_NAME-ingress
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hello
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME-svc
            port:
              number: 80
EOF

echo -e "\n\e[32mAplicação implantada com sucesso!\e[0m"
echo "Aguardando Ingress Controller obter o IP..."

sleep 5

# Obtém o IP do Ingress Controller
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    echo -e "\e[33mAviso: O IP do Ingress ainda não foi atribuído. Verifique 'kubectl get svc -n ingress-nginx'.\e[0m"
else
    echo -e "\n\e[32m=== Teste de Acesso ===\e[0m"
    echo "Abra o navegador ou use o curl no seguinte endereço:"
    echo -e "\e[36mhttp://$INGRESS_IP/hello\e[0m"
    echo ""
    echo "Se você ver uma página com 'Server address' e 'Server name', tudo está funcionando!"
    echo "Para remover essa demo depois, execute: kubectl delete deployment,svc,ingress -l app=$APP_NAME"
fi
