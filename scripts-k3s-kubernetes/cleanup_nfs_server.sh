#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: cleanup_nfs_server.sh
#
# Descrição:
#   Este script automatiza a remoção e limpeza completa de um servidor NFS
#   (Network File System) que foi instalado pelo script "install_nfs_server.sh".
#   Ele reverte todas as configurações, desinstala os pacotes e remove os
#   diretórios criados.
#
# Funcionalidades:
#   - Para e desabilita o serviço do servidor NFS.
#   - Remove a entrada de compartilhamento do arquivo /etc/exports.
#   - Remove o diretório de compartilhamento criado.
#   - Desinstala os pacotes do servidor NFS e suas dependências não utilizadas.
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
#   28/11/2025
#
# Pré-requisitos:
#   - Acesso root ou um usuário com privilégios sudo.
#
# Como usar:
#   1. Dê permissão de execução ao script:
#      chmod +x cleanup_nfs_server.sh
#   2. Execute o script:
#      sudo ./cleanup_nfs_server.sh
#   3. O script solicitará o caminho do diretório compartilhado para garantir
#      que a limpeza seja feita no local correto.
#
# Onde Utilizar:
#   - Diretamente na VM ou servidor que atua como servidor NFS.
#
# -----------------------------------------------------------------------------

# --- Variáveis de Configuração ---
NFS_SHARE_PATH="/mnt/k3s-share-nfs/"

# --- Funções Auxiliares ---

# Função para exibir mensagens de erro e sair
function error_exit {
    echo "ERRO: $1" >&2
    exit 1
}

# Função para verificar se um comando foi bem-sucedido
function check_command {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# Função para coletar entrada do usuário
function get_user_input {
    local prompt_message="$1"
    local default_value="$2"
    local var_name="$3"
    local is_path_check="$4" # Novo parâmetro para indicar verificação de caminho

    if [ -n "$default_value" ]; then
        prompt_message="$prompt_message (Padrão: $default_value)"
    fi

    while true; do
        read -p "$prompt_message: " input_value
        local final_value=""

        if [ -z "$input_value" ] && [ -n "$default_value" ]; then
            final_value="$default_value"
        elif [ -n "$input_value" ]; then
            final_value="$input_value"
        else
            echo "Entrada não pode ser vazia. Por favor, tente novamente."
            continue
        fi

        # Se for uma verificação de caminho, valide o prefixo
        if [ "$is_path_check" = "true" ]; then
            if [[ "$final_value" != /mnt/* ]]; then
                echo "ERRO: O caminho do compartilhamento deve estar dentro de /mnt/ (ex: /mnt/meu-share)."
                continue # Volta ao início do loop
            fi
        fi

        eval "$var_name=\"$final_value\""
        break
    done
}

# --- Início do Script ---
echo " "
echo "--- Limpeza do Servidor NFS ---"
echo " "

# Verifica se é root
if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, execute este script como root (sudo)."
fi

# Solicita o caminho para confirmação
get_user_input "Digite o caminho do diretório compartilhado para REMOVER" "$NFS_SHARE_PATH" "CONFIRMED_PATH" "true"

echo " "
echo "ATENÇÃO: Isso irá DELETAR PERMANENTEMENTE o diretório '$CONFIRMED_PATH' e todos os dados nele."
echo "Também irá desinstalar o servidor NFS."
read -p "Tem certeza que deseja continuar? (s/n): " confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo " "

# 1. Parar serviços
echo "Parando serviços NFS..."
systemctl stop nfs-kernel-server
systemctl disable nfs-kernel-server

# 2. Limpar /etc/exports
echo "Removendo configuração do /etc/exports..."
# Faz backup antes
cp /etc/exports /etc/exports.bak
# Remove a linha que contém o caminho
sed -i "\|^$CONFIRMED_PATH|d" /etc/exports
# Aplica alterações (embora o serviço esteja parado, é boa prática)
exportfs -ra

# 3. Remover diretório
if [ -d "$CONFIRMED_PATH" ]; then
    echo "Removendo diretório de dados '$CONFIRMED_PATH'..."
    rm -rf "$CONFIRMED_PATH"
else
    echo "Diretório '$CONFIRMED_PATH' não encontrado, pulando remoção."
fi

# 4. Desinstalar pacotes
echo "Desinstalando servidor NFS..."
apt-get remove --purge -y nfs-kernel-server
apt-get autoremove -y

echo " "
echo "--- Limpeza Concluída com Sucesso ---"
