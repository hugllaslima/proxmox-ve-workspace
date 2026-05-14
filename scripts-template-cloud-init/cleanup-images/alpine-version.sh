#!/usr/bin/env bash
# ==============================================================================
# Script: alpine-version.sh
# Descrição: Script de sanitização e preparação para Alpine Linux.
#            Instala qemu-guest-agent, limpa logs, cache e histórico.
# ==============================================================================

# No Alpine, o processo de instalação de pacotes é via apk e serviços via OpenRC
sudo apk add qemu-guest-agent
sudo rc-update add qemu-guest-agent default
sudo /etc/init.d/qemu-guest-agent start

# Limpeza de cache de pacotes (Alpine é mínimo, tem menos logs)
sudo apk cache clean
sudo rm -rf /var/cache/apk/*

# Truncar o machine-id (se existir) para gerar um novo no próximo boot
[ -f /etc/machine-id ] && sudo truncate -s 0 /etc/machine-id

# Finalização: Limpa o histórico do ash (shell padrão) e desliga a VM
history -c && rm -f ~/.ash_history && sudo poweroff