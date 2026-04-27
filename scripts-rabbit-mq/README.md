# 🐇 Scripts de Gerenciamento do RabbitMQ

Este diretório contém scripts para instalar, reconfigurar e remover o **RabbitMQ**, um message broker de código aberto amplamente utilizado em arquiteturas de microsserviços e sistemas distribuídos.

## 📜 Estrutura de Diretórios

```
rabbit-mq/
├── install_rabbit_mq.sh
├── reconfigure_rabbit_mq.sh
├── cleanup_rabbit_mq.sh
└── README.md
```

## Compatibilidade

Os scripts deste diretório são compatíveis com as seguintes distribuições Linux baseadas em Debian:

- **Ubuntu Server**: 22.04 LTS, 24.04 LTS
- **Debian**: 11, 12

A recomendação oficial é utilizar **Ubuntu Server 24.04 LTS** para garantir a melhor compatibilidade com as dependências do Erlang e RabbitMQ.



### 1. `install_rabbit_mq.sh`

- **Função**:
  Realiza a instalação e configuração completas do **RabbitMQ Server** em distribuições baseadas em Debian/Ubuntu.

- **Quando Utilizar**:
  Use este script para configurar um servidor RabbitMQ do zero. É ideal para ambientes que precisam de um message broker robusto, como pré-requisito para aplicações como o OnlyOffice Document Server em modo cluster.

- **Recursos Principais**:
  - Adiciona os repositórios oficiais do RabbitMQ e do Erlang (sua principal dependência).
  - Importa as chaves GPG para garantir a autenticidade dos pacotes.
  - Instala as versões mais recentes e compatíveis do `erlang` e `rabbitmq-server`.
  - Habilita o serviço `rabbitmq-server` para iniciar automaticamente com o sistema.
  - Cria um usuário administrador com uma senha segura gerada aleatoriamente.
  - Configura as permissões (`vhost`) para o novo usuário.
  - Habilita o **RabbitMQ Management Plugin**, que fornece uma interface web para monitoramento e gerenciamento.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_rabbit_mq.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_rabbit_mq.sh
     ```
  3. **Acessar a Interface de Gerenciamento**:
     Abra `http://<ip-do-servidor>:15672` em um navegador e faça login com o usuário `admin` e a senha fornecida no final da execução do script.

### 2. `reconfigure_rabbit_mq.sh`

- **Função**:
  Permite redefinir a senha do usuário administrador do RabbitMQ e reiniciar o serviço.

- **Quando Utilizar**:
  Use este script se você perdeu a senha do usuário `admin` ou precisa alterá-la por motivos de segurança. Ele automatiza o processo de alteração de senha e garante que o serviço seja reiniciado corretamente.

- **Recursos Principais**:
  - Gera uma nova senha segura.
  - Utiliza `rabbitmqctl` para alterar a senha do usuário `admin`.
  - Reinicia o serviço `rabbitmq-server` para aplicar a alteração.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x reconfigure_rabbit_mq.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./reconfigure_rabbit_mq.sh
     ```

### 3. `cleanup_rabbit_mq.sh`

- **Função**:
  Remove completamente a instalação do RabbitMQ Server e do Erlang.

- **Quando Utilizar**:
  Execute este script para desinstalar o RabbitMQ e todas as suas dependências de forma limpa. É útil para migrar para uma nova versão, solucionar problemas de instalação corrompida ou liberar recursos do servidor.

- **Recursos Principais**:
  - Para o serviço `rabbitmq-server`.
  - Remove os pacotes `rabbitmq-server`, `erlang*` e dependências associadas.
  - Exclui os diretórios de dados e logs do RabbitMQ (`/var/lib/rabbitmq/`, `/var/log/rabbitmq/`).
  - Limpa o cache de pacotes do APT.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x cleanup_rabbit_mq.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./cleanup_rabbit_mq.sh
     ```

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Distribuição baseada em Debian (Ubuntu Server recomendado).
- **Acesso**: Permissões de `root` ou um usuário com privilégios `sudo`.
- **Conectividade**: Acesso à internet para download dos pacotes.

## 🔒 Notas de Segurança

- **Senha do Administrador**: A senha gerada pelo script de instalação é exibida no final da execução. Armazene-a em um local seguro. Se perdida, utilize o script `reconfigure_rabbit_mq.sh`.
- **Firewall**: Certifique-se de que as portas do RabbitMQ estejam devidamente protegidas. As portas padrão são:
  - `5672` (AMQP, para comunicação de clientes)
  - `15672` (HTTP, para a interface de gerenciamento)
  - `25672` (para comunicação entre nós do cluster)
  Configure o firewall para permitir acesso apenas de fontes confiáveis.
