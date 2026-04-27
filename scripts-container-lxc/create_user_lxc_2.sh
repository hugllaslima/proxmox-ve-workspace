#!/bin/bash

#==================================================================================================
# Script: create_user_lxc_2.sh
# Descrição: Criação e configuração de usuários em containers LXC (Versão 2)
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 2.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-container-lxc
#==================================================================================================

# ETAPAS DO SCRIPT:
# 1. Atualização e configuração do template
# 2. Instalação do sudo e openssh-client
# 3. Criação do novo usuário
# 4. Configuração de permissões sudo avançadas
# 5. Configuração SSH com chaves
# 6. Configurações de segurança
# 7. Reinicialização do container LXC
# Uso:
#   - sudo ./create_user_lxc_2.sh

# ============================================================================
# ETAPA 1: CONFIGURAÇÃO INICIAL DO SISTEMA
# ============================================================================

echo "Ajustando o timezone..."
timedatectl set-timezone America/Sao_Paulo
echo "Timezone configurado para: $(timedatectl show --property=Timezone --value)"
echo

# ============================================================================
# ETAPA 2: ATUALIZAÇÃO DO SISTEMA OPERACIONAL
# ============================================================================

read -p "Deseja atualizar o sistema operacional? (s/n): " ATUALIZAR
if [[ "$ATUALIZAR" =~ ^[sS]$ ]]; then
  echo "Atualizando o sistema operacional..."
  apt update && apt upgrade -y
  echo "Sistema atualizado!"
else
  echo "Atualização do sistema pulada."
fi
echo

# ============================================================================
# ETAPA 3: INSTALAÇÃO DO PACOTE SUDO
# ============================================================================

read -p "Deseja instalar o pacote 'sudo'? (s/n): " INSTALAR_SUDO
if [[ "$INSTALAR_SUDO" =~ ^[sS]$ ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Instalando 'sudo'..."
    apt update && apt install sudo -y
    echo "'sudo' instalado!"
  else
    echo "'sudo' já instalado!"
  fi
else
  echo "Instalação do 'sudo' pulada."
fi
echo

# ============================================================================
# ETAPA 4: INSTALAÇÃO DO OPENSSH-CLIENT
# ============================================================================

read -p "Deseja instalar o pacote 'openssh-client'? (s/n): " INSTALAR_OPENSSH
if [[ "$INSTALAR_OPENSSH" =~ ^[sS]$ ]]; then
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Instalando 'openssh-client'..."
    apt update && apt install openssh-client -y
    echo "'openssh-client' instalado!"
  else
    echo "'openssh-client' já instalado!"
  fi
else
  echo "Instalação do 'openssh-client' pulada."
fi
echo

# ============================================================================
# ETAPA 5: CRIAÇÃO E CONFIGURAÇÃO DO USUÁRIO
# ============================================================================

read -p "Digite o nome do usuário que deseja criar: " USUARIO
echo

if id "$USUARIO" &>/dev/null; then
  echo "Usuário '$USUARIO' já existe. Abortando criação."
else
  if command -v sudo >/dev/null 2>&1; then
    sudo adduser $USUARIO
    sudo usermod -aG sudo $USUARIO

    # Adiciona ao grupo lxc/lxd se existir
    if getent group lxc >/dev/null; then
      sudo usermod -aG lxc $USUARIO
      echo "Usuário $USUARIO adicionado ao grupo lxc."
    elif getent group lxd >/dev/null; then
      sudo usermod -aG lxd $USUARIO
      echo "Usuário $USUARIO adicionado ao grupo lxd."
    else
      echo "Atenção: Não foi encontrado o grupo 'lxc' nem 'lxd'."
    fi

# ============================================================================
# ETAPA 6: CONFIGURAÇÃO DE PERMISSÕES SUDO
# ============================================================================

    # Permite sudo sem senha para o usuário (opcional, seguro apenas em ambiente de LAB)
    echo "$USUARIO ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USUARIO
    echo "Usuário $USUARIO criado e configurado com sucesso!"
  else
    adduser $USUARIO
    echo "Usuário criado. Aviso: 'sudo' não está instalado, então configurações avançadas e grupos podem não ter sido aplicados!"
  fi
fi

# ============================================================================
# ETAPA 7: REINICIALIZAÇÃO DO SERVIDOR
# ============================================================================

echo
read -p "Deseja reiniciar o servidor agora? (s/n): " REINICIAR
if [[ "$REINICIAR" =~ ^[sS]$ ]]; then
  echo "Reiniciando o servidor..."
  if command -v sudo >/dev/null 2>&1; then
    sudo reboot
  else
    reboot
  fi
else
  echo "Reinicialização cancelada. Você pode reiniciar manualmente se necessário."
fi

# fim_script
