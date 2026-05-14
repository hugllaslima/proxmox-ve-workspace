# No Alpine, o processo é via OpenRC e apk
sudo apk add qemu-guest-agent
sudo rc-update add qemu-guest-agent default
sudo /etc/init.d/qemu-guest-agent start

# Limpeza de cache e logs (Alpine é mínimo, tem menos logs)
sudo apk cache clean
sudo rm -rf /var/cache/apk/*
[ -f /etc/machine-id ] && sudo truncate -s 0 /etc/machine-id

# Finalização (Alpine usa o shell ash por padrão)
history -c && rm -f ~/.ash_history && sudo poweroff