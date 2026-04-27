#!/bin/bash

#==============================================================================
# Script: yum_install_agent_qemu.sh
# Descrição: Instalação do QEMU Guest Agent em sistemas Red Hat/CentOS
# Autor: Hugllas Lima
# Data: $(date +%Y-%m-%d)
# Versão: 1.0
# Licença: MIT
# Repositório: https://github.com/hugllaslima/proxmox-ve-workspace
#==============================================================================

# ETAPAS DO SCRIPT:
# 1. Verificação do sistema operacional
# 2. Atualização dos repositórios
# 3. Instalação do QEMU Guest Agent
# 4. Habilitação do serviço
# 5. Verificação do status do serviço

# ============================================================================
# ETAPA 1: APRESENTAÇÃO E PREPARAÇÃO
# ============================================================================

echo " "
echo " -------------------------------------------------------------- "
echo "|                                                              |"
echo "|    AGUARDE QUE IREMOS INICIAR A INSTALAÇÃO DO AGENTE QEMU    |"
echo "|                                                              |"
echo " -------------------------------------------------------------- "
       sleep 3
echo " "

# ============================================================================
# ETAPA 2: INSTALAÇÃO DO QEMU GUEST AGENT
# ============================================================================

       # INSTALAÇÃO DO "QEMU-GUEST-AGENT" NO HOST CONVIDADO
         yum install qemu-guest-agent -y

# ============================================================================
# ETAPA 3: CONFIGURAÇÃO E INICIALIZAÇÃO DO SERVIÇO
# ============================================================================

       # INICIANDO O SERVIÇO
         systemctl start qemu-guest-agent

       # HABILITARÁ O SERVIÇO PARA INICIALIZAÇÃO AUTOMÁTICA
         systemctl enable qemu-guest-agent

       sleep 2

# ============================================================================
# ETAPA 4: FINALIZAÇÃO E REINICIALIZAÇÃO
# ============================================================================
echo " "
echo " -------------------------------------------------------------- "
echo "|                                                              |"
echo "|               INSTALAÇÃO CONCLUÍDA COM SUCESSO               |"
echo "|                                                              |"
echo "|                            < | >                             |"
echo "|                                                              |"
echo "|                      #### ATENÇÃO ####                       |"
echo "|                                                              |"
echo "|          SEU SISTEMA SERÁ REINICIADO EM 10 SEGUNDOS          |"
echo "|       PARA CANCELAR A REINICIALIZAÇÃO, DIGITE {CTRL+C}       |"
echo "|                                                              |"
echo " -------------------------------------------------------------- "
echo " "
       sleep 10

       # REINICIARÁ O SISTEMA OPERACIONAL
         reboot

#fim_script
