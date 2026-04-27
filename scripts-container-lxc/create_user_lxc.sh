#!/bin/bash

#==================================================================================================
# Script: create_user_lxc.sh
# Descrição: Criação e configuração de usuários em containers LXC
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-container-lxc
#==================================================================================================

# ETAPAS DO SCRIPT:
# 1. Atualização e configuração do template
# 2. Instalação do sudo e openssh-client
# 3. Criação do novo usuário
# 4. Configuração de permissões sudo
# 5. Configuração SSH com chaves
# 6. Configurações de segurança
# 7. Reinicialização do container LXC

# Uso:
#   - sudo ./create_user_lxc.sh

# ============================================================================
# ETAPA 1: CONFIGURAÇÃO INICIAL DO SISTEMA
# ============================================================================

echo "Ajustando o timezone..."
    timedatectl set-timezone America/Sao_Paulo
    echo "Timezone configurado para: $(timedatectl show --property=Timezone --value)"
    sleep 1
echo " "
echo "Atualizando o sistema operacional... "
        apt update && apt upgrade -y
echo " "

# ============================================================================
# ETAPA 2: INSTALAÇÃO DE DEPENDÊNCIAS
# ============================================================================

garante_sudo_e_openssh() {
    if ! command -v sudo >/dev/null 2>&1; then
        echo "[INFO] 'sudo' não encontrado. Instalando..."
        apt update && apt install sudo -y
        echo "[INFO] 'sudo' instalado!"
    fi
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        echo "[INFO] 'ssh-keygen' (openssh-client) não encontrado. Instalando..."
        apt update && apt install openssh-client -y
        echo "[INFO] 'openssh-client' instalado!"
    else
        echo "[INFO] 'openssh-client' já instalado."
    fi
}

# ============================================================================
# ETAPA 3: CRIAÇÃO E CONFIGURAÇÃO DO USUÁRIO
# ============================================================================

# Pergunta o nome do usuário
        read -p "Digite o nome do usuário que deseja criar: " USUARIO
echo " "
# Cria o usuário
        sudo adduser $USUARIO
echo " "
# Adiciona o usuário ao grupo "sudo"
        sudo usermod -aG sudo $USUARIO
echo " "
    if getent group lxc >/dev/null; then
        sudo usermod -aG lxc $USUARIO
        echo "Usuário $USUARIO adicionado ao grupo lxc."
    elif getent group lxd >/dev/null; then
        sudo usermod -aG lxd $USUARIO
        echo "Usuário $USUARIO adicionado ao grupo lxd."
    else
        echo "Atenção: Não foi encontrado o grupo 'lxc' nem 'lxd'. Verifique se LXC/LXD estão corretamente instalados."
    fi

# ============================================================================
# ETAPA 4: CONFIGURAÇÃO DE PERMISSÕES SUDO
# ============================================================================

# Permite sudo sem senha para o usuário (opcional, recomendado para manutenção de containers LXC)
        echo "$USUARIO ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USUARIO
        echo "Usuário $USUARIO criado e configurado com sucesso para administrar containers LXC!"
echo " "

# ============================================================================
# ETAPA 5: REINICIALIZAÇÃO DO CONTAINER
# ============================================================================
echo " "
read -p "Deseja reiniciar o servidor agora? (s/n): " REINICIAR
   if [ "$REINICIAR" == "s" ]; then
        echo "Reiniciando o servidor..."
        sudo reboot
   else
        echo "Reinicialização cancelada. Você pode reiniciar manualmente se for necessário."
   fi
   
# fim_script
