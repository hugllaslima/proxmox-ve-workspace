# 📦 Instalação Automatizada do Antigravity

Este diretório contém scripts para automatizar a instalação e configuração do **Antigravity** em sistemas baseados em Debian e Ubuntu. O objetivo é simplificar o processo de adição de repositórios, chaves de segurança e instalação do pacote, garantindo um ambiente pronto para uso em poucos segundos.

## 🚀 Funcionalidades

O script `install_antigravity.sh` executa as seguintes tarefas automaticamente:

1.  **Verificação de Ambiente**: Confirma se o usuário possui permissões de superusuário (sudo).
2.  **Configuração de Repositório**:
    *   Baixa e instala a chave GPG oficial de assinatura do repositório.
    *   Adiciona o repositório oficial do Antigravity à lista de fontes do APT (`/etc/apt/sources.list.d/`).
3.  **Instalação**: Atualiza o cache do APT e instala o pacote `antigravity`.

## 📋 Pré-requisitos

Para utilizar este script, você precisará de:

*   Um sistema operacional compatível:
    *   Debian (versões recentes)
    *   Ubuntu (versões recentes)
    *   Linux Mint
    *   Outros derivados baseados em Debian
*   Conexão com a Internet.
*   Permissões de `sudo` no sistema.
*   Pacotes `curl` e `gpg` instalados (geralmente presentes por padrão).

## 🛠️ Como Utilizar

Siga os passos abaixo para realizar a instalação:

1.  **Baixe ou navegue até o diretório do script**:
    ```bash
    cd scripts-antigravity
    ```

2.  **Dê permissão de execução ao script**:
    ```bash
    chmod +x install_antigravity.sh
    ```

3.  **Execute o instalador**:
    ```bash
    sudo ./install_antigravity.sh
    ```

O script fornecerá feedback visual passo a passo sobre o progresso da instalação.

## 📜 Scripts Disponíveis

| Arquivo | Descrição |
| :--- | :--- |
| `install_antigravity.sh` | Script principal que gerencia todo o processo de instalação do repositório e do pacote. |

## 👨‍💻 Autor

**Hugllas R S Lima**

- **GitHub:** [@hugllaslima](https://github.com/hugllaslima)
- **LinkedIn:** [hugllas-lima](https://www.linkedin.com/in/hugllas-lima/)
