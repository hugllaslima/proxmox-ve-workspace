# ☁️ Scripts de Template Cloud-Init

Este diretório contém scripts para automatizar a criação de templates de máquinas virtuais (VMs) utilizando Cloud-Init no Proxmox VE.

## 📜 Estrutura de Diretórios

```text
scripts-template-cloud-init/
├── debian_10_template.sh
├── debian_11_template.sh
├── debian_12_template.sh
├── debian_13_template.sh
├── ubuntu_20_04_template.sh
├── ubuntu_22_04_template.sh
├── ubuntu_24_04_template.sh
├── ubuntu_26_04_template.sh
├── alma_linux_9_template.sh
├── rocky_linux_9_template.sh
└── README.md
```

## 🚀 Scripts Disponíveis

| Script | Descrição | Imagem Base |
| :--- | :--- | :--- |
| `debian_10_template.sh` | Cria um template do Debian 10 (Buster). | `debian-10-generic-amd64.qcow2` |
| `debian_11_template.sh` | Cria um template do Debian 11 (Bullseye). | `debian-11-generic-amd64.qcow2` |
| `debian_12_template.sh` | Cria um template do Debian 12 (Bookworm). | `debian-12-generic-amd64.qcow2` |
| `debian_13_template.sh` | Cria um template do Debian 13 (Trixie). | `debian-13-generic-amd64.qcow2` |
| `ubuntu_20_04_template.sh` | Cria um template do Ubuntu Server 20.04 (Focal Fossa). | `focal-server-cloudimg-amd64.img` |
| `ubuntu_22_04_template.sh` | Cria um template do Ubuntu Server 22.04 (Jammy Jellyfish). | `jammy-server-cloudimg-amd64.img` |
| `ubuntu_24_04_template.sh` | Cria um template do Ubuntu Server 24.04 (Noble Numbat). | `noble-server-cloudimg-amd64.img` |
| `ubuntu_26_04_template.sh` | Cria um template do Ubuntu Server 26.04 LTS (Resolute Raccoon). | `resolute-server-cloudimg-amd64.img` |
| `alma_linux_9_template.sh` | Cria um template do AlmaLinux 9. | `AlmaLinux-9-GenericCloud-latest.x86_64.qcow2` |
| `rocky_linux_9_template.sh` | Cria um template do Rocky Linux 9. | `Rocky-9-GenericCloud.latest.x86_64.qcow2` |

### 1. `debian_10_template.sh`

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

### 2. `debian_11_template.sh`

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

### 3. `debian_12_template.sh`

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

### 4. `debian_13_template.sh`

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

### 5. `ubuntu_20_04_template.sh`

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

### 6. `ubuntu_22_04_template.sh`

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

### 7. `ubuntu_24_04_template.sh`

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

### 8. `ubuntu_26_04_template.sh`

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

### 9. `alma_linux_9_template.sh`

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

### 10. `rocky_linux_9_template.sh`

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

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Proxmox VE.
- **Acesso**: Acesso `root` no nó Proxmox VE (via Shell).
- **Conectividade**: Conexão com a internet para baixar as imagens cloud-init (Ubuntu/Debian/Rocky/AlmaLinux).
- **Armazenamento**: Espaço suficiente no storage de destino para o disco da VM.

---

## 🛠️ Configurações Manuais Pós-Script (Opcional)

Se durante a execução interativa do script você optar por **NÃO** converter a VM em template imediatamente (respondendo `n` ou `N`), você terá a oportunidade de personalizar dados do Cloud-Init e instalar pacotes essenciais antes de convertê-la manualmente.

Recomendamos seguir os passos abaixo diretamente na interface web (GUI) do Proxmox:

1. **Acesse as opções Cloud-Init**: Selecione a VM criada (ex: `9004`) e vá até a aba **Cloud-Init**.
2. **Preencha os campos conforme necessário**:
   - **User**: O nome do usuário principal que será criado nas futuras VMs clonadas. Você pode colocar qualquer nome que quiser (ex: `admin`, `seu_nome`, `nome_da_distro`). Como *exemplo padrão*, as imagens costumam usar o nome da distro: `debian`, `ubuntu`, `rocky` ou `almalinux`.
   - **Password**: *sua_senha_forte* (senha de root/administrador do servidor).
   - **DNS Domain**: O domínio DNS que será usado para a VM (ex: `example.com` ou `domain.local`). Pode deixar em branco para usar o domínio padrão.
   - **DNS Servers**: Os servidores DNS que serão usados para a VM (ex: `8.8.8.8`, `1.1.1.1`). Pode deixar em branco para usar os servidores DNS padrão do Proxmox VE.
   - **SSH Public Key**: Cole o conteúdo da sua chave pública (`id_rsa.pub` ou similar). Se for adicionar múltiplas chaves, cole uma abaixo da outra.
   - **Upgrade Packages**: Se você quiser atualizar os pacotes da VM quando for convertida em template, marque esta opção. Caso contrário, deixe desmarcado.
   - **IP Config**: Geralmente deixamos em `DHCP` para que a VM receba um IP novo quando clonada.
3. ⚠️ **ATENÇÃO** ⚠️: Clique no botão **Regenerate Image** (no topo) para salvar as configurações do Cloud-Init no disco virtual.
4. **Instalação do QEMU Guest Agent**: Ligue a VM, acesse o Console e rode o comando de instalação para garantir comunicação perfeita com o Proxmox.
   - Para distros baseadas em **Debian/Ubuntu**:
     ```bash
     sudo apt update && sudo apt install qemu-guest-agent -y
     ```
   - Para distros baseadas em **RedHat/AlmaLinux/Rocky Linux**:
     Atenção: nestas distribuições é recomendável atualizar todo o sistema antes de gerar o template.
     ```bash
     sudo dnf update -y
     sudo dnf install qemu-guest-agent -y
     ```
5. **Limpeza de Logs e Histórico**: Antes de desligar a VM, limpe os logs do sistema e o histórico de comandos do terminal para que o template fique "virgem" e não repasse lixo ou histórico para as futuras VMs clonadas:
   - Para **qualquer distribuição (Debian/Ubuntu/AlmaLinux/Rocky)**:
     ```bash
     sudo truncate -s 0 /var/log/*.log
     history -c && history -w
     ```
6. **Prepare para Template**: Desligue a VM (`sudo poweroff` ou via Proxmox).
7. **Conversão**: Clique com o botão direito na VM e selecione **Convert to Template**.

---

## 🔒 Notas Importantes

- A imagem baixada será armazenada no diretório `/var/lib/vz/template/iso`.
- A VM resultante será convertida em template e **não poderá ser iniciada diretamente**. Para utilizá-la, você deve criar um clone a partir deste template e então definir os parâmetros do Cloud-Init.
- 💡 **DICA DE OURO (Full Clone vs Linked Clone):** Quando for clonar o template para criar uma nova VM, escolha sempre a opção **"Full Clone"** (Clone Completo). Isso garante que a nova VM tenha seu próprio disco independente. Se você usar o *Linked Clone*, a nova VM ficará eternamente dependente do disco do template, o que pode causar problemas graves se você excluir ou alterar o template no futuro.
