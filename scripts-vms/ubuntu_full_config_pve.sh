#!/bin/bash

#==============================================================================
# Script: ubuntu_full_config_pve.sh
# Descrição: Configuração completa do Ubuntu Server para Proxmox VE
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 2.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Configuração de timezone
# 2. Configuração de usuário sudo
# 3. Configuração SSH avançada
# 4. Atualização do sistema
# 5. Instalação do Docker e Docker Compose
# 6. Configuração de permissões
# 7. Instalação de ferramentas adicionais
# 8. Configurações de segurança

set -euo pipefail

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

reiniciar() {
    echo
    echo "ATENÇÃO: Caso tenha configurado uma chave SSH, teste o acesso com sua chave em outro terminal antes de reiniciar!"
    read -p "Deseja reiniciar o servidor agora para aplicar as alterações? (s/n): " RESP_REBOOT
    if [[ "$RESP_REBOOT" =~ ^([sS][iI][mM]|[sS])$ ]]; then
        echo "Reiniciando o servidor..."
        sleep 2
        sudo reboot
    else
        echo "REINICIALIZAÇÃO NÃO EXECUTADA."
        echo "Por favor, execute 'sudo reboot' manualmente quando estiver pronto."
    fi
}
echo " "

# ============================================================================
# ETAPA 1: CONFIGURAÇÃO INICIAL DO SISTEMA
# ============================================================================
configuracao_inicial() {
echo "[Configuração Inicial - Root]"
echo "Ajustando o timezone..."
    timedatectl set-timezone America/Sao_Paulo
    echo "Timezone configurado para: $(timedatectl show --property=Timezone --value)"
sleep 1

echo "Adicionando usuário 'ubuntu' ao grupo sudo..."
    usermod -aG sudo ubuntu
    sleep 1

echo "Enable sudo sem senha para ubuntu..."
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu   
    sleep 1

echo "Atualizando pacotes..."
    apt update && apt upgrade -y   
    sleep 1

echo "Instalando qemu-guest-agent..."
    apt install qemu-guest-agent -y
    systemctl start qemu-guest-agent
    systemctl enable qemu-guest-agent
}
echo " "

# ============================================================================
# ETAPA 2: CONFIGURAÇÃO SSH AVANÇADA PARA USUÁRIO UBUNTU
# ============================================================================
configura_ssh_ubuntu() {
    echo "[SSH para usuário ubuntu]"

    read -p "Deseja configurar uma chave SSH para o usuário ubuntu? (s/n): " CONFIGURAR_SSH
    if [[ "$CONFIGURAR_SSH" =~ ^([sS][iI][mM]|[sS])$ ]]; then
        SSH_DIR="/home/ubuntu/.ssh"
        AUTH_KEYS="$SSH_DIR/authorized_keys"

        echo "Criando diretório SSH para o usuário ubuntu..."
        sudo -u ubuntu mkdir -p $SSH_DIR
        sudo chown ubuntu:ubuntu $SSH_DIR
        sudo chmod 700 $SSH_DIR

        # Entrada manual da chave pública
        echo "Por favor, cole a chave PÚBLICA do usuário ubuntu."
        echo "Finalize com Ctrl+D numa linha em branco."
        
        # Lê a chave pública fornecida pelo usuário
        CHAVE_PUBLICA=$(sudo -u ubuntu tee /tmp/temp_pubkey)
        
        # Valida se parece com uma chave pública SSH
        if [[ ! "$CHAVE_PUBLICA" =~ ^ssh-(rsa|dss|ecdsa|ed25519) ]]; then
            echo "ERRO: A entrada não parece ser uma chave pública SSH válida."
            echo "Uma chave pública deve começar com 'ssh-rsa', 'ssh-dss', 'ssh-ecdsa' ou 'ssh-ed25519'."
            rm -f /tmp/temp_pubkey
            exit 1
        fi
        echo " "

        # Cria ou atualiza o authorized_keys sem apagar chaves existentes
        sudo -u ubuntu touch $AUTH_KEYS
        
        # Verifica se a chave já existe para evitar duplicatas
        if ! grep -qF "$CHAVE_PUBLICA" $AUTH_KEYS; then
            echo "$CHAVE_PUBLICA" | sudo tee -a $AUTH_KEYS > /dev/null
            echo "Nova chave pública adicionada ao authorized_keys."
        else
            echo "Esta chave pública já existe no authorized_keys."
        fi
        
        sudo chmod 600 $AUTH_KEYS
        sudo chown ubuntu:ubuntu $AUTH_KEYS

        # Remove arquivo temporário
        rm -f /tmp/temp_pubkey

        echo "Chave SSH configurada para o usuário ubuntu (chaves existentes preservadas)."
    else
        echo "Configuração de chave SSH IGNORADA."
    fi
}
echo " "

# ============================================================================
# ETAPA 3: AJUSTES NO SSHD
# ============================================================================
ajusta_sshd() {
    echo "[Ajuste do SSHD]"

    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Backup antes de alterar
    sudo cp $SSHD_CONFIG ${SSHD_CONFIG}.bkp_$(date +%Y%m%d%H%M%S)

    # Descomentar/ajustar parâmetros essenciais
    sudo sed -i \
        -e 's/^#\?\s*PubkeyAuthentication.*/PubkeyAuthentication yes/' \
        -e 's/^#\?\s*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys .ssh\/authorized_keys2/' \
        -e 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/^#\?\s*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' \
        $SSHD_CONFIG

    # Ajusta *.conf se necessário (comenta PasswordAuthentication yes)
    for CONF in /etc/ssh/sshd_config.d/*.conf; do
        if [ -f "$CONF" ]; then
            sudo sed -i \
                -e 's/^\s*PasswordAuthentication yes/# PasswordAuthentication yes/g' \
                $CONF
        fi
    done

    echo "Reiniciando sshd..."
    sudo systemctl restart ssh

    echo "Ajustes SSH aplicados. Teste o acesso via SSH em outra janela antes de sair desta sessão!"
}
echo " "

# ============================================================================
# ETAPA 4: INSTALAÇÃO DOCKER E DOCKER COMPOSE
# ============================================================================
instala_docker() {
    echo "[Docker para usuário ubuntu]"

    read -p "Deseja instalar o Docker e Docker Compose para o usuário ubuntu? (s/n): " INSTALAR_DOCKER
    if [[ "$INSTALAR_DOCKER" =~ ^([sS][iI][mM]|[sS])$ ]]; then
        sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y

        sudo apt update
        sudo apt install docker-ce -y
        sudo systemctl enable docker

        sudo usermod -aG docker ubuntu

        echo "Instalando Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        echo "Versões instaladas:"
        docker --version
        docker-compose --version

        echo "Usuário ubuntu pronto para usar Docker e Docker Compose."
    else
        echo "Instalação do Docker IGNORADA."
    fi
}

# ============================================================================
# EXECUÇÃO PRINCIPAL DO SCRIPT
# ============================================================================

if [[ $(id -u) -eq 0 ]]; then
    configuracao_inicial
    configura_ssh_ubuntu

    # Só ajusta o sshd se a configuração da chave foi feita para evitar bloqueio
    if [[ "$CONFIGURAR_SSH" =~ ^([sS][iI][mM]|[sS])$ ]]; then
        ajusta_sshd
    fi

    instala_docker
    reiniciar
else
    echo "Execute este script como ROOT (sudo su)."
    exit 1
fi

# ===== FIM DO SCRIPT =====
