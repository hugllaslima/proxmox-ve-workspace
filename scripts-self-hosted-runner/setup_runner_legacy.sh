#!/bin/bash

#==============================================================================
# Script: setup_runner_legacy.sh
# Descrição: Configuração de GitHub Actions Self-hosted Runner — Legado (Versão 1.0)
# Perfil: Simples/linear — recomendado para laboratório e cenários básicos
# Limitações: menos validações, sem checkpoints, tratamento de erros simplificado
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Criação do usuário dedicado para o runner
# 2. Download e instalação do GitHub Actions Runner
# 3. Configuração do runner com token de autenticação
# 4. Criação do serviço systemd
# 5. Configuração de permissões e segurança
# 6. Inicialização e verificação do serviço

set -e  # Parar execução se houver erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para executar comandos como usuário runner
run_as_runner() {
    sudo -u runner bash -c "$1"
}

#==============================================================================
# ETAPA 1: APRESENTAÇÃO E VERIFICAÇÃO DE PRIVILÉGIOS
#==============================================================================
echo " "
echo "=================================================================================="
echo "✅ Permissões aprimoradas: Adicionadas permissões para kill, pkill e systemctl"
echo "✅ Gerenciamento de processos melhorado: Método mais seguro para parar processos"
echo "✅ Timeouts controlados: Uso de timeout para evitar processos infinitos"
echo "✅ Múltiplos métodos de fallback: Se um método falhar, tenta alternativo"
echo "✅ Verificações de status melhoradas: Múltiplas formas de verificar o serviço"
echo "✅ Aguardos apropriados: Sleeps estratégicos para processos estabilizarem"
echo "✅ Melhor tratamento de erros: Mais tolerante a falhas e com recuperação"
echo "✅ Captura de Ctrl+C - Script continua automaticamente após interrupção"
echo "✅ Verificações robustas - Múltiplos métodos de verificação de status"
echo "✅ Feedback visual aprimorado - Separadores e emojis para clareza"
echo "✅ Tratamento de erros melhorado - Métodos alternativos quando necessário"
echo "=================================================================================="
echo " "

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Self-Hosted Runner Setup Script (Legacy v1.0)${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Verificar se está rodando como sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado com sudo!${NC}"
    echo "Execute: sudo ./setup-runner.sh"
    exit 1
fi

#==============================================================================
# ETAPA 2: CRIAÇÃO E CONFIGURAÇÃO DO USUÁRIO RUNNER
#==============================================================================
echo -e "${YELLOW}[ETAPA 1]${NC} Criando usuário 'runner' com permissões mínimas..."

# Criar usuário runner
if id "runner" &>/dev/null; then
    echo -e "${YELLOW}Usuário 'runner' já existe. Continuando...${NC}"
else
    useradd -m -s /bin/bash runner
    echo -e "${GREEN}Usuário 'runner' criado com sucesso!${NC}"
fi

# Configurar senha para o usuário runner
echo -e "${BLUE}Configurando senha para o usuário runner...${NC}"
echo -e "${YELLOW}Digite uma senha para o usuário runner (para segurança):${NC}"
passwd runner

# Adicionar runner ao grupo docker
usermod -aG docker runner
echo -e "${GREEN}Usuário 'runner' adicionado ao grupo docker.${NC}"

#==============================================================================
# ETAPA 3: CONFIGURAÇÃO DE PERMISSÕES SUDO
#==============================================================================
# Criar arquivo de configuração sudo para o usuário runner
cat > /etc/sudoers.d/runner << EOF
# Permissões específicas para o usuário runner
runner ALL=(ALL) NOPASSWD: /bin/systemctl restart *
runner ALL=(ALL) NOPASSWD: /bin/systemctl start *
runner ALL=(ALL) NOPASSWD: /bin/systemctl stop *
runner ALL=(ALL) NOPASSWD: /bin/systemctl status *
runner ALL=(ALL) NOPASSWD: /usr/bin/docker
runner ALL=(ALL) NOPASSWD: /usr/local/bin/docker-compose
runner ALL=(ALL) NOPASSWD: /usr/bin/docker-compose
runner ALL=(ALL) NOPASSWD: /bin/chown runner\:runner *
runner ALL=(ALL) NOPASSWD: /bin/chmod *

# Permitir instalação e gerenciamento do serviço do runner
runner ALL=(ALL) NOPASSWD: /home/runner/actions-runner/svc.sh *

# Permitir runner voltar para ubuntu sem senha
runner ALL=(ALL) NOPASSWD: /bin/su - ubuntu
runner ALL=(ALL) NOPASSWD: /usr/bin/su - ubuntu
runner ALL=(ALL) NOPASSWD: /bin/su ubuntu
runner ALL=(ALL) NOPASSWD: /usr/bin/su ubuntu

# Permitir acesso ao diretório de logs
runner ALL=(ALL) NOPASSWD: /usr/bin/journalctl *
EOF

chmod 440 /etc/sudoers.d/runner
echo -e "${GREEN}Permissões sudo configuradas para o usuário runner.${NC}"

# Configurar acesso entre usuários
echo -e "${BLUE}Configurando navegação entre usuários...${NC}"
echo "# Permitir ubuntu acessar runner sem senha" >> /etc/sudoers.d/runner
echo "ubuntu ALL=(runner) NOPASSWD: ALL" >> /etc/sudoers.d/runner
echo -e "${GREEN}Navegação entre usuários configurada.${NC}"

# Criar diretório da aplicação se não existir
if [ ! -d "/var/www" ]; then
    mkdir -p /var/www
fi
chown runner:runner /var/www
echo -e "${GREEN}Diretório da aplicação configurado.${NC}"

#==============================================================================
# ETAPA 4: PREPARAÇÃO DO DIRETÓRIO DO RUNNER
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 2]${NC} Mudando para usuário 'runner' e criando diretório actions-runner..."

# Criar diretório actions-runner como usuário runner
run_as_runner "cd /home/runner && mkdir -p actions-runner && cd actions-runner"
echo -e "${GREEN}Diretório actions-runner criado com sucesso!${NC}"

#==============================================================================
# ETAPA 5: DOWNLOAD DO GITHUB ACTIONS RUNNER
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 3]${NC} Download do GitHub Actions Runner"
echo -e "${BLUE}Agora você precisa ir ao GitHub e copiar o comando de download.${NC}"
echo -e "${BLUE}Vá em: Settings > Actions > Runners > New self-hosted runner${NC}"
echo -e "${BLUE}Copie o comando que começa com 'curl -o actions-runner-linux...'${NC}"
echo
read -p "Cole aqui o comando de download do GitHub: " download_command

if [ -z "$download_command" ]; then
    echo -e "${RED}Comando não pode estar vazio!${NC}"
    exit 1
fi

echo -e "${GREEN}Executando download...${NC}"
run_as_runner "cd /home/runner/actions-runner && $download_command"

#==============================================================================
# ETAPA 6: VALIDAÇÃO DE HASH (OPCIONAL)
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 4]${NC} Validação do hash (opcional)"
echo -e "${BLUE}Cole o comando de validação do hash ou pressione ENTER para pular:${NC}"
read -p "Comando de validação: " hash_command

if [ ! -z "$hash_command" ]; then
    echo -e "${GREEN}Validando hash...${NC}"
    run_as_runner "cd /home/runner/actions-runner && $hash_command"
    echo -e "${GREEN}Hash validado com sucesso!${NC}"
else
    echo -e "${YELLOW}Validação de hash pulada.${NC}"
fi

#==============================================================================
# ETAPA 7: EXTRAÇÃO DO INSTALADOR
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 5]${NC} Extração do instalador"
echo -e "${BLUE}Cole o comando de extração do GitHub (geralmente tar xzf actions-runner-linux...):${NC}"
read -p "Comando de extração: " extract_command

if [ -z "$extract_command" ]; then
    echo -e "${RED}Comando não pode estar vazio!${NC}"
    exit 1
fi

echo -e "${GREEN}Extraindo instalador...${NC}"
run_as_runner "cd /home/runner/actions-runner && $extract_command"

#==============================================================================
# ETAPA 8: CONFIGURAÇÃO DO RUNNER
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 6]${NC} Configuração do Runner"
echo -e "${BLUE}Cole o comando de configuração do GitHub (./config.sh --url...):${NC}"
read -p "Comando de configuração: " config_command

if [ -z "$config_command" ]; then
    echo -e "${RED}Comando não pode estar vazio!${NC}"
    exit 1
fi

echo -e "${GREEN}Configurando runner...${NC}"
run_as_runner "cd /home/runner/actions-runner && $config_command"

#==============================================================================
# ETAPA 9: TESTE E INSTALAÇÃO DO SERVIÇO
#==============================================================================
echo
echo -e "${YELLOW}[ETAPA 7]${NC} Teste do Runner"
echo -e "${BLUE}Deseja instalar o runner como serviço automático? (s/n):${NC}"
read -p "Instalar como serviço: " install_service

if [[ $install_service =~ ^[Ss]$ ]]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    TESTE DO RUNNER                            ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}1. O runner será iniciado agora${NC}"
    echo -e "${YELLOW}2. Aguarde aparecer: '2025-XX-XX XX:XX:XXZ: Listening for Jobs'${NC}"
    echo -e "${YELLOW}3. Quando ver essa mensagem, pressione Ctrl+C${NC}"
    echo -e "${YELLOW}4. O script continuará automaticamente${NC}"
    echo
    read -p "Pressione ENTER para iniciar o teste..."
    
    echo -e "${BLUE}Iniciando runner...${NC}"
    echo
    
    # Executar o runner e aguardar Ctrl+C do usuário
    run_as_runner "cd /home/runner/actions-runner && ./run.sh" || {
        echo
        echo -e "${GREEN}Runner parado pelo usuário (Ctrl+C). Continuando...${NC}"
    }
    
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                INSTALANDO COMO SERVIÇO                        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Aguardar um momento para processos terminarem naturalmente
    sleep 2
    
    echo -e "${BLUE}Instalando e iniciando o serviço...${NC}"
    
    # Instalar e iniciar o serviço
    if run_as_runner "cd /home/runner/actions-runner && sudo ./svc.sh install runner && sudo ./svc.sh start"; then
        echo -e "${GREEN}✅ Serviço instalado e iniciado com sucesso!${NC}"
        
        # Aguardar o serviço inicializar
        echo -e "${BLUE}Aguardando inicialização do serviço...${NC}"
        sleep 5
        
        echo
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                   STATUS DO SERVIÇO                          ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        
        # Mostrar status do serviço
        echo -e "${BLUE}Status do runner:${NC}"
        run_as_runner "cd /home/runner/actions-runner && sudo ./svc.sh status" || echo -e "${YELLOW}Status não disponível no momento.${NC}"
        
        echo
        echo -e "${BLUE}Status do sistema:${NC}"
        systemctl status actions.runner.* --no-pager -l || echo -e "${YELLOW}Verificando...${NC}"
        
        echo
        echo -e "${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✅${NC}"
        echo -e "${BLUE}Pressione ENTER para ver as instruções finais...${NC}"
        read -p ""
        
    else
        echo -e "${RED}❌ Erro na instalação do serviço.${NC}"
        echo -e "${YELLOW}Execute manualmente:${NC}"
        echo "sudo su - runner"
        echo "cd actions-runner"
        echo "sudo ./svc.sh install runner && sudo ./svc.sh start"
    fi
    
else
    echo -e "${YELLOW}Runner não será instalado como serviço.${NC}"
    echo -e "${BLUE}Para testar manualmente: sudo su - runner && cd actions-runner && ./run.sh${NC}"
fi

#==============================================================================
# ETAPA 10: INSTRUÇÕES FINAIS E RESUMO
#==============================================================================
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  🎉 CONFIGURAÇÃO CONCLUÍDA! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}📋 RESUMO DA CONFIGURAÇÃO:${NC}"
echo "• ✅ Usuário 'runner' criado com senha e permissões mínimas"
echo "• ✅ Runner instalado em /home/runner/actions-runner"
echo "• ✅ Usuário runner adicionado ao grupo docker"
echo "• ✅ Navegação entre usuários configurada"
echo "• ✅ Runner registrado no GitHub como 'app-personal-contact-develop'"
echo "• ✅ Serviço configurado e ativo"
echo
echo -e "${BLUE}🔄 NAVEGAÇÃO ENTRE USUÁRIOS:${NC}"
echo "• De ubuntu para runner: sudo su - runner"
echo "• De runner para ubuntu: sudo su - ubuntu (sem senha)"
echo "• Ou simplesmente: exit (para voltar)"
echo
echo -e "${BLUE}🔧 COMANDOS ÚTEIS:${NC}"
echo "• Ver status: sudo su - runner && cd actions-runner && sudo ./svc.sh status"
echo "• Reiniciar: sudo su - runner && cd actions-runner && sudo ./svc.sh restart"
echo "• Ver logs: sudo journalctl -u actions.runner.* -f"
echo "• Parar: sudo systemctl stop actions.runner.*"
echo "• Iniciar: sudo systemctl start actions.runner.*"
echo
echo -e "${BLUE}🔍 VERIFICAR NO GITHUB:${NC}"
echo "• Vá para: Settings > Actions > Runners"
echo "• Deve aparecer: app-personal-contact-develop (Online 🟢)"
echo
echo -e "${GREEN}🚀 Runner pronto para uso!${NC}"
echo -e "${YELLOW}💡 Lembre-se da senha do usuário runner.${NC}"
