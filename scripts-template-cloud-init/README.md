# ☁️ Scripts de Template Cloud-Init

Este diretório contém scripts para automatizar a criação de templates de máquinas virtuais (VMs) utilizando Cloud-Init no Proxmox VE.

## 📜 Estrutura de Diretórios

```text
scripts-template-cloud-init/
├── debian_13_template.sh
├── ubuntu_24_04_template.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `ubuntu_24_04_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Ubuntu 24.04 utilizando Cloud-Init no Proxmox VE. O script gerencia o download da imagem oficial, criação da VM, importação do disco, configurações de hardware (virtio, boot, serial) e conversão final para template.

- **Quando Utilizar**:
  Ideal para provisionar rapidamente um template base do Ubuntu 24.04 pronto para ser clonado e configurado automaticamente via Cloud-Init em seu ambiente Proxmox.

- **Recursos Principais**:
  - Download automático da imagem oficial `noble-server-cloudimg-amd64.img`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware necessárias para o Cloud-Init (virtio, porta serial, etc.).
  - Opção interativa para revisar as configurações da VM via GUI antes de converter definitivamente em template.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x ubuntu_24_04_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./ubuntu_24_04_template.sh
     ```
  3. Siga as instruções interativas na tela para configurar o template.

### 2. `debian_13_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Debian 13 (Trixie) utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar criar uma base limpa do Debian 13 para clonagem rápida via Cloud-Init no Proxmox.

- **Recursos Principais**:
  - Download automático da imagem oficial `debian-13-generic-amd64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware e rede para o Cloud-Init.
  - Instruções integradas de pré-configuração (GUI) caso o usuário opte por não converter em template imediatamente.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x debian_13_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./debian_13_template.sh
     ```
  3. Siga as instruções interativas na tela.

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Proxmox VE.
- **Acesso**: Acesso `root` no nó Proxmox VE (via Shell).
- **Conectividade**: Conexão com a internet para baixar as imagens cloud-init (Ubuntu/Debian).
- **Armazenamento**: Espaço suficiente no storage de destino para o disco da VM.

## 🔒 Notas Importantes

- A imagem baixada será armazenada no diretório `/var/lib/vz/template/iso`.
- A VM resultante será convertida em template e **não poderá ser iniciada diretamente**. Para utilizá-la, você deve criar um "Clone Completo" (Full Clone) ou "Clone Vinculado" (Linked Clone) a partir deste template e então definir os parâmetros do Cloud-Init.
