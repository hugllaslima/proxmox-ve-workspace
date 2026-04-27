#!/bin/bash

# ==============================================================================
# Script de Instalação do Antigravity
# ==============================================================================
#
# Este script automatiza a instalação do pacote 'antigravity' em sistemas
# operacionais baseados em Debian/Ubuntu e seus derivados. Ele adiciona o
# repositório oficial do Antigravity, importa a chave GPG de assinatura do
# repositório e, em seguida, instala o pacote usando o gerenciador 'apt'.
#
# Compatibilidade:
#   - Debian (todas as versões recentes)
#   - Ubuntu (todas as versões recentes)
#   - Linux Mint
#   - Outras distribuições baseadas em Debian/Ubuntu que utilizam 'apt'.
#
# Pré-requisitos:
#   - Conexão com a internet.
#   - Permissões de superusuário (sudo) para executar os comandos.
#   - Pacotes 'curl' e 'gpg' instalados (geralmente vêm por padrão).
#
# Uso:
#   1. Salve este conteúdo em um arquivo (ex: install_antigravity.sh).
#   2. Conceda permissões de execução: chmod +x install_antigravity.sh
#   3. Execute o script: ./install_antigravity.sh
#
# Autor: Inner AI
# Data: 18 de Dezembro de 2025
# Versão: 1.0
#
# ==============================================================================

echo "Iniciando a instalação do Antigravity..."
echo "Verificando permissões de superusuário..."

# Verifica se o script está sendo executado com sudo ou se o usuário pode usar sudo
if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "Erro: 'sudo' não encontrado. Por favor, execute este script como root ou instale 'sudo'."
        exit 1
    fi
    echo "Solicitando permissões de sudo para continuar..."
    # Testa se o sudo funciona sem exigir senha para o próximo comando, ou solicita
    sudo -v
    if [ $? -ne 0 ]; then
        echo "Erro: Não foi possível obter permissões de sudo. Verifique sua senha ou configurações."
        exit 1
    fi
fi

# --- Comando 1: Adicionar o repositório Antigravity e a chave GPG ---
echo ""
echo "Passo 1/3: Adicionando o repositório Antigravity e a chave GPG..."

# Cria o diretório para as chaves GPG, se não existir
sudo mkdir -p /etc/apt/keyrings

# Baixa a chave de assinatura do repositório e a adiciona ao keyring
if curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg; then
    echo "Chave GPG do repositório Antigravity adicionada com sucesso."
else
    echo "Erro: Falha ao baixar ou adicionar a chave GPG do repositório Antigravity."
    exit 1
fi

# Adiciona o repositório Antigravity à lista de fontes do APT
if echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null; then
    echo "Repositório Antigravity adicionado com sucesso."
else
    echo "Erro: Falha ao adicionar o repositório Antigravity."
    exit 1
fi

# --- Comando 2: Atualizar a lista de pacotes do APT ---
echo ""
echo "Passo 2/3: Atualizando a lista de pacotes do APT..."
if sudo apt update; then
    echo "Lista de pacotes do APT atualizada com sucesso."
else
    echo "Erro: Falha ao atualizar a lista de pacotes do APT. Verifique sua conexão com a internet ou as configurações do repositório."
    exit 1
fi

# --- Comando 3: Instalar o pacote Antigravity ---
echo ""
echo "Passo 3/3: Instalando o pacote 'antigravity'..."
if sudo apt install antigravity -y; then
    echo "Pacote 'antigravity' instalado com sucesso!"
else
    echo "Erro: Falha ao instalar o pacote 'antigravity'. Verifique se o pacote está disponível no repositório."
    exit 1
fi

echo ""
echo "Instalação do Antigravity concluída."
echo "Você pode verificar a instalação ou usar o 'antigravity' agora."

exit 0