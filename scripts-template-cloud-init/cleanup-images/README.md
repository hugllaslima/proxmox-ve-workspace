# 🧹 Scripts de Limpeza para Templates Cloud-Init

Este diretório contém scripts de limpeza desenvolvidos para preparar as máquinas virtuais antes que elas sejam convertidas em Templates no Proxmox VE.

Antes de transformar uma VM em um template, é crucial acessá-la e executar o script correspondente ao seu sistema operacional. O objetivo principal destes scripts é realizar tarefas de sanitização da imagem, tais como:

- 📦 Instalação do `qemu-guest-agent` para melhor integração com o Proxmox.
- 🗑️ Limpeza de logs do sistema e do Cloud-Init.
- 🕒 Limpeza do histórico de comandos aplicados (`bash_history` e etc).
- 🔄 Reset do `machine-id` para garantir que os clones recebam um novo IP via DHCP de forma correta.
- ✨ Outras remoções necessárias para garantir que o template seja uma imagem base limpa e pronta para clonagem.

## 🎯 Scripts e Distribuições Suportadas

Utilize o script adequado de acordo com a imagem do sistema operacional da sua máquina virtual:

| Script | Sistema Operacional | Descrição |
| :--- | :--- | :--- |
| `alpine-version.sh` | **Alpine Linux** | Instala via `apk`, configura o OpenRC e limpa cache/logs. |
| `debian_versions.sh` | **Debian** | Usa `apt`, limpa cache, logs e reseta o `machine-id`. |
| `oracle-versions.sh` | **Oracle Linux** | Usa `dnf`, limpa cache, logs e reseta o `machine-id`. |
| `rhel_versions.sh` | **RHEL, AlmaLinux, Rocky Linux** | Usa `dnf`, limpa cache, logs e reseta o `machine-id`. |
| `ubuntu_versions.sh` | **Ubuntu** | Usa `apt`, limpa cache, logs e reseta o `machine-id`. |

## 🚀 Como Utilizar

1. Acesse a máquina virtual via SSH ou console (interface web do Proxmox).
2. Copie o script correspondente para dentro da VM.
3. Torne o script executável:
   ```bash
   chmod +x nome_do_script.sh
   ```
4. Execute o script como usuário root (ou com sudo):
   ```bash
   sudo ./nome_do_script.sh
   ```
5. A VM será desligada automaticamente ao final do processo.
6. Após a VM desligar, você pode convertê-la com segurança para **Template** no Proxmox.

## ⚠️ Avisos Importantes

- **Desligamento Automático:** Todos os scripts encerram a VM no final da execução. Certifique-se de que não há processos não salvos rodando.
- **Histórico Apagado:** O histórico do shell da sua sessão será apagado. Se precisar guardar comandos, faça-o antes da execução do script.
