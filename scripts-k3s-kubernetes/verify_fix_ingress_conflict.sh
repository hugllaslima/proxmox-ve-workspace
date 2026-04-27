#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: verify_fix_ingress_conflict.sh
#
# Descrição:
#   Este script ajusta a configuração de um nó K3s existente para desativar
#   o Traefik e o ServiceLB (Klipper LB). Isso é necessário para resolver
#   conflitos de porta (80/443) ao utilizar o Nginx Ingress Controller e MetalLB.
#
# Funcionalidades:
#   - Verifica e cria/atualiza o arquivo /etc/rancher/k3s/config.yaml.
#   - Adiciona as flags 'disable: traefik' e 'disable: servicelb'.
#   - Reinicia o serviço K3s para aplicar as alterações.
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
#   - Acesso root/sudo.
#   - Cluster K3s instalado.
#
# Como usar:
#   1. chmod +x verify_fix_ingress_conflict.sh
#   2. sudo ./verify_fix_ingress_conflict.sh
#
# Onde Utilizar:
#   - Deve ser executado em TODOS os nós do Control Plane se o cluster
#     já estiver instalado e apresentando conflitos no Ingress.
#
# -----------------------------------------------------------------------------

echo -e "\e[34m--- Ajustando configuração do K3s para desativar Traefik e ServiceLB ---\e[0m"

CONFIG_FILE="/etc/rancher/k3s/config.yaml"
mkdir -p /etc/rancher/k3s

# Verifica se já existe configuração de disable
if grep -q "disable:" "$CONFIG_FILE" 2>/dev/null; then
    echo "Configuração já existente. Verificando itens..."
else
    echo "disable:" >> "$CONFIG_FILE"
fi

# Adiciona traefik se não estiver listado
if ! grep -q "traefik" "$CONFIG_FILE"; then
    echo "  - traefik" >> "$CONFIG_FILE"
    echo "Traefik desativado no config."
fi

# Adiciona servicelb se não estiver listado
if ! grep -q "servicelb" "$CONFIG_FILE"; then
    echo "  - servicelb" >> "$CONFIG_FILE"
    echo "ServiceLB desativado no config."
fi

echo -e "\e[34mReiniciando serviço K3s...\e[0m"
systemctl restart k3s

echo -e "\e[34mConcluído neste nó.\e[0m"
