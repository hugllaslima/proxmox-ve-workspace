#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script: install_nfs_server.sh
#
# Descrição:
#   Este script automatiza a instalação e configuração de um servidor NFS
#   (Network File System) em um sistema baseado em Debian (como Ubuntu). O NFS
#   é usado para compartilhar diretórios através de uma rede e é comumente
#   utilizado em clusters Kubernetes para provisionamento de armazenamento
#   dinâmico (Persistent Volumes).
#
# Funcionalidades:
#   - Instala os pacotes necessários para o servidor NFS.
#   - Cria um diretório de compartilhamento padrão (/mnt/k3s-share-nfs/).
#   - Configura as permissões do diretório de compartilhamento.
#   - Adiciona uma entrada ao arquivo /etc/exports para permitir o acesso de
#     qualquer cliente na rede (*).
#   - Reinicia o serviço do servidor NFS para aplicar as alterações.
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
#   21/11/2025
#
# Pré-requisitos:
#   - Sistema operacional baseado em Debian (Ubuntu 22.04 ou 24.04 LTS recomendado).
#   - Acesso root ou um usuário com privilégios sudo.
#   - Conectividade de rede.
#
# Como usar:
#   1. Certifique-se de que os pré-requisitos foram atendidos.
#   2. Dê permissão de execução ao script:
#      chmod +x install_nfs_server.sh
#   3. Execute o script:
#      sudo ./install_nfs_server.sh
#   4. O script executará todas as etapas automaticamente.
#
# Onde Utilizar:
#   - Diretamente na VM que será configurada como Servidor NFS.
#
# -----------------------------------------------------------------------------

# As variáveis de configuração serão solicitadas durante a execução do script.

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

# Verificação de root
if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, execute este script como root (sudo)."
fi

echo -e "\e[34m--- Instalação do Servidor NFS ---\e[0m"

# 1. Atualizar repositórios
echo "Atualizando repositórios..."
apt update -y
check_command "Falha ao atualizar repositórios."

# 2. Instalar Servidor NFS
echo "Instalando pacote nfs-kernel-server..."
apt install nfs-kernel-server -y
check_command "Falha ao instalar nfs-kernel-server."

# 3. Criar diretório de compartilhamento
# Solicita o caminho ao usuário, com padrão
get_user_input "Digite o caminho do diretório para compartilhar" "/mnt/k3s-share-nfs/" "NFS_SHARE_PATH" "true"

echo "Criando diretório: $NFS_SHARE_PATH"
mkdir -p "$NFS_SHARE_PATH"
# Define permissões: nobody:nogroup é padrão para acesso genérico, 777 permite escrita por todos (útil para testes/pvcs)
chown nobody:nogroup "$NFS_SHARE_PATH"
chmod 777 "$NFS_SHARE_PATH"
check_command "Falha ao criar/configurar diretório."

# 4. Configurar Exports
echo "Configurando /etc/exports..."
# Faz backup do original
cp /etc/exports /etc/exports.bak

# Verifica se a entrada já existe para evitar duplicatas
if grep -q "$NFS_SHARE_PATH" /etc/exports; then
    echo "Aviso: Entrada para $NFS_SHARE_PATH já existe em /etc/exports."
else
    # Adiciona a linha.
    # rw: leitura e escrita
    # sync: confirmação síncrona de escrita (segurança de dados)
    # no_subtree_check: melhora performance
    # no_root_squash: permite que o root do cliente aja como root no servidor (necessário para alguns provisioners K8s)
    echo "$NFS_SHARE_PATH *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    echo "Entrada adicionada: $NFS_SHARE_PATH *(rw,sync,no_subtree_check,no_root_squash)"
fi

# 5. Aplicar e Reiniciar
echo "Exportando compartilhamentos..."
exportfs -a
systemctl restart nfs-kernel-server
check_command "Falha ao reiniciar o serviço NFS."

# 6. Status Final
echo "Verificando status do serviço..."
systemctl status nfs-kernel-server --no-pager | head -n 10

echo -e "\n\e[32m--- Instalação do Servidor NFS concluída ---\e[0m"
echo "IP do Servidor: $(hostname -I | awk '{print $1}')"
echo "Caminho Exportado: $NFS_SHARE_PATH"
