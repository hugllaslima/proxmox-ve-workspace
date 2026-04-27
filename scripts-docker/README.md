# 🐳 Scripts de Instalação do Docker

Este diretório contém scripts para automatizar a instalação e configuração do Docker e Docker Compose em distribuições baseadas em Debian, como Ubuntu e Zorin OS.

## 📜 Estrutura de Diretórios

```
docker/
├── install_docker_full_ubuntu_server.sh
├── install_docker_full_ubuntu.sh
├── install_docker_full_zorin.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `install_docker_full_ubuntu_server.sh` (Recomendado para Servidores Ubuntu)

- **Função**:
  Realiza a instalação completa e moderna do Docker Engine e do Docker Compose V2 em servidores **Ubuntu**. Este script utiliza os métodos de instalação mais recentes recomendados pela documentação oficial do Docker.

- **Compatibilidade**:
  - Ubuntu Server 20.04 LTS (Focal Fossa)
  - Ubuntu Server 22.04 LTS (Jammy Jellyfish)
  - Ubuntu Server 24.04 LTS (Noble Numbat)

- **Recursos Principais**:
  - Utiliza o método seguro de `gpg --dearmor` para a chave GPG do Docker (substituindo o `apt-key` obsoleto).
  - Instala o plugin `docker-compose` (V2) via `apt`, que é a abordagem moderna.
  - Adiciona o repositório oficial do Docker de forma segura.
  - Instala a última versão estável do Docker Engine (`docker-ce`), CLI (`docker-ce-cli`) e `containerd.io`.
  - Adiciona o usuário atual ao grupo `docker` para permitir a execução de comandos sem `sudo`.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_docker_full_ubuntu_server.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_docker_full_ubuntu_server.sh
     ```

### 2. `install_docker_full_zorin.sh`

- **Função**:
  Realiza a instalação completa do Docker e do Docker Compose em sistemas **Zorin OS** e outros derivados do Ubuntu (como Pop!_OS, Linux Mint).

- **Quando Utilizar**:
  Ideal para ambientes de desktop ou desenvolvimento baseados em Zorin OS que precisam de um ambiente Docker funcional. O script adapta os passos de instalação para garantir compatibilidade.

- **Recursos Principais**:
  - Remove versões antigas ou não oficiais do Docker para evitar conflitos.
  - Executa as mesmas etapas do script para Ubuntu, garantindo uma instalação padronizada.
  - Otimiza a configuração para sistemas de desktop, se necessário.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_docker_full_zorin.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_docker_full_zorin.sh
     ```

### 3. `install_docker_full_ubuntu.sh` (Legado)

- **Função**:
  Realiza a instalação do Docker e do Docker Compose V1 em servidores **Ubuntu**.

- **Quando Utilizar**:
  Este script utiliza métodos mais antigos (`apt-key` e download do binário do Compose V1 com `curl`). Pode ser útil para sistemas legados ou para manter a compatibilidade com ambientes que ainda dependem do `docker-compose` V1. **Para novas instalações, o uso de `install_docker_full_ubuntu_server.sh` é fortemente recomendado.**

- **Recursos Principais**:
  - Usa `apt-key` para adicionar a chave GPG (método obsoleto).
  - Baixa e instala o binário do `docker-compose` (V1) a partir do GitHub.
  - Configura o repositório oficial do Docker e instala o Docker Engine.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_docker_full_ubuntu.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_docker_full_ubuntu.sh
     ```

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Ubuntu Server ou Zorin OS.
- **Acesso**: Permissões de `root` ou um usuário com privilégios `sudo`.
- **Conectividade**: Acesso à internet para download dos pacotes e chaves de repositório.

## 🔒 Notas de Segurança

- **Revisão de Código**: É sempre uma boa prática revisar o conteúdo de qualquer script antes de executá-lo com privilégios de superusuário.
- **Grupo Docker**: Adicionar um usuário ao grupo `docker` concede privilégios equivalentes ao de `root`. Certifique-se de que apenas usuários confiáveis tenham esse acesso. Após a execução do script, é necessário fazer logout e login novamente para que a alteração no grupo tenha efeito.
