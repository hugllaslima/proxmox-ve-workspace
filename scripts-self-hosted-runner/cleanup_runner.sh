#!/bin/bash

#==============================================================================
# Script: cleanup_runner.sh
# Descrição: Limpeza completa das configurações do Self-hosted Runner
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Parada do serviço do runner
# 2. Desabilitação do serviço systemd
# 3. Remoção dos arquivos de configuração
# 4. Remoção do usuário runner
# 5. Limpeza dos diretórios de trabalho
# 6. Verificação da limpeza completa

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cleanup Self-Hosted Runner Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Verificar se está rodando como sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado com sudo!${NC}"
    echo "Execute: sudo ./cleanup-runner.sh"
    exit 1
fi

echo -e "${YELLOW}ATENÇÃO: Este script irá remover:${NC}"
echo "• Usuário 'runner' e seu diretório home"
echo "• Serviço do GitHub Actions Runner (se instalado)"
echo "• Configurações sudo do usuário runner"
echo "• Diretório /var/www (se criado pelo script)"
echo

read -p "Tem certeza que deseja continuar? (s/N): " confirm

if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

echo
echo -e "${YELLOW}[ETAPA 1]${NC} Parando serviços do runner..."

# Verificar se o usuário runner existe
if id "runner" &>/dev/null; then
    echo -e "${BLUE}Usuário runner encontrado. Procedendo com cleanup...${NC}"
    
    # Parar o serviço se estiver rodando
    if sudo -u runner bash -c "cd /home/runner/actions-runner && test -f ./svc.sh" 2>/dev/null; then
        echo -e "${YELLOW}Parando serviço do runner...${NC}"
        sudo -u runner bash -c "cd /home/runner/actions-runner && sudo ./svc.sh stop" 2>/dev/null || echo -e "${YELLOW}Serviço já estava parado.${NC}"
        sudo -u runner bash -c "cd /home/runner/actions-runner && sudo ./svc.sh uninstall" 2>/dev/null || echo -e "${YELLOW}Serviço não estava instalado.${NC}"
    fi
    
    # Matar processos do runner se houver
    echo -e "${YELLOW}Finalizando processos do runner...${NC}"
    pkill -f "actions-runner" 2>/dev/null || echo -e "${YELLOW}Nenhum processo do runner encontrado.${NC}"
    pkill -u runner 2>/dev/null || echo -e "${YELLOW}Nenhum processo do usuário runner encontrado.${NC}"
    
else
    echo -e "${YELLOW}Usuário runner não encontrado.${NC}"
fi

echo
echo -e "${YELLOW}[ETAPA 2]${NC} Removendo configurações sudo..."

# Remover configurações sudo
if [ -f "/etc/sudoers.d/runner" ]; then
    rm -f /etc/sudoers.d/runner
    echo -e "${GREEN}Configurações sudo removidas.${NC}"
else
    echo -e "${YELLOW}Arquivo sudoers não encontrado.${NC}"
fi

echo
echo -e "${YELLOW}[ETAPA 3]${NC} Removendo usuário runner..."

# Remover usuário runner e seu home directory
if id "runner" &>/dev/null; then
    userdel -r runner 2>/dev/null || {
        echo -e "${YELLOW}Erro ao remover usuário. Tentando forçar...${NC}"
        userdel -f runner 2>/dev/null || echo -e "${RED}Não foi possível remover o usuário runner automaticamente.${NC}"
    }
    echo -e "${GREEN}Usuário runner removido.${NC}"
else
    echo -e "${YELLOW}Usuário runner não existe.${NC}"
fi

# Remover diretório home se ainda existir
if [ -d "/home/runner" ]; then
    rm -rf /home/runner
    echo -e "${GREEN}Diretório /home/runner removido.${NC}"
fi

echo
echo -e "${YELLOW}[ETAPA 4]${NC} Limpando diretórios adicionais..."

# Perguntar sobre /var/www (cuidado para não remover dados importantes)
if [ -d "/var/www" ]; then
    echo -e "${YELLOW}Diretório /var/www encontrado.${NC}"
    read -p "Remover /var/www? (CUIDADO: pode conter suas aplicações) (s/N): " remove_www
    
    if [[ $remove_www =~ ^[Ss]$ ]]; then
        rm -rf /var/www
        echo -e "${GREEN}Diretório /var/www removido.${NC}"
    else
        echo -e "${YELLOW}Diretório /var/www mantido.${NC}"
    fi
fi

echo
echo -e "${YELLOW}[ETAPA 5]${NC} Verificando limpeza..."

# Verificações finais
if id "runner" &>/dev/null; then
    echo -e "${RED}❌ Usuário runner ainda existe${NC}"
else
    echo -e "${GREEN}✅ Usuário runner removido${NC}"
fi

if [ -f "/etc/sudoers.d/runner" ]; then
    echo -e "${RED}❌ Configurações sudo ainda existem${NC}"
else
    echo -e "${GREEN}✅ Configurações sudo removidas${NC}"
fi

if [ -d "/home/runner" ]; then
    echo -e "${RED}❌ Diretório home ainda existe${NC}"
else
    echo -e "${GREEN}✅ Diretório home removido${NC}"
fi

# Verificar processos
if pgrep -f "actions-runner" > /dev/null; then
    echo -e "${RED}❌ Processos do runner ainda rodando${NC}"
else
    echo -e "${GREEN}✅ Nenhum processo do runner rodando${NC}"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup concluído!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Agora você pode rodar o script de setup novamente:${NC}"
echo "sudo ./setup_runner.sh"
echo

echo -e "${YELLOW}Nota: Se algum item apareceu como ❌ acima,${NC}"
echo -e "${YELLOW}pode ser necessário reinicializar o servidor ou${NC}"
echo -e "${YELLOW}fazer limpeza manual.${NC}"
