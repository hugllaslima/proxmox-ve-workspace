# 🤖 Scripts de Automação para Máquinas Virtuais (VMs) em Proxmox

Este diretório contém scripts para automatizar a criação, configuração e gerenciamento de Máquinas Virtuais (VMs) no ambiente de virtualização **Proxmox VE**.

##  compatibilidade

| Script | Sistema Operacional (Host) | Sistema Operacional (Guest) | Arquitetura | Dependências |
| ------------------------------- | -------------------------- | --------------------------- | ----------- | ------------------------------------------------------------------ |
| `create_vm.sh` | Proxmox VE (baseado em Debian) | N/A | `amd64` | `bash`, `pvesh`, `pvesm`, `qm`, `jq` (recomendado) |
| `create_vm_v2.sh` | Proxmox VE (baseado em Debian) | N/A | `amd64` | `bash`, `pvesh`, `pvesm`, `qm`, `jq` (recomendado) |
| `ubuntu_full_config_pve.sh` | N/A | Ubuntu 20.04+ | `amd64` | `bash`, `systemd`, `apt`, `curl`, `sudo` |

---

## 📜 Estrutura de Diretórios

```
scripts-vms/
├── create_vm.sh
├── create_vm_v2.sh
├── ubuntu_full_config_pve.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `create_vm.sh` (Legado)

- **Função**:
  Script interativo para criar uma nova Máquina Virtual (VM) no Proxmox VE. Ele guia o usuário através de um processo de perguntas e respostas para definir as configurações da VM.
- **Recursos Principais**:
  - Coleta interativa de ID, nome, RAM, CPU e tamanho do disco.
  - Seleção de storage para o disco.
  - Seleção do tipo de sistema operacional (Linux, Windows, Outro).
  - Anexo opcional de uma imagem ISO para instalação.
- **Quando Utilizar**:
  Para criações rápidas e pontuais de VMs onde uma interação manual é aceitável. **Recomenda-se o uso do `create_vm_v2.sh` para uma experiência aprimorada.**

### 2. `create_vm_v2.sh` (Recomendado)

- **Função**:
  Versão aprimorada do `create_vm.sh`, com validações avançadas, melhor tratamento de erros e uma interface de usuário mais robusta.
- **Recursos Principais**:
  - Todas as funcionalidades do script legado.
  - **Listagem Inteligente**: Lista automaticamente os storages disponíveis para discos (`images`) e ISOs (`iso`).
  - **Validação Aprimorada**: Verifica o formato do tamanho do disco (G/M) e a disponibilidade de IDs.
  - **Instalação de Dependências**: Oferece a instalação do `jq` se não estiver presente.
- **Como Utilizar**:
  1. **Conectar ao nó Proxmox**:
     ```bash
     ssh root@seu-no-proxmox
     ```
  2. **Tornar o script executável**:
     ```bash
     chmod +x create_vm_v2.sh
     ```
  3. **Executar o script**:
     ```bash
     ./create_vm_v2.sh
     ```
  4. **Fornecer as Informações**: Siga as instruções interativas para configurar a nova VM.

### 3. `ubuntu_full_config_pve.sh`

- **Função**:
  Script de pós-instalação para ser executado **dentro de uma VM Ubuntu Server recém-criada**. Ele automatiza a configuração completa do sistema para otimizá-lo para o ambiente Proxmox e para uso geral.
- **Recursos Principais**:
  - **Configuração do Sistema**: Ajusta o fuso horário e atualiza todos os pacotes.
  - **QEMU Guest Agent**: Instala e habilita o `qemu-guest-agent` para melhor integração com o host Proxmox.
  - **Segurança SSH (Opcional)**: Oferece a configuração de acesso via chave SSH. Se ativado, a autenticação por senha é desabilitada para aumentar a segurança.
  - **Usuário Sudo**: Concede permissões `sudo` sem senha a um usuário padrão (`ubuntu`).
  - **Instalação de Ferramentas (Opcional)**: Oferece a instalação do Docker e Docker Compose.
- **Como Utilizar**:
  1. **Copiar para a VM**: Após criar uma VM Ubuntu, copie este script para dentro dela.
     ```bash
     scp ubuntu_full_config_pve.sh ubuntu@ip-da-vm:/home/ubuntu/
     ```
  2. **Executar na VM**:
     ```bash
     ssh ubuntu@ip-da-vm
     sudo bash /home/ubuntu/ubuntu_full_config_pve.sh
     ```

## ⚠️ Pré-requisitos

- **Para `create_vm` e `create_vm_v2`**:
  - Acesso `root` a um nó do cluster Proxmox VE.
  - Storages devidamente configurados no Proxmox para armazenar imagens de disco e ISOs.
- **Para `ubuntu_full_config_pve.sh`**:
  - Uma VM com Ubuntu Server (20.04 ou superior) em execução.
  - Acesso `sudo` ou `root` dentro da VM.
