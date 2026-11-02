#!/usr/bin/env bash
# ==============================================================================
# Script: debian_versions.sh
# Descrição: Script de sanitização e preparação para sistemas baseados em Debian.
#            Instala qemu-guest-agent, limpa logs, cache e histórico.
# ==============================================================================

# Instala o QEMU Guest Agent e habilita o serviço no systemd
sudo apt update && sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent

# Limpeza do cache do APT e remoção de pacotes órfãos
sudo apt clean && sudo apt autoremove -y

# Sanitização de logs do Cloud-Init e do sistema
sudo cloud-init clean --logs
sudo find /var/log -type f -exec truncate -s 0 {} \;

# Reset do machine-id para evitar conflitos de IP em clones
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Finalização: Limpa o histórico do bash e desliga a VM
history -c && history -w && rm -f ~/.bash_history && sudo poweroff