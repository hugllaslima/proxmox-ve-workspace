#!/bin/bash

#==============================================================================
# Script: install_docker_full_zorin.sh
# Descrição: Instalação completa do Docker e Docker Compose para Zorin OS
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Detecção da distribuição (Zorin OS e derivados do Ubuntu)
# 2. Limpeza completa de instalação anterior
# 3. Otimização do mirror (evita erros de sincronização)
# 4. Atualização do sistema
# 5. Instalação de dependências
# 6. Adição da chave GPG do Docker (método moderno)
# 7. Adição do repositório Docker
# 8. Instalação do Docker
# 9. Configuração de permissões do usuário
# 10. Teste rápido
# 11. Verificação da instalação
# 12. Limpeza final

# Ativa modo de erro (para o script se algum comando falhar)
set -e

# Detecta a distribuição base (Ubuntu para derivados)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    
    # Se for Zorin, Pop!_OS, Linux Mint, etc., usa Ubuntu
    case "$OS" in
        zorin|pop|linuxmint|elementary)
            OS="ubuntu"
            ;;
    esac
else
    echo "Não foi possível detectar a distribuição"
    exit 1
fi

echo "Sistema detectado: $OS"
echo " "

# ============================================================================
# ETAPA 1: LIMPEZA COMPLETA DE INSTALAÇÃO ANTERIOR
# ============================================================================
echo "Removendo configurações antigas do Docker (se existirem)..."

# Remove chaves antigas (tanto legadas quanto novas)
sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg 2>/dev/null || true
sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
sudo apt-key del 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 2>/dev/null || true

# Remove repositórios duplicados
sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
sudo rm -f /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu*.list 2>/dev/null || true

echo " "

# ============================================================================
# ETAPA 2: OTIMIZAÇÃO DO MIRROR (EVITA ERROS DE SINCRONIZAÇÃO)
# ============================================================================
echo "Otimizando configuração de mirrors..."

# Usa mirror global para evitar problemas de sincronização
if grep -q "br.archive.ubuntu.com" /etc/apt/sources.list 2>/dev/null; then
    echo "Ajustando para mirror global (mais estável)..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak-$(date +%Y%m%d-%H%M%S)
    sudo sed -i 's|br.archive.ubuntu.com|archive.ubuntu.com|g' /etc/apt/sources.list
fi

echo " "

# ============================================================================
# ETAPA 3: ATUALIZAÇÃO DO SISTEMA
# ============================================================================
echo "Atualizando o sistema..."
sudo apt clean
sudo apt update -o Acquire::Languages=none -o Acquire::GzipIndexes=true || {
    echo "⚠️  Erro ao atualizar. Limpando cache e tentando novamente..."
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt clean
    sudo apt update
}
sudo apt upgrade -y
echo " "

# ============================================================================
# ETAPA 4: INSTALAÇÃO DE DEPENDÊNCIAS
# ============================================================================
echo "Instalando dependências..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
echo " "

# ============================================================================
# ETAPA 5: ADIÇÃO DA CHAVE GPG DO DOCKER (MÉTODO MODERNO)
# ============================================================================
echo "Adicionando a chave GPG do Docker (método moderno)..."
sudo install -m 0755 -d /etc/apt/keyrings

# Força o uso do repositório Ubuntu
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "✓ Chave GPG instalada corretamente"
echo " "

# ============================================================================
# ETAPA 6: ADIÇÃO DO REPOSITÓRIO DOCKER
# ============================================================================
echo "Adicionando o repositório do Docker..."

# Pega a versão do Ubuntu base (para Zorin OS)
UBUNTU_CODENAME=$(grep UBUNTU_CODENAME /etc/os-release | cut -d= -f2)

# Cria repositório com signed-by (método correto, sem avisos)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "✓ Repositório Docker configurado"
echo " "

# ============================================================================
# ETAPA 7: INSTALAÇÃO DO DOCKER
# ============================================================================
echo "Instalando o Docker..."
sudo apt update -qq
sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo " "

echo "Verificando a Versão do Docker..."
docker --version
echo " "

echo "Habilitando a inicialização do Docker..."
sudo systemctl enable docker
sudo systemctl start docker
echo " "

# ============================================================================
# ETAPA 8: CONFIGURAÇÃO DE PERMISSÕES DO USUÁRIO
# ============================================================================
USER=$(whoami)
echo "Adicionando o usuário $USER ao grupo Docker..."
sudo usermod -aG docker $USER
echo " "

# ============================================================================
# ETAPA 9: TESTE RÁPIDO
# ============================================================================
echo "Testando Docker com sudo..."
sudo docker run --rm hello-world
echo " "

# ============================================================================
# ETAPA 10: VERIFICAÇÃO DA INSTALAÇÃO
# ============================================================================
echo "Verificando a instalação do Docker Compose (plugin)..."
docker compose version
echo " "

# ============================================================================
# ETAPA 11: LIMPEZA FINAL
# ============================================================================
echo "Limpando cache do APT..."
sudo apt clean
sudo apt autoclean
echo " "

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Instalação concluída com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " "
echo "📋 Resumo da instalação:"
echo "   - Docker Engine: $(docker --version)"
echo "   - Docker Compose: $(docker compose version)"
echo "   - Mirror: archive.ubuntu.com (global)"
echo "   - Método de chave: Moderno (keyrings)"
echo " "
echo "⚠️  IMPORTANTE: Você precisa fazer logout e login novamente"
echo "    para que as permissões do grupo Docker sejam aplicadas."
echo "    Após isso, você poderá usar Docker sem sudo."
echo " "

read -p "Deseja fazer logout agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Fazendo logout em 3 segundos..."
    sleep 3
    gnome-session-quit --logout --no-prompt 2>/dev/null || \
    pkill -KILL -u $USER
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Lembre-se de fazer logout/login antes de usar Docker sem sudo!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

#fim_script
