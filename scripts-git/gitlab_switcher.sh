#!/bin/bash

# ==============================================================================
# SCRIPT PARA ALTERNAR USUÁRIOS GIT/GITLAB EM UM REPOSITÓRIO LOCAL (GENÉRICO)
# ==============================================================================
# Este script permite que você configure e alterne facilmente entre múltiplas
# contas Git/GitLab (pessoal, trabalho, etc.) em seus repositórios locais.
# Ele gerencia as credenciais de commit (user.name, user.email) e a URL do
# remote 'origin' para usar a chave SSH correta para autenticação.
#
# As informações das suas contas são armazenadas em um arquivo de configuração
# local (~/.gitlab_switcher_accounts.conf) para uso futuro.
#
# O arquivo ~/.ssh/config é gerenciado automaticamente pelo script.
# Ele adiciona/atualiza/remove blocos de configuração SSH marcados com
# "# BEGIN git_switcher:" e "# END git_switcher:" para cada conta.
# Outras configurações manuais no ~/.ssh/config serão preservadas.
#
# Pré-requisitos:
# 1. Você deve ter gerado um par de chaves SSH (privada e pública) para CADA
#    conta GitLab que deseja gerenciar.
#    Ex: ~/.ssh/id_rsa (para uma conta) e ~/.ssh/id_ed25519_outra (para outra conta).
# 2. As chaves públicas (.pub) correspondentes devem estar adicionadas às suas
#    respectivas contas no GitLab.
#
# Uso:
# 1. Salve o script (ex: gitlab_switcher.sh) e torne-o executável: chmod +x gitlab_switcher.sh
# 2. Execute o script de qualquer lugar: ./gitlab_switcher.sh
# 3. Siga as instruções interativas. Se for configurar um repositório, navegue
#    até a pasta raiz do seu projeto Git antes de escolher a opção.
# ==============================================================================

# Define o caminho para o arquivo de configuração das contas do script (AGORA PARA GITLAB)
CONFIG_FILE="$HOME/.gitlab_switcher_accounts.conf"
# Define o caminho para o arquivo de configuração SSH
SSH_CONFIG_FILE="$HOME/.ssh/config"
# Array para armazenar os detalhes das contas (cada elemento é uma string separada por '|')
ACCOUNTS_ARRAY=()

echo "----------------------------------------------------"
echo "  Bem-vindo ao Alternador de Usuários Git/GitLab!   "
echo "----------------------------------------------------"

# Função para carregar as contas do arquivo de configuração do script
load_accounts() {
    ACCOUNTS_ARRAY=() # Limpa o array antes de carregar
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            # Ignora linhas vazias ou só com espaços
            if [[ -z "${line//[[:space:]]/}" ]]; then
                continue
            fi
            ACCOUNTS_ARRAY+=("$line")
        done < "$CONFIG_FILE"
    fi
}

# Função para salvar as contas no arquivo de configuração do script
save_accounts() {
    printf "%s\n" "${ACCOUNTS_ARRAY[@]}" > "$CONFIG_FILE"
    echo "Configurações de contas salvas em $CONFIG_FILE"
}

# Função para exibir as contas configuradas
display_accounts() {
    local i=0
    if (( ${#ACCOUNTS_ARRAY[@]} == 0 )); then
        echo "  Nenhuma conta configurada."
        return 1 # Indica que não há contas
    fi
    for account_entry in "${ACCOUNTS_ARRAY[@]}"; do
        IFS='|' read -r name email ssh_host gitlab_user pubkey_path <<< "$account_entry"
        echo "  $((i+1))) $name ($email)"
        ((i++))
    done
    return 0 # Indica que há contas
}

# Função para reconstruir o arquivo ~/.ssh/config com base nas contas ativas
rebuild_ssh_config() {
    # Garante que o diretório ~/.ssh existe
    mkdir -p "$(dirname "$SSH_CONFIG_FILE")"
    # Cria o arquivo config se não existir e define permissões
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        touch "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
        echo "Arquivo '$SSH_CONFIG_FILE' criado com sucesso e permissões ajustadas (600)."
    fi

    local tmp_file
    tmp_file=$(mktemp)

    # 1) Lê o conteúdo atual do SSH_CONFIG_FILE e remove todos os blocos
    #    que foram gerenciados anteriormente pelo git_switcher (entre BEGIN/END).
    #    Também remove linhas vazias no início e no final do conteúdo filtrado.
    awk '
        BEGIN {skip=0; first_line=1}
        /^# BEGIN git_switcher:/ {skip=1; next}
        /^# END git_switcher:/ {skip=0; next}
        skip==0 {
            if (first_line && $0 ~ /^[[:space:]]*$/) { # Ignora linhas vazias no início
                next
            }
            print
            first_line=0
        }
    ' "$SSH_CONFIG_FILE" | awk 'NF {p=1}; p' | awk 'NF || !last {print}; {last=NF}' > "$tmp_file"
    # O segundo awk 'NF {p=1}; p' remove linhas vazias do início
    # O terceiro awk 'NF || !last {print}; {last=NF}' remove linhas vazias do final

    # Move o conteúdo filtrado de volta para o SSH_CONFIG_FILE
    mv "$tmp_file" "$SSH_CONFIG_FILE"

    # 2) Acrescenta os blocos de configuração SSH para cada conta que ainda existe no script
    local num_accounts_to_add=${#ACCOUNTS_ARRAY[@]}
    local current_account_index=0

    for account_entry in "${ACCOUNTS_ARRAY[@]}"; do
        IFS='|' read -r name email ssh_host gitlab_user pubkey_path <<< "$account_entry"
        # Extrai o nome da chave privada do caminho da chave pública
        key_name=$(basename "$pubkey_path" .pub)

        # Adiciona uma linha vazia antes do bloco se não for o primeiro bloco
        # e se o arquivo não estiver vazio (para não ter linha vazia no topo)
        if [ "$current_account_index" -gt 0 ] || [ -s "$SSH_CONFIG_FILE" ]; then
            echo # Adiciona uma linha vazia para separação entre blocos ou se o arquivo já tem conteúdo
        fi

        echo "# BEGIN git_switcher: $ssh_host" >> "$SSH_CONFIG_FILE"
        echo "Host $ssh_host" >> "$SSH_CONFIG_FILE"
        echo "    HostName gitlab.com" >> "$SSH_CONFIG_FILE" # ALTERADO PARA GITLAB.COM
        echo "    User git" >> "$SSH_CONFIG_FILE"
        echo "    IdentityFile ~/.ssh/$key_name" >> "$SSH_CONFIG_FILE" # Usa o caminho relativo com ~
        echo "    IdentitiesOnly yes" >> "$SSH_CONFIG_FILE"
        echo "# END git_switcher: $ssh_host" >> "$SSH_CONFIG_FILE"

        current_account_index=$((current_account_index + 1))
    done

    echo "Arquivo '$SSH_CONFIG_FILE' reconstruído com base nas contas atuais."
}

# Função para adicionar uma nova conta interativamente
add_account_interactively() {
    echo "----------------------------------------------------"
    echo "  Adicionar Nova Conta Git/GitLab                   "
    echo "----------------------------------------------------"
    local new_name new_email new_ssh_host new_gitlab_user new_pubkey_path

    read -p "Nome da Conta (ex: Pessoal, Trabalho ou Seu Nome Completo): " new_name
    read -p "Email para Commits (ex: seu.email@exemplo.com): " new_email
    read -p "Host SSH (ex: gitlab.com-pessoal, gitlab.com-trabalho ou gitlab.com-seu_usuario): " new_ssh_host # EXEMPLOS ATUALIZADOS
    read -p "Usuário/Organização GitLab (ex: seu-username ou nome-da-org): " new_gitlab_user
    read -p "Caminho completo da Chave Pública (ex: ~/.ssh/id_rsa.pub): " new_pubkey_path

    # Expande o til (~) para o caminho completo do diretório HOME
    new_pubkey_path=$(eval echo "$new_pubkey_path")

    # Adiciona a nova conta ao array
    ACCOUNTS_ARRAY+=("$new_name|$new_email|$new_ssh_host|$new_gitlab_user|$new_pubkey_path")

    save_accounts
    rebuild_ssh_config # Reconstroi o SSH config após adicionar a conta

    echo "Conta '$new_name' adicionada com sucesso!"
    echo ""
}

# Função para editar uma conta existente
edit_account_interactively() {
    echo "----------------------------------------------------"
    echo "  Editar Conta Git/GitLab                           "
    echo "----------------------------------------------------"
    if ! display_accounts; then
        echo "Não há contas para editar."
        echo ""
        return
    fi

    read -p "Escolha o número da conta para editar (1-${#ACCOUNTS_ARRAY[@]}): " edit_choice
    if ! [[ "$edit_choice" =~ ^[0-9]+$ && "$edit_choice" -ge 1 && "$edit_choice" -le "${#ACCOUNTS_ARRAY[@]}" ]]; then
        echo "Escolha inválida."
        echo ""
        return
    fi

    local index=$((edit_choice - 1))
    local current_entry="${ACCOUNTS_ARRAY[$index]}"
    IFS='|' read -r current_name current_email current_ssh_host current_gitlab_user current_pubkey_path <<< "$current_entry"

    echo "Editando conta: $current_name"
    read -p "Novo Nome da Conta (atual: $current_name, ex: Seu Nome Completo): " new_name_input
    read -p "Novo Email para Commits (atual: $current_email): " new_email_input
    read -p "Novo Host SSH (atual: $current_ssh_host, ex: gitlab.com-seu_usuario): " new_ssh_host_input # EXEMPLOS ATUALIZADOS
    read -p "Novo Usuário/Organização GitLab (atual: $current_gitlab_user): " new_gitlab_user_input
    read -p "Novo Caminho completo da Chave Pública (atual: $current_pubkey_path): " new_pubkey_path_input

    # Usa o valor atual se o novo estiver vazio
    local final_name=${new_name_input:-$current_name}
    local final_email=${new_email_input:-$current_email}
    local final_ssh_host=${new_ssh_host_input:-$current_ssh_host}
    local final_gitlab_user=${new_gitlab_user_input:-$current_gitlab_user}
    local final_pubkey_path=${new_pubkey_path_input:-$current_pubkey_path}
    final_pubkey_path=$(eval echo "$final_pubkey_path") # Expande o til

    ACCOUNTS_ARRAY[$index]="$final_name|$final_email|$final_ssh_host|$final_gitlab_user|$final_pubkey_path"
    save_accounts
    rebuild_ssh_config # Reconstroi o SSH config após editar a conta

    echo "Conta '$final_name' atualizada com sucesso!"
    echo ""
}

# Função para excluir uma conta existente
delete_account_interactively() {
    echo "----------------------------------------------------"
    echo "  Excluir Conta Git/GitLab                          "
    echo "----------------------------------------------------"
    if ! display_accounts; then
        echo "Não há contas para excluir."
        echo ""
        return
    fi

    read -p "Escolha o número da conta para excluir (1-${#ACCOUNTS_ARRAY[@]}): " delete_choice
    if ! [[ "$delete_choice" =~ ^[0-9]+$ && "$delete_choice" -ge 1 && "$delete_choice" -le "${#ACCOUNTS_ARRAY[@]}" ]]; then
        echo "Escolha inválida."
        echo ""
        return
    fi

    local index_to_delete=$((delete_choice - 1))
    local deleted_entry="${ACCOUNTS_ARRAY[$index_to_delete]}"
    local deleted_name=$(echo "$deleted_entry" | cut -d'|' -f1)

    # Remove o elemento do array
    unset 'ACCOUNTS_ARRAY[index_to_delete]'
    ACCOUNTS_ARRAY=("${ACCOUNTS_ARRAY[@]}") # Reindexa o array

    save_accounts
    rebuild_ssh_config # Reconstroi o SSH config após excluir a conta

    echo "Conta '$deleted_name' excluída com sucesso (e SSH config reconstruído)!"
    echo ""
}

# Função para verificar e guiar a configuração SSH
check_ssh_config() {
    local account_name=$1
    local ssh_host=$2
    local pubkey_path=$3
    local gitlab_user=$4 # Renomeado para gitlab_user para clareza
    local private_key_path_relative="~/.ssh/$(basename "$pubkey_path" .pub)"

    echo "Verificando configuração SSH para a conta '$account_name'..."

    # 1. Verificar se o arquivo da chave pública existe
    if [ ! -f "$pubkey_path" ]; then
        echo "ERRO: O arquivo da chave pública '$pubkey_path' NÃO foi encontrado."
        echo "Por favor, gere a chave SSH para esta conta primeiro."
        echo "Exemplo: ssh-keygen -t ed25519 -C \"$account_name\" -f $(dirname "$pubkey_path")/id_ed25519_$(echo "$account_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
        exit 1
    fi

    # 2. Perguntar se a chave já está no GitLab
    read -p "A chave pública para '$account_name' (arquivo: $(basename "$pubkey_path")) já está configurada no GitLab? (s/n): " ssh_configured_choice
    if [[ "$ssh_configured_choice" =~ ^[Ss]$ ]]; then
        echo "Realizando teste de conexão SSH para '$account_name'..."
        # Tentar conectar ao GitLab usando o host SSH configurado
        # O '2>&1 | grep -q "successfully authenticated"' verifica se a mensagem de sucesso aparece
        if ssh -T git@"$ssh_host" 2>&1 | grep -q "successfully authenticated"; then
            echo "SUCESSO: Conexão SSH para '$account_name' estabelecida com sucesso!"
        else
            echo "FALHA: Não foi possível autenticar via SSH para '$account_name'."
            echo "Por favor, verifique:"
            echo "  - Se a chave privada correspondente ('$private_key_path_relative') está no seu ~/.ssh/."
            echo "  - Se o seu '$SSH_CONFIG_FILE' está correto para o Host '$ssh_host' e aponta para a chave correta."
            echo "  - Se a chave pública está adicionada corretamente na sua conta GitLab."
            echo "  - Tente 'eval \"\$(ssh-agent -s)\"' e 'ssh-add \"$private_key_path_relative\"' se você usa passphrase."
            exit 1
        fi
    else
        echo "Por favor, adicione a chave pública ao GitLab para a conta '$gitlab_user'."
        echo "1. Copie o conteúdo da sua chave pública:"
        echo "   cat $pubkey_path"
        echo "2. Acesse as configurações SSH do GitLab para a conta '$gitlab_user':"
        echo "   https://gitlab.com/-/profile/keys" # LINK ATUALIZADO PARA GITLAB
        echo "3. Clique em 'Add a new key', cole o conteúdo e salve." # TEXTO ATUALIZADO
        read -p "Pressione Enter após adicionar a chave no GitLab..."
        # Após o usuário adicionar, tentar o teste de conexão
        if ssh -T git@"$ssh_host" 2>&1 | grep -q "successfully authenticated"; then
            echo "SUCESSO: Conexão SSH para '$account_name' estabelecida com sucesso!"
        else
            echo "FALHA: A chave ainda não está funcionando. Por favor, verifique os passos acima."
            exit 1
        fi
    fi
    echo ""
}


# --- Lógica Principal do Script ---

# Carrega as contas existentes ao iniciar
load_accounts

# Loop principal para o menu de gerenciamento
while true; do
    echo "----------------------------------------------------"
    echo "  Menu Principal                                    "
    echo "----------------------------------------------------"
    echo "  1) Configurar repositório atual (selecionar conta)"
    echo "  2) Adicionar nova conta"
    echo "  3) Editar conta existente"
    echo "  4) Excluir conta"
    echo "  q) Sair"
    echo "----------------------------------------------------"
    read -p "Escolha uma opção: " main_menu_choice

    case "$main_menu_choice" in
        1) # Configurar repositório atual
            # Verifica se estamos em um repositório Git antes de prosseguir
            if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
                echo "ERRO: Para configurar um repositório, você deve estar na pasta raiz do seu projeto Git."
                echo "Por favor, navegue até o repositório e execute o script novamente, ou escolha outra opção."
                echo ""
                continue # Volta para o menu principal
            fi
            echo "Repositório Git detectado: $(basename "$(pwd)")"
            echo ""

            # Loop para seleção de conta para o repositório
            while true; do
                num_accounts=${#ACCOUNTS_ARRAY[@]}
                if (( num_accounts == 0 )); then
                    echo "Nenhuma conta configurada. Por favor, adicione uma conta primeiro (opção 2 no menu principal)."
                    break # Sai do loop de seleção de conta e volta para o menu principal
                fi

                echo "----------------------------------------------------"
                echo "  Contas Configuradas:                             "
                echo "----------------------------------------------------"
                display_accounts # Exibe as contas
                echo "----------------------------------------------------"
                read -p "Escolha uma conta para este repositório (1-${num_accounts}, 'q' para voltar ao menu principal): " select_account_choice

                if [[ "$select_account_choice" =~ ^[Qq]$ ]]; then
                    break # Volta para o menu principal
                elif [[ "$select_account_choice" =~ ^[0-9]+$ && "$select_account_choice" -ge 1 && "$select_account_choice" -le "$num_accounts" ]]; then
                    selected_index=$((select_account_choice - 1))
                    selected_account_entry="${ACCOUNTS_ARRAY[$selected_index]}"
                    IFS='|' read -r SELECTED_NAME SELECTED_EMAIL SELECTED_SSH_HOST SELECTED_GITLAB_USER SELECTED_PUBKEY_PATH <<< "$selected_account_entry" # Renomeado para SELECTED_GITLAB_USER

                    echo ""
                    echo "Configurando para a conta: $SELECTED_NAME..."
                    echo ""

                    # Chamar a função de verificação SSH para a conta selecionada
                    check_ssh_config "$SELECTED_NAME" "$SELECTED_SSH_HOST" "$SELECTED_PUBKEY_PATH" "$SELECTED_GITLAB_USER"

                    # 4. Configurar user.name e user.email localmente
                    echo "Definindo credenciais de commit localmente..."
                    git config user.name "$SELECTED_NAME"
                    git config user.email "$SELECTED_EMAIL"
                    echo "  -> user.name definido para: $(git config user.name)"
                    echo "  -> user.email definido para: $(git config user.email)"
                    echo ""

                    # 5. Configurar a URL do remote 'origin' para usar o host SSH correto
                    echo "Configurando a URL do remote 'origin' para autenticação SSH..."
                    CURRENT_REMOTE_URL=$(git config remote.origin.url)

                    if [ -z "$CURRENT_REMOTE_URL" ]; then
                        echo "AVISO: O remote 'origin' não está configurado. Não foi possível alterar a URL do remote."
                        echo "Por favor, configure o remote manualmente se necessário (ex: git remote add origin git@$SELECTED_SSH_HOST:$SELECTED_GITLAB_USER/nome-do-repositorio.git)"
                    else
                        REPO_NAME=$(basename "$CURRENT_REMOTE_URL")
                        NEW_REMOTE_URL="git@$SELECTED_SSH_HOST:$SELECTED_GITLAB_USER/$REPO_NAME"
                        git remote set-url origin "$NEW_REMOTE_URL"
                        echo "  -> URL do remote 'origin' atualizada para: $(git config remote.origin.url)"
                    fi

                    echo ""
                    echo "----------------------------------------------------"
                    echo "  Configuração concluída para o repositório atual!  "
                    echo "----------------------------------------------------"
                    echo "Você pode verificar as configurações com:"
                    echo "  git config --list"
                    echo ""
                    echo "Agora você pode fazer commits e pushes com a conta selecionada."
                    echo "Lembre-se de que esta configuração é LOCAL para este repositório."
                    echo "----------------------------------------------------"
                    break 2 # Sai dos dois loops (seleção de conta e menu principal)
                else
                    echo "Opção inválida. Por favor, tente novamente."
                    echo ""
                fi
            done
            ;;
        2) # Adicionar nova conta
            add_account_interactively
            load_accounts # Recarrega as contas após adicionar
            ;;
        3) # Editar conta existente
            edit_account_interactively
            load_accounts # Recarrega as contas após editar
            ;;
        4) # Excluir conta
            delete_account_interactively
            load_accounts # Recarrega as contas após excluir
            ;;
        q|Q) # Sair
            echo "Saindo do alternador de usuários."
            exit 0
            ;;
        *)
            echo "Opção inválida. Por favor, tente novamente."
            echo ""
            ;;
    esac
done
