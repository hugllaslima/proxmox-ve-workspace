#!/bin/bash

# ==============================================================================
# Script Gerenciador do Antigravity
# ==============================================================================
#
# Este script automatiza a instalação, atualização e desinstalação do pacote 
# 'antigravity' em sistemas baseados em Debian/Ubuntu.
#
# Uso:
#   1. Salve este conteúdo em um arquivo (ex: manage_antigravity.sh).
#   2. Conceda permissões de execução: chmod +x manage_antigravity.sh
#   3. Execute o script: ./manage_antigravity.sh
#
# ==============================================================================

# --- Verificação de Permissões ---
verificar_permissoes() {
    echo "Verificando permissões de superusuário..."
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo &> /dev/null; then
            echo "Erro: 'sudo' não encontrado. Execute este script como root ou instale 'sudo'."
            exit 1
        fi
        echo "Solicitando permissões de sudo para continuar..."
        sudo -v
        if [ $? -ne 0 ]; then
            echo "Erro: Não foi possível obter permissões de sudo. Verifique sua senha."
            exit 1
        fi
    fi
}

# --- Função de Instalação ---
instalar() {
    echo ""
    echo "=== Iniciando Instalação ==="
    echo "Passo 1/3: Adicionando o repositório Antigravity e a chave GPG..."
    
    sudo mkdir -p /etc/apt/keyrings

    if curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg; then
        echo "[OK] Chave GPG adicionada."
    else
        echo "[ERRO] Falha ao baixar ou adicionar a chave GPG."
        exit 1
    fi

    if echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null; then
        echo "[OK] Repositório adicionado."
    else
        echo "[ERRO] Falha ao adicionar o repositório."
        exit 1
    fi

    echo ""
    echo "Passo 2/3: Atualizando a lista de pacotes do APT..."
    if sudo apt update; then
        echo "[OK] Lista de pacotes atualizada."
    else
        echo "[ERRO] Falha ao atualizar a lista de pacotes."
        exit 1
    fi

    echo ""
    echo "Passo 3/3: Instalando o pacote 'antigravity'..."
    if sudo apt install antigravity -y; then
        echo "[OK] Pacote 'antigravity' instalado com sucesso!"
    else
        echo "[ERRO] Falha ao instalar o pacote 'antigravity'."
        exit 1
    fi
}

# --- Função de Atualização ---
atualizar() {
    echo ""
    echo "=== Iniciando Atualização ==="
    echo "Passo 1/2: Atualizando a lista de pacotes..."
    if sudo apt update; then
        echo "[OK] Lista atualizada."
    else
        echo "[ERRO] Falha ao atualizar a lista de pacotes."
        exit 1
    fi

    echo ""
    echo "Passo 2/2: Atualizando o pacote 'antigravity'..."
    # A flag --only-upgrade garante que ele só atualize se já estiver instalado
    if sudo apt install --only-upgrade antigravity -y; then
        echo "[OK] 'antigravity' atualizado com sucesso (se houvesse versão nova)!"
    else
        echo "[ERRO] Falha ao atualizar o pacote. Verifique se ele já está instalado."
        exit 1
    fi
}

# --- Função de Desinstalação ---
desinstalar() {
    echo ""
    echo "=== Iniciando Desinstalação ==="
    echo "Passo 1/2: Removendo o pacote 'antigravity'..."
    if sudo apt remove --purge antigravity -y; then
        echo "[OK] Pacote removido."
    else
        echo "[ERRO] Falha ao remover o pacote."
        exit 1
    fi

    echo ""
    echo "Passo 2/2: Removendo repositório e chaves GPG..."
    sudo rm -f /etc/apt/sources.list.d/antigravity.list
    sudo rm -f /etc/apt/keyrings/antigravity-repo-key.gpg
    
    # Atualiza o apt para limpar referências ao repositório antigo
    sudo apt update > /dev/null 2>&1
    echo "[OK] Repositório e chaves removidos com sucesso."
}

# --- Menu Principal ---
exibir_menu() {
    clear
    echo "==============================================="
    echo "     Gerenciador do Pacote Antigravity         "
    echo "==============================================="
    echo "O que você deseja fazer?"
    echo ""
    echo "  1) Instalar o Antigravity"
    echo "  2) Atualizar o Antigravity"
    echo "  3) Desinstalar o Antigravity"
    echo "  4) Sair"
    echo ""
    echo "==============================================="
    read -p "Digite o número da opção desejada [1-4]: " opcao

    case $opcao in
        1)
            verificar_permissoes
            instalar
            ;;
        2)
            verificar_permissoes
            atualizar
            ;;
        3)
            verificar_permissoes
            desinstalar
            ;;
        4)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida! Por favor, execute o script novamente e escolha de 1 a 4."
            exit 1
            ;;
    esac
}

# Inicia o script exibindo o menu
exibir_menu

echo ""
echo "Operação finalizada."
exit 0