# 🏃‍♂️ Scripts para GitHub Self-Hosted Runner

Este diretório contém scripts para automatizar a instalação, configuração e gerenciamento de *runners* auto-hospedados (self-hosted) do GitHub, permitindo a execução de workflows de CI/CD em sua própria infraestrutura.

##  Compatibilidade

Os scripts são projetados para sistemas operacionais baseados em Debian que utilizam `systemd` como gerenciador de serviços. A compatibilidade foi testada e verificada nas seguintes distribuições:

- **Ubuntu**:
  - 24.04 LTS (Noble Numbat)
  - 22.04 LTS (Jammy Jellyfish)
  - 20.04 LTS (Focal Fossa)
- **Debian**:
  - 12 (Bookworm)
  - 11 (Bullseye)
  - 10 (Buster)

O principal requisito é a presença do gerenciador de pacotes `apt` e do `systemd`.

## 📜 Estrutura de Diretórios

```
scripts-self-hosted-runner/
├── setup_runner.sh
├── setup_runner_legacy.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `setup_runner.sh` (Recomendado)

- **Função**:
  Automatiza a instalação e configuração de um GitHub Self-Hosted Runner em uma máquina Linux (Ubuntu/Debian). Este script é a versão mais recente e robusta, com mais validações e interatividade.

- **Quando Utilizar**:
  Use este script para adicionar um novo runner a um repositório ou organização no GitHub. É ideal para ambientes que exigem controle total sobre o hardware e o software usado para executar jobs de CI/CD, como acesso a recursos locais, configurações de segurança específicas ou maior poder de processamento.

- **Recursos Principais**:
  - **Interatividade**: Solicita informações essenciais, como a URL do repositório/organização e o token de registro do runner.
  - **Download Automatizado**: Baixa a versão mais recente do agente do runner diretamente do GitHub.
  - **Verificação de Hash**: Valida a integridade do arquivo baixado comparando o checksum (SHA-256) com o fornecido pelo GitHub, garantindo que o software não foi corrompido.
  - **Instalação de Dependências**: Verifica e instala automaticamente as dependências necessárias (`curl`, `jq`, etc.).
  - **Configuração como Serviço**: Configura e habilita o runner para ser executado como um serviço do `systemd`, garantindo que ele inicie automaticamente com o sistema e seja reiniciado em caso de falha.
  - **Logs Detalhados**: Fornece feedback claro durante todo o processo de instalação.

- **Como Utilizar**:
  1. **Obter Token**: No GitHub, vá para **Settings > Actions > Runners > New self-hosted runner** e copie o token de registro.
  2. **Tornar o script executável**:
     ```bash
     chmod +x setup_runner.sh
     ```
  3. **Executar o script**:
     ```bash
     ./setup_runner.sh
     ```
  4. **Fornecer Informações**: Cole a URL do repositório/organização e o token quando solicitado pelo script.

### 2. `setup_runner_legacy.sh` (Legado)

- **Função**:
  Versão mais antiga e simplificada do script de instalação. Embora funcional, possui menos validações e recursos de automação.

- **Quando Utilizar**:
  Este script pode ser usado como referência ou em ambientes onde a interatividade não é desejada. No entanto, a **versão mais recente é fortemente recomendada** para novas instalações devido à sua robustez e segurança aprimorada.

- **Recursos Principais**:
  - **Download e Extração**: Baixa e descompacta o agente do runner.
  - **Configuração Básica**: Executa o script de configuração do runner, mas requer que o usuário passe o token e outras informações manualmente.
  - **Instalação do Serviço**: Instala o serviço do `systemd`.

- **Como Utilizar**:
  Este script geralmente requer edição manual para inserir a URL e o token antes da execução.

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Linux (distribuições baseadas em Debian, como Ubuntu ou o próprio Debian).
- **Acesso**: Um usuário com privilégios `sudo` para instalar o serviço.
- **Token do GitHub**: Um token de registro de runner válido obtido do seu repositório ou organização.
- **Conectividade**: Acesso à internet para baixar o agente do runner e se comunicar com o GitHub.

## 💡 Dicas e Boas Práticas

- **Segurança**: Execute o runner com um usuário dedicado e com privilégios mínimos. Evite usar o usuário `root`. O script `v2` já incentiva essa prática.
- **Runners Efêmeros**: Para maior segurança e consistência, considere configurar runners efêmeros, que são provisionados sob demanda para executar um único job e depois descartados. Isso pode ser orquestrado com ferramentas como Docker ou Terraform.
- **Manutenção**: Periodicamente, verifique se há novas versões do agente do runner e atualize-o para receber novos recursos e correções de segurança. O GitHub geralmente notifica sobre atualizações na interface de Actions.
- **Labels**: Use labels para direcionar workflows a runners específicos. Por exemplo, você pode ter um runner com GPU e aplicar a label `gpu` para que apenas jobs que necessitem de processamento gráfico sejam executados nele.
