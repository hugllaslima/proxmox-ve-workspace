# 📦 Scripts para QEMU Guest Agent

Este diretório contém scripts para gerenciar o **QEMU Guest Agent** em máquinas virtuais (VMs) Linux, facilitando a comunicação e a integração entre o host (hipervisor, como o Proxmox VE) e o guest (VM).

## Compatibilidade

Os scripts são específicos para diferentes famílias de distribuições Linux, com base no gerenciador de pacotes utilizado:

- **`apt_install_agent_qemu.sh`**:
  - **Sistemas Operacionais**: Distribuições baseadas em Debian.
  - **Exemplos**: Ubuntu (20.04, 22.04, 24.04), Debian (10, 11, 12), e outros derivados.

- **`yum_install_agent_qemu.sh`**:
  - **Sistemas Operacionais**: Distribuições baseadas em Red Hat.
  - **Exemplos**: CentOS, Rocky Linux, AlmaLinux, e outros que utilizam `yum` ou `dnf` (já que `dnf` mantém compatibilidade com `yum`).

## 📜 Estrutura de Diretórios

```
scripts-qemu-agent/
├── apt_install_agent_qemu.sh
├── yum_install_agent_qemu.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `apt_install_agent_qemu.sh`

- **Função**:
  Instala e habilita o QEMU Guest Agent em uma VM Linux baseada em **Debian/Ubuntu**.

- **Quando Utilizar**:
  Execute este script em **VMs com sistemas operacionais como Ubuntu, Debian** ou derivados que rodam em um hipervisor como o Proxmox VE. A instalação do agente é crucial para habilitar funcionalidades avançadas, como:
  - **Desligamento/Reinicialização Graciosa**: Permite que o hipervisor desligue ou reinicie a VM de forma segura.
  - **Obtenção de Informações**: Fornece ao host detalhes sobre a VM, como endereços IP.
  - **Snapshots Consistentes**: Ajuda a "congelar" o sistema de arquivos da VM antes de um snapshot.

- **Como Utilizar**:
  1. **Copiar para a VM**: Transfira o script para a máquina virtual.
  2. **Tornar o script executável**:
     ```bash
     chmod +x apt_install_agent_qemu.sh
     ```
  3. **Executar com `sudo`**:
     ```bash
     sudo ./apt_install_agent_qemu.sh
     ```

### 2. `yum_install_agent_qemu.sh`

- **Função**:
  Instala e habilita o QEMU Guest Agent em uma VM Linux baseada em **Red Hat/CentOS**.

- **Quando Utilizar**:
  Use este script em **VMs com sistemas como CentOS, Rocky Linux, AlmaLinux** ou outros que usam o gerenciador de pacotes `yum`/`dnf`.

- **Como Utilizar**:
  1. **Copiar para a VM**: Transfira o script para a máquina virtual.
  2. **Tornar o script executável**:
     ```bash
     chmod +x yum_install_agent_qemu.sh
     ```
  3. **Executar com `sudo`**:
     ```bash
     sudo ./yum_install_agent_qemu.sh
     ```

## ✅ Verificação no Proxmox VE

Após executar o script na VM, você pode confirmar que o QEMU Guest Agent está funcionando corretamente no painel do Proxmox VE:

1. Selecione a VM na interface web.
2. Vá para a aba **Summary**.
3. Na seção **IPs**, você deverá ver os endereços IP da VM listados. Se a mensagem "No guest agent configured" desapareceu e os IPs são exibidos, a comunicação foi estabelecida com sucesso.

## ⚠️ Pré-requisitos

- **Acesso na VM**: Um usuário com privilégios `sudo` ou `root`.
- **Configuração no Hipervisor**: O hipervisor (Proxmox VE) deve estar configurado para usar o QEMU Guest Agent. Isso é feito na aba **Options** da VM, marcando a caixa de seleção **QEMU Guest Agent**.

## 💡 Dica

- **Templates de VM**: A melhor prática é instalar o QEMU Guest Agent em uma VM base e, em seguida, convertê-la em um template. Todas as novas VMs criadas a partir deste template já terão o agente instalado e configurado.
