# ☁️ Scripts de Template Cloud-Init

Este diretório contém scripts para automatizar a criação de templates de máquinas virtuais (VMs) utilizando Cloud-Init no Proxmox VE.

## ⚙️ Configuração Padrão de Hardware

Os scripts provisionam automaticamente os recursos de hardware das máquinas virtuais no momento da criação. Abaixo estão os valores definidos em código (exceto o disco, que é sugerido e pode ser alterado durante a execução interativa do script):

| Sistema Operacional (Família de Scripts) | Núcleos de vCPU (vCores) Alocados | Memória RAM Padrão | Espaço de Armazenamento Sugerido (Interativo) |
| :--- | :--- | :--- | :--- |
| **Alma Linux 9** (`alma_linux_9_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Alpine Linux** (`alpine_linux_template.sh`) | 1 vCPU | 1 GB (1024 MB) | 5 GB |
| **CentOS Stream 9** (`centos_stream_9_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Debian 10** (`debian_10_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Debian 11** (`debian_11_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Debian 12** (`debian_12_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Debian 13** (`debian_13_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Oracle Linux 8** (`oracle_linux_8_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Oracle Linux 9** (`oracle_linux_9_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Red Hat Enterprise Linux 8** (`rhel_8_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Red Hat Enterprise Linux 9** (`rhel_9_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Rocky Linux 9** (`rocky_linux_9_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Ubuntu 20.04** (`ubuntu_20_04_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Ubuntu 22.04** (`ubuntu_22_04_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Ubuntu 24.04** (`ubuntu_24_04_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |
| **Ubuntu 26.04** (`ubuntu_26_04_template.sh`) | 2 vCPU | 2 GB (2048 MB) | 20 GB |

## 🔧 Alterando vCPU e Memória

Se você desejar que o template seja criado com valores diferentes de CPU e Memória, basta abrir o script desejado com um editor de texto (ex: `nano script.sh`) e alterar os valores `2048` e `2` na linha que contém o comando de criação. Exemplo:

```bash
 qm create $VM_ID --name "$VM_NAME" --memory 4096 --cores 4 ...
```

## 📂 Estrutura de Diretórios

```text
scripts-template-cloud-init/
├── alma_linux_9_template.sh
├── alpine_linux_template.sh
├── centos_stream_9_template.sh
├── debian_10_template.sh
├── debian_11_template.sh
├── debian_12_template.sh
├── debian_13_template.sh
├── oracle_linux_8_template.sh
├── oracle_linux_9_template.sh
├── rhel_8_template.sh
├── rhel_9_template.sh
├── rocky_linux_9_template.sh
├── ubuntu_20_04_template.sh
├── ubuntu_22_04_template.sh
├── ubuntu_24_04_template.sh
├── ubuntu_26_04_template.sh
├── cleanup-images/
│   ├── alpine-version.sh
│   ├── debian_versions.sh
│   ├── oracle-versions.sh
│   ├── rhel_versions.sh
│   ├── ubuntu_versions.sh
│   └── README.md
└── README.md
```

## 🎯 Scripts Disponíveis

| Script | Descrição | Imagem Base |
| :--- | :--- | :--- |
| `alma_linux_9_template.sh` | Cria um template do AlmaLinux 9. | `AlmaLinux-9-GenericCloud-latest.x86_64.qcow2` |
| `alpine_linux_template.sh` | Cria um template do Alpine Linux (leve/rápido). | `nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2` |
| `centos_stream_9_template.sh` | Cria um template do CentOS Stream 9. | `CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2` |
| `debian_10_template.sh` | Cria um template do Debian 10 (Buster). | `debian-10-generic-amd64.qcow2` |
| `debian_11_template.sh` | Cria um template do Debian 11 (Bullseye). | `debian-11-generic-amd64.qcow2` |
| `debian_12_template.sh` | Cria um template do Debian 12 (Bookworm). | `debian-12-generic-amd64.qcow2` |
| `debian_13_template.sh` | Cria um template do Debian 13 (Trixie). | `debian-13-generic-amd64.qcow2` |
| `oracle_linux_8_template.sh` | Cria um template do Oracle Linux 8. | `OL8U9_x86_64-kvm-b166.qcow2` |
| `oracle_linux_9_template.sh` | Cria um template do Oracle Linux 9. | `OL9U4_x86_64-kvm-b183.qcow2` |
| `rhel_8_template.sh` | Cria um template do Red Hat Enterprise Linux 8. | `rhel-8.9-x86_64-kvm.qcow2` |
| `rhel_9_template.sh` | Cria um template do Red Hat Enterprise Linux 9. | `rhel-9.4-x86_64-kvm.qcow2` |
| `rocky_linux_9_template.sh` | Cria um template do Rocky Linux 9. | `Rocky-9-GenericCloud.latest.x86_64.qcow2` |
| `ubuntu_20_04_template.sh` | Cria um template do Ubuntu Server 20.04 (Focal Fossa). | `focal-server-cloudimg-amd64.img` |
| `ubuntu_22_04_template.sh` | Cria um template do Ubuntu Server 22.04 (Jammy Jellyfish). | `jammy-server-cloudimg-amd64.img` |
| `ubuntu_24_04_template.sh` | Cria um template do Ubuntu Server 24.04 (Noble Numbat). | `noble-server-cloudimg-amd64.img` |
| `ubuntu_26_04_template.sh` | Cria um template do Ubuntu Server 26.04 LTS (Resolute Raccoon). | `resolute-server-cloudimg-amd64.img` |

### 1. `alma_linux_9_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) AlmaLinux 9 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar de um sistema operacional robusto e 100% binário-compatível com RHEL 9 para implantações corporativas, servidores web ou laboratórios.

- **Recursos Principais**:
  - Download automático da imagem oficial genérica `AlmaLinux-9-GenericCloud-latest.x86_64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas de pós-instalação para comandos `dnf` e limpeza do sistema.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x alma_linux_9_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./alma_linux_9_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 2. `alpine_linux_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Alpine Linux utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar de uma máquina virtual incrivelmente leve, rápida e segura (baseada em musl libc e BusyBox) para rodar containers, proxies ou serviços minimalistas.

- **Recursos Principais**:
  - Download automático da imagem Cloud-Init (`nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2`).
  - Configuração da VM otimizada para recursos baixos: **1 CPU e 1GB de RAM**.
  - Permite a expansão do disco (recomendado: 5GB).
  - Instruções de pós-instalação para comandos `apk` (gerenciador de pacotes do Alpine) e configuração do QEMU Guest Agent.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x alpine_linux_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./alpine_linux_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 3. `centos_stream_9_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) CentOS Stream 9 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar provisionar rapidamente um ambiente Enterprise Linux que serve como "upstream" para o RHEL 9 (ideal para testar novidades do ecossistema Red Hat).

- **Recursos Principais**:
  - Download automático da imagem oficial genérica `CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas (com comandos `dnf`) de pré-configuração (GUI).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x centos_stream_9_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./centos_stream_9_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 4. `debian_10_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Debian 10 (Buster) utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Para provisionar VMs baseadas no Debian 10 (legado) com agilidade usando Cloud-Init, útil para compatibilidade de sistemas mais antigos.

- **Recursos Principais**:
  - Download automático da imagem oficial `debian-10-generic-amd64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas de pré-configuração (GUI) para definição de senhas e chaves SSH.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x debian_10_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./debian_10_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 5. `debian_11_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Debian 11 (Bullseye) utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Para provisionar VMs baseadas no Debian 11 (legado/estável) com agilidade usando Cloud-Init.

- **Recursos Principais**:
  - Download automático da imagem oficial `debian-11-generic-amd64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas de pré-configuração (GUI) para definição de senhas e chaves SSH.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x debian_11_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./debian_11_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 6. `debian_12_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Debian 12 (Bookworm) utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar criar uma base estável do Debian 12 para clonagem rápida via Cloud-Init.

- **Recursos Principais**:
  - Download automático da imagem oficial `debian-12-generic-amd64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware e rede para o Cloud-Init.
  - Instruções integradas de pré-configuração (GUI).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x debian_12_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./debian_12_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 7. `debian_13_template.sh`

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

### 8. `oracle_linux_8_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Oracle Linux 8 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar de um ambiente Enterprise Linux robusto baseado na geração 8, comumente exigido por versões específicas de bancos de dados ou softwares corporativos legados.

- **Recursos Principais**:
  - Download automático da imagem oficial genérica `OL8U9_x86_64-kvm-b166.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas de pós-instalação para comandos `dnf` e limpeza do sistema.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x oracle_linux_8_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./oracle_linux_8_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 9. `oracle_linux_9_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Oracle Linux 9 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar de um ambiente Enterprise Linux robusto, otimizado para bancos de dados Oracle ou como uma alternativa sólida e gratuita ao RHEL.

- **Recursos Principais**:
  - Download automático da imagem oficial genérica `OL9U4_x86_64-kvm-b183.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas de pós-instalação para comandos `dnf` e limpeza do sistema.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x oracle_linux_9_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./oracle_linux_9_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 10. `rhel_8_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Red Hat Enterprise Linux 8 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar provisionar um ambiente Enterprise Linux corporativo oficial para produção baseado na versão 8.

- **Recursos Principais**:
  - Tenta o download automático da imagem (pode requerer download manual dependendo da sua conta/token Red Hat).
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas (com comandos `dnf` e `subscription-manager`) de pré-configuração (GUI).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x rhel_8_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./rhel_8_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 11. `rhel_9_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Red Hat Enterprise Linux 9 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar provisionar rapidamente um ambiente Enterprise Linux corporativo oficial para produção.

- **Recursos Principais**:
  - Tenta o download automático da imagem (pode requerer download manual dependendo da sua conta/token Red Hat).
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas (com comandos `dnf` e `subscription-manager`) de pré-configuração (GUI).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x rhel_9_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./rhel_9_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 12. `rocky_linux_9_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Rocky Linux 9 utilizando Cloud-Init no Proxmox VE. 

- **Quando Utilizar**:
  Sempre que precisar provisionar rapidamente um ambiente Enterprise Linux estável (compatível bit-a-bit com RHEL 9) para laboratórios, testes ou produção.

- **Recursos Principais**:
  - Download automático da imagem oficial genérica `Rocky-9-GenericCloud.latest.x86_64.qcow2`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware para o Cloud-Init.
  - Instruções integradas (com comandos `dnf`) de pré-configuração (GUI).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x rocky_linux_9_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./rocky_linux_9_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 13. `ubuntu_20_04_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Ubuntu 20.04 (Focal Fossa) utilizando Cloud-Init no Proxmox VE.

- **Quando Utilizar**:
  Para projetos legados, sistemas antigos ou documentações corporativas que ainda exijam o provisionamento ágil de Ubuntu 20.04.

- **Recursos Principais**:
  - Download automático da imagem oficial `focal-server-cloudimg-amd64.img`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware necessárias para o Cloud-Init.
  - Opção interativa para revisar as configurações da VM via GUI antes de converter em template.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x ubuntu_20_04_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./ubuntu_20_04_template.sh
     ```
  3. Siga as instruções interativas na tela.

### 14. `ubuntu_22_04_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Ubuntu 22.04 (Jammy Jellyfish) utilizando Cloud-Init no Proxmox VE. O script gerencia o download da imagem oficial, criação da VM, importação do disco, configurações de hardware (virtio, boot, serial) e conversão final para template.

- **Quando Utilizar**:
  Ideal para provisionar rapidamente um template base do Ubuntu 22.04 pronto para ser clonado e configurado automaticamente via Cloud-Init em seu ambiente Proxmox.

- **Recursos Principais**:
  - Download automático da imagem oficial `jammy-server-cloudimg-amd64.img`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware necessárias para o Cloud-Init (virtio, porta serial, etc.).
  - Opção interativa para revisar as configurações da VM via GUI antes de converter definitivamente em template.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x ubuntu_22_04_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./ubuntu_22_04_template.sh
     ```
  3. Siga as instruções interativas na tela para configurar o template.

### 15. `ubuntu_24_04_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Ubuntu 24.04 (Noble Numbat) utilizando Cloud-Init no Proxmox VE.

- **Quando Utilizar**:
  Ideal para provisionar rapidamente um template base do Ubuntu 24.04 pronto para ser clonado e configurado automaticamente via Cloud-Init.

- **Recursos Principais**:
  - Download automático da imagem oficial `noble-server-cloudimg-amd64.img`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware necessárias para o Cloud-Init.
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

### 16. `ubuntu_26_04_template.sh`

- **Função**:
  Automatiza a criação de um template de máquina virtual (VM) Ubuntu 26.04 LTS (Resolute Raccoon) utilizando Cloud-Init no Proxmox VE.

- **Quando Utilizar**:
  Ideal para provisionar rapidamente um template base do novíssimo Ubuntu 26.04 LTS pronto para ser clonado e configurado via Cloud-Init.

- **Recursos Principais**:
  - Download automático da imagem diária oficial `resolute-server-cloudimg-amd64.img`.
  - Configuração interativa do ID, Nome, Storage e Tamanho do disco da VM.
  - Ajuste automático das configurações de hardware necessárias para o Cloud-Init.
  - Instruções de pós-instalação para comandos `apt` e limpeza do sistema.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x ubuntu_26_04_template.sh
     ```
  2. **Executar no nó Proxmox**:
     ```bash
     ./ubuntu_26_04_template.sh
     ```
  3. Siga as instruções interativas na tela.

## 🧹 Limpeza e Sanitização Pré-Template

Antes de converter uma VM em template, é **obrigatório** sanitizá-la para garantir que cada clone futuro seja gerado a partir de uma imagem "virgem", sem lixo de logs, histórico de comandos ou conflitos de identidade de máquina.

Para isso, após realizar as configurações manuais descritas na seção anterior, acesse a VM via SSH ou console e **execute o script de limpeza correspondente ao sistema operacional** da sua imagem. Os scripts estão localizados no diretório [`cleanup-images/`](./cleanup-images/):

| Script | Sistema Operacional |
| :--- | :--- |
| `cleanup-images/alpine-version.sh` | Alpine Linux |
| `cleanup-images/debian_versions.sh` | Debian |
| `cleanup-images/oracle-versions.sh` | Oracle Linux |
| `cleanup-images/rhel_versions.sh` | RHEL, AlmaLinux, Rocky Linux e CentOS |
| `cleanup-images/ubuntu_versions.sh` | Ubuntu |

Cada script realiza automaticamente as seguintes etapas e **desliga a VM ao final**:

- 📦 Instalação e habilitação do `qemu-guest-agent`.
- 🗑️ Limpeza dos logs do sistema e do Cloud-Init.
- 🕒 Remoção do histórico de comandos do shell.
- 🔄 Reset do `machine-id` para evitar conflitos de IP nos clones.

> 💡 Consulte o [`cleanup-images/README.md`](./cleanup-images/README.md) para mais detalhes e instruções de uso.

Após a VM ser desligada pelo script, você pode convertê-la com segurança em template via **botão direito → Convert to Template** no Proxmox.

---

## 🛡️ Pré-requisitos

- **Sistema Operacional**: Proxmox VE.
- **Acesso**: Acesso `root` no nó Proxmox VE (via Shell).
- **Conectividade**: Conexão com a internet para baixar as imagens cloud-init (Ubuntu/Debian/Rocky/AlmaLinux/Oracle).
- **Armazenamento**: Espaço suficiente no storage de destino para o disco da VM.

---

## 🛠️ Configurações Manuais Pós-Script (Opcional)

> 💡 **Como o Cloud-Init gerencia usuários nesses scripts?**
> Os scripts desta suíte **não injetam usuários, senhas ou chaves SSH** via código. Eles apenas preparam o hardware virtual e anexam o drive do Cloud-Init. Deixamos o template o mais genérico possível para que você possa definir credenciais diferentes para cada VM clonada. As configurações de usuário devem ser feitas diretamente na aba **Cloud-Init** do Proxmox, conforme os passos abaixo.

Se durante a execução interativa do script você optar por **NÃO** converter a VM em template imediatamente (respondendo `n` ou `N`), você terá a oportunidade de personalizar dados do Cloud-Init e instalar pacotes essenciais antes de convertê-la manualmente.

Recomendamos seguir os passos abaixo diretamente na interface web (GUI) do Proxmox:

1. **Acesse as opções Cloud-Init**: Selecione a VM criada (ex: `9004`) e vá até a aba **Cloud-Init**.
2. **Preencha os campos conforme necessário**:
   - **User**: O nome do usuário principal que será criado nas futuras VMs clonadas. Você pode colocar qualquer nome que quiser (ex: `admin`, `seu_nome`). No entanto, se você deseja manter a compatibilidade com o padrão adotado em provedores de nuvem pública (como a AWS), sugerimos os seguintes usuários padrão:
     - **Ubuntu**: `ubuntu`
     - **Debian**: `debian`
     - **Família Red Hat (RHEL, AlmaLinux, Rocky, CentOS)**: `cloud-user`
     - **Oracle Linux**: `opc`
     - **Alpine Linux**: `alpine`
   - **Password**: *sua_senha_forte* (senha de root/administrador do servidor).
   - **DNS Domain**: O domínio DNS que será usado para a VM (ex: `example.com` ou `domain.local`). Pode deixar em branco para usar o domínio padrão.
   - **DNS Servers**: Os servidores DNS que serão usados para a VM (ex: `8.8.8.8`, `1.1.1.1`). Pode deixar em branco para usar os servidores DNS padrão do Proxmox VE.
   - **SSH Public Key**: Cole o conteúdo da sua chave pública (`id_rsa.pub` ou similar). Se for adicionar múltiplas chaves, cole uma abaixo da outra.
   - **Upgrade Packages**: Se você quiser atualizar os pacotes da VM quando for convertida em template, marque esta opção. Caso contrário, deixe desmarcado.
   - **IP Config**: Geralmente deixamos em `DHCP` para que a VM receba um IP novo quando clonada.
3. ⚠️ **ATENÇÃO** ⚠️: Clique no botão **Regenerate Image** (no topo) para salvar as configurações do Cloud-Init no disco virtual.
4. **Redimensionamento de Disco (Opcional)**: Se o tamanho do disco sugerido na execução do script não for suficiente, você pode aumentá-lo agora:
   - Vá na aba **Hardware** da VM.
   - Selecione o **Hard Disk (virtio0)**.
   - Clique em **Disk Action** (no menu superior) e depois em **Resize**.
   - Insira quantos Gigabytes (GB) você quer adicionar (ex: para ir de 20GB para 50GB, digite `30`). O Cloud-Init expandirá a partição automaticamente no primeiro boot!
5. **Instalação do Agent e Limpeza**: Ligue a VM, acesse o Console e execute o **script de limpeza** correspondente ao sistema operacional, disponível em [`cleanup-images/`](./cleanup-images/). Ele irá instalar o `qemu-guest-agent`, limpar os logs, resetar o `machine-id`, apagar o histórico e **desligar a VM automaticamente** ao final.

   > ⚠️ **IMPORTANTE**: Não pule esta etapa! Executar o script de limpeza é fundamental para que os clones do template sejam gerados corretamente, sem conflitos de identidade de rede ou resíduos de configuração.
6. **Conversão**: Com a VM desligada (o script de limpeza fará isso automaticamente), clique com o botão direito na VM no Proxmox e selecione **Convert to Template**.

---

## 🚀 Como Criar uma VM a partir do Template (Full Clone)

Depois que o seu template estiver pronto, você nunca deve iniciá-lo diretamente. O processo correto é criar um clone desse template. Siga os passos abaixo na interface (GUI) do Proxmox:

1. Clique com o botão direito sobre o Template criado e selecione **Clone**.
2. Preencha os campos na janela que irá se abrir:
   - **VM ID**: Número de identificação da nova VM no Proxmox VE (geralmente gerado automaticamente).
   - **Name**: Hostname do servidor e nome da VM (ex: `prod-zabbix` ou `service-zabbix`).
   - **Mode**: Selecione obrigatoriamente a opção **"Full Clone"** (isso garante que o disco seja independente do template).
   - **Target Storage**: Local onde o disco da nova VM será armazenado (ex: `local-lvm` ou `local-zfs`).
   - **Format**: Formato do disco da VM. Por padrão, utilize **"QEMU image format (qcow2)"** ou deixe no padrão selecionado pelo Proxmox para o seu tipo de storage.
3. Clique em **Clone** e aguarde o processo finalizar.
4. Antes de ligar a nova VM, vá até a aba **Cloud-Init** dela e ajuste configurações como IP (se não for usar DHCP) ou senhas específicas, caso não tenha feito isso no template base.
5. Clique em **Regenerate Image** e ligue a VM!

---

## ⚠️ Notas Importantes

- A imagem baixada será armazenada no diretório `/var/lib/vz/template/iso`.
- A VM resultante será convertida em template e **não poderá ser iniciada diretamente**. Para utilizá-la, você deve criar um clone a partir deste template e então definir os parâmetros do Cloud-Init.
- 💡 **DICA DE OURO (Full Clone vs Linked Clone):** Quando for clonar o template para criar uma nova VM, escolha sempre a opção **"Full Clone"** (Clone Completo). Isso garante que a nova VM tenha seu próprio disco independente. Se você usar o *Linked Clone*, a nova VM ficará eternamente dependente do disco do template, o que pode causar problemas graves se você excluir ou alterar o template no futuro.
