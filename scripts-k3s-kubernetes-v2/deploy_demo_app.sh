#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: deploy_demo_app.sh
#
# Descrição:
#   Implanta uma aplicação de demonstração ("Hello World") para validar o funcionamento
#   completo do cluster utilizando Gateway API: Deployment -> Service -> Gateway -> MetalLB.
#
# Funcionalidades:
#   - Cria um Deployment do Nginx (nginxdemos/hello).
#   - Cria um Service ClusterIP para expor os pods.
#   - Cria um Gateway e HTTPRoute para roteamento via Traefik (Gateway API).
#   - Exibe a URL final de acesso (baseada no IP do MetalLB).
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
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: $APP_NAME-gateway
  namespace: $NAMESPACE
spec:
  gatewayClassName: traefik
  listeners:
  - name: web
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: $APP_NAME-route
  namespace: $NAMESPACE
spec:
  parentRefs:
  - name: $APP_NAME-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /hello
    backendRefs:
    - name: $APP_NAME-svc
      port: 80
EOF

echo -e "\n\e[32mAplicação implantada com sucesso!\e[0m"
echo "Aguardando Gateway obter o IP..."

sleep 5

# Obtém o IP do Gateway (Traefik Service)
INGRESS_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    echo -e "\e[33mAviso: O IP do Gateway ainda não foi atribuído. Verifique 'kubectl get svc -n kube-system traefik'.\e[0m"
else
    echo -e "\n\e[32m=== Teste de Acesso ===\e[0m"
    echo "Abra o navegador ou use o curl no seguinte endereço:"
    echo -e "\e[36mhttp://$INGRESS_IP/hello\e[0m"
    echo ""
    echo "Se você ver uma página com 'Server address' e 'Server name', tudo está funcionando!"
    echo "Para remover essa demo depois, execute: kubectl delete deployment,svc,gateway,httproute -l app=$APP_NAME"
fi
