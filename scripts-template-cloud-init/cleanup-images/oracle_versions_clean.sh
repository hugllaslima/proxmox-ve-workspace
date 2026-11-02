#!/usr/bin/env bash
# ==============================================================================
# Script: oracle-versions.sh
# Descrição: Script de sanitização e preparação para Oracle Linux.
#            Instala qemu-guest-agent, limpa logs, cache e histórico.
# ==============================================================================

# Instala o QEMU Guest Agent via DNF e habilita o serviço
sudo dnf install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent

# Limpeza de cache do gerenciador de pacotes e sanitização para Cloud
sudo dnf clean all
sudo cloud-init clean --logs

# Truncar todos os arquivos de log do sistema para zerar seu conteúdo
sudo find /var/log -type f -exec truncate -s 0 {} \;

# Reset do machine-id para evitar conflitos de IP em clones
sudo truncate -s 0 /etc/machine-id

# Finalização: Limpa o histórico do bash e desliga a VM
history -c && history -w && rm -f ~/.bash_history && sudo poweroff