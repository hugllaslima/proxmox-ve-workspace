# Automação de Scripts para o GitHub

Este diretório contém scripts para automatizar tarefas relacionadas ao GitHub e GitLab, como alternar entre diferentes contas de usuário (pessoal, trabalho, etc.) em repositórios locais.

## Compatibilidade

Os scripts deste diretório são compatíveis com qualquer sistema operacional que possua um ambiente de shell `bash` e o `git` instalado. Isso inclui:

- **Linux**: Qualquer distribuição (Ubuntu, Debian, Fedora, Arch, etc.).
- **macOS**: Qualquer versão com um terminal `bash` ou `zsh`.
- **Windows**: Utilizando o **Git Bash** (incluído na instalação do Git para Windows) ou o **Windows Subsystem for Linux (WSL)**.

Os scripts não possuem dependências de gerenciadores de pacotes específicos do sistema (`apt`, `yum`, etc.), tornando-os altamente portáteis.

## Estrutura do Diretório

```
scripts-git/
├── github_switcher.sh
├── gitlab_switcher.sh
├── README.md
└── sync-branchs.shREADME.md
```

---

## Descrição dos Scripts

### `gitlab_switcher.sh`

O `gitlab_switcher.sh` é um script interativo projetado para simplificar o gerenciamento de múltiplas contas Git/GitLab em um ambiente de desenvolvimento local. Ele automatiza a configuração de credenciais de commit e a URL do `remote 'origin'` para garantir que você esteja usando a identidade e a chave SSH corretas para cada repositório.

#### O que o script faz?

- **Gerenciamento de Contas**: Permite adicionar, editar, remover e listar múltiplas contas Git/GitLab, armazenando as informações de forma segura em um arquivo de configuração local (`~/.gitlab_switcher_accounts.conf`).
- **Configuração de Repositório**: Altera as configurações `user.name` e `user.email` do repositório Git local para corresponder à conta selecionada.
- **Gerenciamento de SSH**: Atualiza dinamicamente o arquivo `~/.ssh/config` para associar um host SSH exclusivo a cada conta, garantindo que a chave SSH correta seja usada para autenticação no GitLab.
- **Atualização de Remote**: Modifica a URL do `remote 'origin'` para usar o host SSH configurado, permitindo a comunicação transparente com o GitLab.

#### Quando utilizar?

Este script é ideal para desenvolvedores que trabalham com múltiplas identidades no GitLab, como:
- Freelancers com contas de clientes diferentes.
- Profissionais que separam suas contas pessoais e de trabalho.
- Colaboradores de projetos de código aberto que precisam alternar entre diferentes perfis.

#### Recursos Principais

- **Interativo e Guiado**: O script oferece um menu de fácil utilização para guiar o usuário através das opções disponíveis.
- **Configuração Centralizada**: Armazena todas as informações de conta em um único arquivo, facilitando o backup e a migração.
- **Gerenciamento Automatizado de SSH**: Evita a necessidade de editar manualmente o arquivo `~/.ssh/config`, reduzindo o risco de erros.
- **Flexibilidade**: Permite configurar um repositório existente ou gerenciar as contas de forma independente.

#### Como Utilizar

1. **Tornar o script executável**:
   ```bash
   chmod +x gitlab_switcher.sh
   ```
2. **Executar o script**:
   ```bash
   ./gitlab_switcher.sh
   ```
3. **Seguir as instruções do menu**:
   - Para configurar um repositório, navegue até o diretório raiz do projeto antes de executar o script.
   - Use as opções do menu para adicionar suas contas, fornecendo um nome, e-mail, host SSH, usuário GitLab e o caminho para a chave pública SSH correspondente.
   - Após configurar as contas, use a opção para "Configurar/Alternar conta em um repositório" para aplicar a identidade desejada.

#### Pré-requisitos

- **Chaves SSH**: Você deve ter um par de chaves SSH (pública e privada) para cada conta GitLab que deseja gerenciar.
- **GitLab Configurado**: A chave pública de cada conta deve ser adicionada à respectiva conta no GitLab.

---
