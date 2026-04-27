#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALAÇÃO COMPLETA DO DOCKER E DOCKER COMPOSE
# ==============================================================================
#
# DESCRIÇÃO:
# Este script automatiza a instalação do Docker Engine e do Docker Compose V2
# em sistemas baseados em Ubuntu. Ele segue as melhores práticas recomendadas
# pela documentação oficial do Docker.
#
# COMPATIBILIDADE:
# - Ubuntu Server 20.04 LTS (Focal Fossa)
# - Ubuntu Server 22.04 LTS (Jammy Jellyfish)
# - Ubuntu Server 24.04 LTS (Noble Numbat)
#
# O QUE O SCRIPT FAZ:
# 1.  Atualiza os pacotes do sistema.
# 2.  Instala as dependências necessárias para adicionar repositórios via HTTPS.
# 3.  Adiciona a chave GPG oficial do Docker de forma segura.
# 4.  Configura o repositório oficial do Docker.
# 5.  Instala o Docker Engine, Docker CLI, containerd e o plugin Docker Compose V2.
# 6.  Adiciona o usuário atual ao grupo 'docker' para permitir a execução de
#     comandos Docker sem 'sudo'.
# 7.  Habilita o serviço do Docker para iniciar com o sistema.
# 8.  Verifica as versões instaladas e exibe uma mensagem de sucesso.
#
# PRÉ-REQUISITOS:
# - Acesso de superusuário (sudo).
# - Conexão com a internet.
#
# COMO USAR:
# 1. Dê permissão de execução ao script: chmod +x install_docker_full_ubuntu_server.sh
# 2. Execute o script com sudo: sudo ./install_docker_full_ubuntu_server.sh
# 3. Após a conclusão, faça logout e login novamente ou reinicie o sistema
#    para que as alterações no grupo de usuários tenham efeito.
#
# ==============================================================================

# --- Início do Script ---

echo "======================================================"
echo "  Iniciando a Instalação do Docker e Docker Compose   "
echo "======================================================"

# 1. ATUALIZAR O SISTEMA
echo "\n[PASSO 1/6] Atualizando o sistema..."
    sudo apt-get update && sudo apt-get upgrade -y
    
# 2. INSTALAR DEPENDÊNCIAS
echo "\n[PASSO 2/6] Instalando dependências necessárias..."
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# 3. ADICIONAR A CHAVE GPG DO DOCKER (MÉTODO MODERNO)
echo "\n[PASSO 3/6] Adicionando a chave GPG oficial do Docker..."
    # Cria o diretório para armazenar as chaves
        sudo install -m 0755 -d /etc/apt/keyrings
    # Baixa e armazena a chave GPG do Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    # Ajusta as permissões da chave
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. ADICIONAR O REPOSITÓRIO DO DOCKER
echo "\n[PASSO 4/6] Adicionando o repositório do Docker..."
    # Adiciona o repositório do Docker ao sources.list.d
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    # Atualiza o índice de pacotes
        sudo apt-get update

# 5. INSTALAR O DOCKER ENGINE E DOCKER COMPOSE
echo "\n[PASSO 5/6] Instalando Docker Engine, CLI, Containerd e Docker Compose..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. CONFIGURAÇÕES PÓS-INSTALAÇÃO
echo "\n[PASSO 6/6] Realizando configurações pós-instalação..."

    # Adicionar usuário atual ao grupo docker
        # Obtém o nome do usuário atual
        CURRENT_USER=$(whoami)
        echo "Adicionando o usuário '$CURRENT_USER' ao grupo 'docker'..."
        sudo usermod -aG docker "$CURRENT_USER"

        # Habilitar o serviço do Docker
        echo "Habilitando o serviço do Docker para iniciar com o sistema..."
        sudo systemctl enable docker
        sudo systemctl start docker

# 7. VERIFICAÇÕES FINAIS
echo "\n[PASSO 7/6] Verificando as versões instaladas..."
echo "========================================================"
echo "           Verificando as versões instaladas            "
echo "========================================================"

if command -v docker &> /dev/null; then
    echo "Docker Engine:"
    docker --version
else
    echo "ERRO: Docker não parece ter sido instalado corretamente."
fi

if docker compose version &> /dev/null; then
    echo "\n[PASSO 7/6] Docker Compose (plugin V2):"
    docker compose version
else
    echo "ERRO: Docker Compose não parece ter sido instalado corretamente."
fi

echo "\n========================================================"
echo "🎉 Instalação concluída com sucesso!"
echo ""
echo "IMPORTANTE: Para usar o Docker sem 'sudo', você precisa fazer logout e login novamente ou reiniciar o sistema."
echo "=========================================================="
