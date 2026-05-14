# Instala o Agent (Geralmente via DNF)
sudo dnf install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent

# Sanitização específica para Cloud
sudo dnf clean all
sudo cloud-init clean --logs
sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo truncate -s 0 /etc/machine-id

# Finalização
history -c && history -w && rm -f ~/.bash_history && sudo poweroff