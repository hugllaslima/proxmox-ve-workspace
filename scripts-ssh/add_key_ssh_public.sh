#!/bin/bash

#==============================================================================
# Script: add_key_ssh_public.sh
# Descrição: Adiciona uma chave pública SSH ao authorized_keys de um usuário
#            com validação, confirmação interativa e comentário identificando
#            o proprietário, data e hora da adição, e o usuário que adicionou.
#            Melhoria: Lida com chaves duplicadas, oferecendo opções para
#            substituir, excluir ou manter a chave existente.
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.4 (Adição de tratamento de duplicidade de chaves)
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================
#
# ETAPAS DO SCRIPT:
# 1. Selecionar e confirmar usuário alvo (com validação de existência)
# 2. Informar o proprietário da chave (comentário)
# 3. Preparar diretório .ssh e authorized_keys (permissões e ownership)
# 4. Colar e validar chave pública
# 5. Verificar duplicidade e interagir com o usuário
# 6. Adicionar comentário e chave
#
# Uso:
#   chmod +x add_key_ssh_public.sh
#   sudo ./add_key_ssh_public.sh
#
# Pré-requisitos:
# - Sistemas operacionais baseados em Debian & Ubuntu
# - Acesso sudo/root para escrever no home de outros usuários
# - openssh-client instalado (para validar formato de chave)
#
# Boas práticas:
# - .ssh deve ter permissão 700 e owned pelo usuário alvo
# - authorized_keys deve ter permissão 600 e owned pelo usuário alvo
# - Para adicionar chave a outro usuário, execute com sudo
#

# Função para exibir uma mensagem de erro e sair
error_exit() {
    echo "Erro: $1" >&2
    exit 1
}

# Determine o usuário real que invocou o script (considerando sudo)
# Se SUDO_USER estiver definido, significa que o script foi executado com sudo.
# Caso contrário, usa o usuário atual ($USER).
if [ -n "$SUDO_USER" ]; then
    EXECUTING_USER="$SUDO_USER"
else
    EXECUTING_USER="$USER"
fi

echo " "
echo "---------------------------------------------"
echo "--- Adicionar Chave Pública SSH (interativo) ---"
echo "---------------------------------------------"

# ============================================================================
# ETAPA 1: Selecionar e confirmar usuário alvo
# ============================================================================
while true; do
    read -p "Para qual usuário neste servidor a chave pública será adicionada? (Deixe em branco para o usuário atual: $USER): " TARGET_USER_INPUT
    TARGET_USER=${TARGET_USER_INPUT:-$USER} # Se vazio, usa o usuário atual

    echo "Você informou o usuário: '$TARGET_USER'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_TARGET_USER
    if [[ "$CONFIRM_TARGET_USER" =~ ^[Ss]$ ]]; then
        # Verificar se o usuário existe no sistema
        if ! id -u "$TARGET_USER" &>/dev/null; then
            echo "Erro: Usuário '$TARGET_USER' não existe no sistema. Por favor, tente novamente."
            continue # Volta para o início do loop
        fi

        # Obter o diretório home do usuário alvo de forma robusta
        HOME_DIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
        if [ -z "$HOME_DIR" ]; then
            echo "Aviso: Não foi possível determinar o diretório home para o usuário '$TARGET_USER'. Por favor, tente novamente."
            continue # Volta para o início do loop
        fi

        break # Sai do loop se confirmado e usuário válido
    else
        echo "Por favor, insira o usuário novamente."
    fi
done

# ============================================================================
# ETAPA 2: Informar o proprietário da chave (comentário)
# ============================================================================
while true; do
    echo ""
    read -p "Qual o nome da pessoa ou sistema que é o DONO desta chave? (Ex: 'João da Silva (Windows 10)', 'Servidor de Backup'): " KEY_OWNER_NAME
    if [ -z "$KEY_OWNER_NAME" ]; then
        echo "Erro: O nome do proprietário da chave é obrigatório para o comentário. Por favor, tente novamente."
        continue # Volta para o início do loop
    fi

    echo "Você informou o nome: '$KEY_OWNER_NAME'"
    read -p "Esta informação está correta? (s/N): " CONFIRM_KEY_OWNER
    if [[ "$CONFIRM_KEY_OWNER" =~ ^[Ss]$ ]]; then
        break # Sai do loop se confirmado
    else
        echo "Por favor, insira o nome novamente."
    fi
done

SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"
CURRENT_DATETIME=$(date +'%Y-%m-%d %H:%M:%S') # Captura a data e hora atual
# A linha de comentário foi atualizada para incluir o usuário que executou o script
COMMENT_LINE="# Key for: $KEY_OWNER_NAME (added by $EXECUTING_USER on $CURRENT_DATETIME)"

run_command() {
    if [ "$TARGET_USER" != "$USER" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

set_authorized_keys_permissions() {
    if run_command test -L "$AUTH_KEYS_FILE"; then
        echo "Aviso: $AUTH_KEYS_FILE é um link simbólico. As etapas de chown e chmod serão ignoradas."
        return 0
    fi

    run_command chown "$TARGET_USER:$TARGET_USER" "$AUTH_KEYS_FILE" || error_exit "Falha ao definir proprietário para $AUTH_KEYS_FILE."
    run_command chmod 0600 "$AUTH_KEYS_FILE" || error_exit "Falha ao definir permissões para $AUTH_KEYS_FILE."
}

echo "A chave será adicionada para o usuário: $TARGET_USER"
echo "Comentário a ser adicionado: $COMMENT_LINE"
echo "Caminho do arquivo authorized_keys: $AUTH_KEYS_FILE"

# ============================================================================
# ETAPA 3: Preparar diretório .ssh e arquivo authorized_keys
# ============================================================================
# Lidar com permissões e ownership cuidadosamente
if [ "$TARGET_USER" != "$USER" ]; then
    # Se o usuário alvo for diferente, provavelmente precisamos de sudo
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Para adicionar chaves para outro usuário ('$TARGET_USER'), você precisa executar o script com 'sudo'."
    fi

    # Criar diretório .ssh e definir permissões/propriedade
    if [ ! -d "$SSH_DIR" ]; then
        echo "Criando diretório $SSH_DIR..."
        sudo mkdir -p "$SSH_DIR" || error_exit "Falha ao criar diretório $SSH_DIR."
        sudo chown "$TARGET_USER:$TARGET_USER" "$SSH_DIR" || error_exit "Falha ao definir proprietário para $SSH_DIR."
        sudo chmod 0700 "$SSH_DIR" || error_exit "Falha ao definir permissões para $SSH_DIR."
    else
        # Garantir permissões e propriedade corretas se já existir
        sudo chown "$TARGET_USER:$TARGET_USER" "$SSH_DIR" || error_exit "Falha ao definir proprietário para $SSH_DIR."
        sudo chmod 0700 "$SSH_DIR" || error_exit "Falha ao definir permissões para $SSH_DIR."
    fi

    # Criar arquivo authorized_keys e definir permissões/propriedade
    if [ ! -f "$AUTH_KEYS_FILE" ]; then
        echo "Criando arquivo $AUTH_KEYS_FILE..."
        sudo touch "$AUTH_KEYS_FILE" || error_exit "Falha ao criar arquivo $AUTH_KEYS_FILE."
        set_authorized_keys_permissions
    else
        # Garantir permissões e propriedade corretas se já existir
        set_authorized_keys_permissions
    fi
else
    # Se o usuário alvo for o usuário atual, não é necessário sudo para a configuração inicial
    if [ ! -d "$SSH_DIR" ]; then
        echo "Criando diretório $SSH_DIR..."
        mkdir -p "$SSH_DIR" || error_exit "Falha ao criar diretório $SSH_DIR."
        chmod 0700 "$SSH_DIR" || error_exit "Falha ao definir permissões para $SSH_DIR."
    fi
    if [ ! -f "$AUTH_KEYS_FILE" ]; then
        echo "Criando arquivo $AUTH_KEYS_FILE..."
        touch "$AUTH_KEYS_FILE" || error_exit "Falha ao criar arquivo $AUTH_KEYS_FILE."
        set_authorized_keys_permissions
    else
        set_authorized_keys_permissions
    fi
fi


# ============================================================================
# ETAPA 4: Colar e validar chave pública
# ============================================================================
while true; do
    echo ""
    echo "Por favor, cole a chave pública SSH. Após colar, pressione Enter e, em seguida, pressione Enter novamente em uma linha vazia para finalizar."
    echo "Exemplo: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD..."
    KEY_CONTENT=""
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        KEY_CONTENT+="$line"$'\n'
    done
    # Remover a última quebra de linha se houver, para garantir correspondência exata
    KEY_CONTENT=$(echo -e "$KEY_CONTENT" | sed -e '$!b' -e '/^\s*$/d')

    if [ -z "$KEY_CONTENT" ]; then
        echo "Erro: Nenhuma chave pública foi fornecida. Por favor, tente novamente."
        continue # Volta para o início do loop
    fi

    # Validação básica do formato da chave SSH
    if ! echo "$KEY_CONTENT" | grep -Eq "^(ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519|sk-ecdsa-sha2-nistp256@openssh.com|sk-ssh-ed25519@openssh.com) [A-Za-z0-9+/]+={0,2}( .*)?$"; then
        echo "Aviso: A chave pública fornecida não parece estar em um formato SSH válido."
        read -p "Deseja continuar mesmo assim? (s/N): " CONFIRM_INVALID
        if [[ ! "$CONFIRM_INVALID" =~ ^[Ss]$ ]]; then
            echo "Por favor, cole a chave pública novamente."
            continue # Volta para o início do loop
        fi
    fi

    # Exibir uma parte da chave para confirmação
    # Garante que KEY_CONTENT é uma única linha para o preview
    SINGLE_LINE_KEY=$(echo "$KEY_CONTENT" | tr -d '\n')
    KEY_PREVIEW=$(echo "$SINGLE_LINE_KEY" | head -n 1 | cut -c 1-70)...$(echo "$SINGLE_LINE_KEY" | tail -n 1 | cut -c $(( $(echo "$SINGLE_LINE_KEY" | tail -n 1 | wc -c) - 50 ))- )
    echo ""
    echo "Você colou a seguinte chave (prévia):"
    echo "$KEY_PREVIEW"
    read -p "A chave pública está correta? (s/N): " CONFIRM_KEY_CONTENT
    if [[ "$CONFIRM_KEY_CONTENT" =~ ^[Ss]$ ]]; then
        break # Sai do loop se confirmado
    else
        echo "Por favor, cole a chave pública novamente."
    fi
done

# ============================================================================
# ETAPA 5: Verificar duplicidade e interagir com o usuário
# ============================================================================
echo "Verificando duplicidade da chave pública no arquivo $AUTH_KEYS_FILE..."

# Tenta encontrar a chave e seu número de linha.
# Usamos `grep -nF` para correspondência de string fixa e para obter o número da linha.
# A saída é capturada para que possamos extrair o número da linha.
KEY_MATCH_OUTPUT=$(run_command grep -nF "$KEY_CONTENT" "$AUTH_KEYS_FILE")

if [ -n "$KEY_MATCH_OUTPUT" ]; then
    echo "Aviso: A chave pública fornecida JÁ EXISTE no arquivo $AUTH_KEYS_FILE."

    # Extrai o número da primeira linha onde a chave foi encontrada.
    # Assumimos que a chave é uma única linha, como é o padrão para chaves SSH públicas.
    FIRST_KEY_LINE_NUM=$(echo "$KEY_MATCH_OUTPUT" | head -n 1 | cut -d: -f1)
    
    # O script adiciona um comentário na linha imediatamente anterior à chave.
    # Se a chave estiver na linha N, o comentário estará na linha N-1.
    FIRST_COMMENT_LINE_NUM=$((FIRST_KEY_LINE_NUM - 1))

    while true; do
        echo ""
        echo "O que você gostaria de fazer com a chave duplicada?"
        echo "  1) Substituir a chave existente por esta nova (o comentário também será atualizado)."
        echo "  2) Excluir a chave existente (e seu comentário, se houver)."
        echo "  3) Manter a chave existente (e não adicionar esta nova)."
        read -p "Escolha uma opção (1, 2 ou 3): " DUPLICATE_ACTION

        case "$DUPLICATE_ACTION" in
            1)
                echo "Opção 'Substituir' selecionada."
                echo "Removendo a chave existente (linha $FIRST_KEY_LINE_NUM) e seu comentário (linha $FIRST_COMMENT_LINE_NUM, se aplicável)..."
                
                # Para remover as linhas corretamente com sed, é mais seguro deletar a linha com maior número primeiro.
                # Isso evita que o número da linha do comentário seja alterado após a exclusão da chave.
                # Se o comentário existir e for válido (linha >= 1), deletamos ambos.
                if [ "$FIRST_COMMENT_LINE_NUM" -ge 1 ]; then
                    run_command sed -i "${FIRST_KEY_LINE_NUM}d; ${FIRST_COMMENT_LINE_NUM}d" "$AUTH_KEYS_FILE" || error_exit "Falha ao remover a chave existente e seu comentário."
                else
                    # Se a chave estiver na primeira linha do arquivo ou não houver comentário antes dela, remove apenas a chave.
                    run_command sed -i "${FIRST_KEY_LINE_NUM}d" "$AUTH_KEYS_FILE" || error_exit "Falha ao remover a chave existente."
                fi
                echo "Chave existente removida. Prosseguindo para adicionar a nova chave."
                break # Sai do loop de ação de duplicidade e continua para ETAPA 6
                ;;
            2)
                echo "Opção 'Excluir' selecionada."
                echo "Removendo a chave existente (linha $FIRST_KEY_LINE_NUM) e seu comentário (linha $FIRST_COMMENT_LINE_NUM, se aplicável)..."
                
                if [ "$FIRST_COMMENT_LINE_NUM" -ge 1 ]; then
                    run_command sed -i "${FIRST_KEY_LINE_NUM}d; ${FIRST_COMMENT_LINE_NUM}d" "$AUTH_KEYS_FILE" || error_exit "Falha ao remover a chave existente e seu comentário."
                else
                    run_command sed -i "${FIRST_KEY_LINE_NUM}d" "$AUTH_KEYS_FILE" || error_exit "Falha ao remover a chave existente."
                fi
                echo "Chave existente excluída com sucesso para o usuário '$TARGET_USER'."
                exit 0 # Sai do script após a exclusão
                ;;
            3)
                echo "Opção 'Manter' selecionada. Nenhuma alteração será feita."
                exit 0 # Sai do script sem fazer alterações
                ;;
            *)
                echo "Opção inválida. Por favor, escolha 1, 2 ou 3."
                ;;
        esac
    done
fi

# ============================================================================
# ETAPA 6: Adicionar comentário e chave ao authorized_keys
# ============================================================================
echo "Adicionando o comentário e a chave pública ao arquivo $AUTH_KEYS_FILE..."

# Prepara o conteúdo completo (comentário + chave) para ser escrito
CONTENT_TO_WRITE="$COMMENT_LINE"$'\n'"$KEY_CONTENT"

# Usa a função run_command para lidar com sudo ou não
echo "$CONTENT_TO_WRITE" | run_command tee -a "$AUTH_KEYS_FILE" > /dev/null || error_exit "Falha ao adicionar a chave pública."
set_authorized_keys_permissions

echo "Chave pública adicionada com sucesso para o usuário '$TARGET_USER'!"
echo ""
echo "--- Próximo Passo: Testar o Acesso SSH ---"
echo "Por favor, abra uma nova sessão de terminal e tente acessar o servidor via SSH usando a chave que você acabou de adicionar."
echo "Exemplo: ssh $TARGET_USER@seu_servidor_ip"
read -p "Pressione Enter após testar o acesso SSH para finalizar o script."

echo "Script concluído. Verifique se o acesso SSH está funcionando corretamente."
