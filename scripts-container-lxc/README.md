# Automação de Gerenciamento de Contêineres LXC no Proxmox VE

Este diretório contém scripts para automatizar a criação e configuração de usuários dentro de contêineres LXC no Proxmox VE.

## Estrutura do Diretório

```
scripts-container-lxc/
|-- README.md
|-- create_user_lxc.sh
`-- create_user_lxc_2.sh
```

---

## Compatibilidade

Os scripts deste diretório são projetados para serem executados dentro de **Contêineres LXC** baseados em distribuições Linux que utilizam o gerenciador de pacotes `apt`.

- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Debian**: 10, 11, 12

Embora possam funcionar em outras distribuições baseadas em Debian, a compatibilidade é garantida para as versões listadas acima.



### 1. `create_user_lxc.sh`

Este script automatiza a criação e configuração de um novo usuário em um contêiner LXC, garantindo que ele tenha as permissões necessárias para administração.

#### 1.1. O que o script faz?

- **Ajusta o fuso horário** para `America/Sao_Paulo`.
- **Atualiza o sistema operacional** (`apt update && apt upgrade`).
- **Instala dependências essenciais**, como `sudo` e `openssh-client`, se não estiverem presentes.
- **Cria um novo usuário** com base no nome fornecido interativamente.
- **Adiciona o usuário aos grupos** `sudo` e, se disponíveis, `lxc` ou `lxd`.
- **Configura o `sudo` para não exigir senha** para o novo usuário, facilitando a administração (ideal para ambientes de laboratório).
- **Oferece a opção de reiniciar o contêiner** ao final da execução.

#### 1.2. Quando utilizar?

Utilize este script para uma configuração rápida e direta de um novo usuário administrador em um contêiner LXC recém-criado ou que ainda não possui um usuário dedicado para gerenciamento.

#### 1.3. Recursos Principais

- **Criação Rápida:** Automatiza todo o processo de criação e configuração de um usuário.
- **Verificação de Dependências:** Garante que `sudo` e `openssh-client` estejam instalados.
- **Permissões Elevadas:** Concede permissões de superusuário sem senha, ideal para automação e gerenciamento simplificado.

#### 1.4. Como Utilizar

1.  **Acesse o contêiner LXC** como `root`.
2.  **Copie o script** para dentro do contêiner.
3.  **Dê permissão de execução**:
    ```bash
    chmod +x create_user_lxc.sh
    ```
4.  **Execute o script**:
    ```bash
    ./create_user_lxc.sh
    ```
5.  **Siga as instruções** para fornecer o nome do novo usuário e decidir sobre a reinicialização.

---

### 2. `create_user_lxc_2.sh`

Esta é uma versão aprimorada e mais interativa do script anterior, oferecendo maior controle sobre as etapas de configuração.

#### 2.1. O que o script faz?

- **Ajusta o fuso horário** para `America/Sao_Paulo`.
- **Pergunta ao usuário** se deseja:
    - Atualizar o sistema operacional.
    - Instalar o pacote `sudo`.
    - Instalar o pacote `openssh-client`.
- **Verifica se o usuário já existe** antes de tentar criá-lo.
- **Cria um novo usuário** e o adiciona aos grupos `sudo`, `lxc` ou `lxd` (se existentes).
- **Configura `sudo` sem senha** (com um aviso de que é seguro apenas para ambientes de laboratório).
- **Oferece a opção de reiniciar o contêiner** ao final.

#### 2.2. Quando utilizar?

Use esta versão quando precisar de mais controle sobre o processo de configuração. É ideal para ambientes onde você pode não querer executar todas as etapas (por exemplo, pular a atualização do sistema) ou quando precisa de uma verificação de segurança para evitar a duplicação de usuários.

#### 2.3. Recursos Principais

- **Interatividade:** Permite ao usuário escolher quais ações executar.
- **Validação de Usuário:** Impede a criação de um usuário que já existe.
- **Modularidade:** As etapas de instalação e atualização são opcionais.
- **Feedback Detalhado:** Fornece mensagens claras sobre cada ação executada ou pulada.

#### 2.4. Como Utilizar

1.  **Acesse o contêiner LXC** como `root`.
2.  **Copie o script** para dentro do contêiner.
3.  **Dê permissão de execução**:
    ```bash
    chmod +x create_user_lxc_2.sh
    ```
4.  **Execute o script**:
    ```bash
    ./create_user_lxc_2.sh
    ```
5.  **Responda às perguntas** (`s` para sim, `n` para não) para guiar o processo de configuração.

---

## Pré-requisitos

- Acesso `root` ao contêiner LXC.
- O contêiner deve ser baseado em Debian ou Ubuntu para que o gerenciador de pacotes `apt` funcione corretamente.

## Dicas

- **Segurança:** A configuração de `sudo` sem senha (`NOPASSWD`) é conveniente para automação e laboratórios, mas não é recomendada para ambientes de produção.
- **Versão Legada:** O script `create_user_lxc.sh` pode ser considerado uma versão mais antiga, enquanto `create_user_lxc_2.sh` é a versão recomendada por sua flexibilidade e segurança aprimorada.
