# Instala o Agent e limpa o cache
sudo dnf install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent

# Limpeza e Sanitização
sudo dnf clean all
sudo cloud-init clean --logs
sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Finalização
history -c && history -w && rm -f ~/.bash_history && sudo poweroff