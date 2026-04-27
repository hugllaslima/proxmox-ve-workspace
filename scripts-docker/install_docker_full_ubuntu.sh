#!/bin/bash

#==================================================================================================
# Script: install_docker_full.sh
# Descrição: Instalação completa do Docker e Docker Compose
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace/tree/main/scripts-docker
#================================================================================================== 

# ETAPAS DO SCRIPT:
# 1. Atualização do sistema
# 2. Instalação de dependências
# 3. Adição da chave GPG do Docker
# 4. Adição do repositório Docker
# 5. Instalação do Docker
# 6. Configuração de permissões do usuário
# 7. Instalação do Docker Compose
# 8. Verificação da instalação

# ============================================================================
# ETAPA 1: ATUALIZAÇÃO DO SISTEMA
# ============================================================================
echo "Atualizando o sistema..."
    sudo apt update && sudo apt upgrade -y
echo " "

# ============================================================================
# ETAPA 2: INSTALAÇÃO DE DEPENDÊNCIAS
# ============================================================================
echo "Instalando dependências..."
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
echo " "

# ============================================================================
# ETAPA 3: ADIÇÃO DA CHAVE GPG DO DOCKER
# ============================================================================
echo "Adicionando a chave GPG do Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo " "

# ============================================================================
# ETAPA 4: ADIÇÃO DO REPOSITÓRIO DOCKER
# ============================================================================
echo "Adicionando o repositório do Docker..."
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
echo " "

# ============================================================================
# ETAPA 5: INSTALAÇÃO DO DOCKER
# ============================================================================
echo "Instalando o Docker..."
    sudo apt update
    sudo apt install docker-ce -y
echo " "

echo "Verificando a Versão do Docker..."
    docker --version
echo " "

echo "Habilitando a inicialização do Docker..."
    sudo systemctl enable docker
echo " "

# ============================================================================
# ETAPA 6: CONFIGURAÇÃO DE PERMISSÕES DO USUÁRIO
# ============================================================================
USER=$(whoami)
echo "Adicionando o usuário $USER ao grupo Docker..."
    sudo usermod -aG docker $USER
echo " "

# ============================================================================
# ETAPA 7: INSTALAÇÃO DO DOCKER COMPOSE
# ============================================================================
echo "Instalando o Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
echo " "

echo "Definindo permissões para o Docker Compose..."
    sudo chmod +x /usr/local/bin/docker-compose
echo " "

# ============================================================================
# ETAPA 8: VERIFICAÇÃO DA INSTALAÇÃO
# ============================================================================
echo "Verificando a versão do Docker Compose..."
    docker-compose --version
echo " "
echo "Instalação concluída! O sistema será reiniciado para aplicar as alterações."
echo " "
    sleep 5
    sudo reboot
#fim_script
