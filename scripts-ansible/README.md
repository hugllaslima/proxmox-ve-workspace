# Automação de Configuração de Hosts para Ansible

Este diretório contém scripts para preparar hosts (VMs ou contêineres LXC) para serem gerenciados via automação com Ansible.

## Compatibilidade

- **Sistema Operacional**: Qualquer distribuição baseada em Debian, como:
  - Ubuntu (20.04 LTS, 22.04 LTS, 24.04 LTS e mais recentes)
  - Debian (10, 11, 12 e mais recentes)
  - Zorin OS
  - Pop!_OS
  - Linux Mint

---

## Estrutura do Diretório

```
scripts-ansible/
|-- README.md
`-- add_host_ansible.sh
```

---

## Descrição do Script

### `add_host_ansible.sh`

Este script interativo configura um usuário em um host de destino para permitir o acesso SSH via chave pública, que é o método de autenticação padrão e mais seguro para o Ansible.

#### O que o script faz?

- **Verificação de Dependências (Opcional):** Pergunta se o usuário deseja verificar e instalar `sudo` e `openssh-client` se não estiverem presentes.
- **Atualização do Sistema (Opcional):** Pergunta se o usuário deseja executar `apt update && apt upgrade`.
- **Seleção de Usuário de Destino:** Solicita o nome do usuário no host que será usado pelo Ansible para se conectar (ex: `ubuntu`, `debian`, `ansible`, `root`).
- **Validação do Usuário:** Verifica se o usuário informado realmente existe no sistema e se possui um diretório home válido.
- **Adição de Chave Pública:**
    - Solicita que o usuário cole a chave pública do nó de controle do Ansible.
    - Pede uma descrição para a chave, que será adicionada como um comentário no arquivo `authorized_keys`.
    - O comentário inclui a descrição, o nome do usuário que executou o script e a data/hora da adição (ex: `# Key for: Ansible Server (added by hugllas on 2025-10-20 15:30:00)`).
    - Valida o formato da chave SSH para evitar erros.
    - Verifica se a chave já existe para evitar duplicatas.
- **Configuração de Permissões:**
    - Cria o diretório `~/.ssh` se ele não existir.
    - Adiciona a chave pública e o comentário ao arquivo `~/.ssh/authorized_keys`.
    - Define as permissões de segurança corretas (`700` para `~/.ssh` e `600` para `~/.ssh/authorized_keys`).
    - Ajusta o proprietário dos arquivos e diretórios para o usuário de destino.

#### Quando utilizar?

Utilize este script durante o provisionamento de um novo servidor, VM ou contêiner que será gerenciado pelo Ansible. Ele é o primeiro passo para estabelecer a comunicação segura entre o nó de controle do Ansible e o host gerenciado.

#### Recursos Principais

- **Interatividade e Segurança:** O script pede confirmação para todas as ações críticas, evitando erros acidentais.
- **Flexibilidade:** Permite pular etapas de verificação e atualização, tornando-o útil em diferentes cenários.
- **Rastreabilidade:** Adiciona comentários detalhados às chaves SSH, facilitando a auditoria e o gerenciamento de chaves.
- **Validação Abrangente:** Realiza múltiplas verificações para garantir que o usuário, os diretórios e a chave estejam corretos antes de aplicar qualquer alteração.
- **Feedback Claro:** Fornece instruções detalhadas sobre os próximos passos, como a verificação da configuração do `sshd_config`.

#### Como Utilizar

1.  **Acesse o host de destino** (a máquina que será gerenciada pelo Ansible) via SSH ou console.
2.  **Copie o script** para o host.
3.  **Dê permissão de execução**:
    ```bash
    chmod +x add_host_ansible.sh
    ```
4.  **Execute o script com `sudo`**, pois ele precisa de privilégios para modificar arquivos em diretórios de outros usuários:
    ```bash
    sudo ./add_host_ansible.sh
    ```
5.  **Siga as instruções interativas:**
    - Responda se deseja verificar dependências e atualizar o sistema.
    - Informe o nome do usuário de destino.
    - Forneça uma descrição para a chave.
    - Cole a chave pública do seu servidor Ansible quando solicitado.

---

## Pré-requisitos

- Acesso `root` ou um usuário com privilégios `sudo` no host de destino.
- O host de destino deve ser baseado em Debian ou Ubuntu para que o gerenciador de pacotes `apt` funcione.
- Você deve ter a chave pública do seu nó de controle Ansible pronta para ser copiada.

## Pós-execução

Após executar o script, o host estará pronto para ser acessado pelo Ansible. Você pode testar a conexão a partir do seu nó de controle Ansible com o comando:

```bash
ansible -i <seu_inventario> <nome_do_host> -m ping
```

Ou testar o acesso SSH diretamente:

```bash
ssh -i /caminho/para/sua/chave_privada <usuario>@<ip_do_host>
```
