# Proxmox VE Automation Suite

<p align="center">
  <img src="https://img.shields.io/github/license/hugllaslima/proxmox-ve-workspace?style=for-the-badge" alt="Licença">
  <img src="https://img.shields.io/github/stars/hugllaslima/proxmox-ve-workspace?style=for-the-badge" alt="Estrelas">
  <img src="https://img.shields.io/github/forks/hugllaslima/proxmox-ve-workspace?style=for-the-badge" alt="Forks">
</p>

Bem-vindo à **Proxmox VE Automation Suite**, uma coleção completa de scripts de automação projetados para simplificar o gerenciamento, a configuração e a manutenção de infraestruturas de virtualização baseadas em Proxmox VE ou outro virtualizador bare-metal.

---

## 📖 Índice

- [🎯 Por que usar este projeto?](#por-que-usar-este-projeto)
- [📁 Estrutura de Scripts](#estrutura-de-scripts)
- [🚀 Primeiros Passos](#primeiros-passos)
- [💡 Casos de Uso](#casos-de-uso)
- [🛡️ Segurança em Primeiro Lugar](#segurança-em-primeiro-lugar)
- [🤝 Como Contribuir](#como-contribuir)
- [📄 Licença](#licença)
- [👨‍💻 Autor](#autor)

---

## 🎯 Por que usar este projeto?

Gerenciar um ambiente de virtualização pode ser complexo e repetitivo. Esta suíte de scripts foi criada para resolver esses desafios, oferecendo:

- **Automação Inteligente:** Scripts interativos que validam dados, tratam erros e fornecem feedback claro.
- **Padronização:** Garanta que todas as suas VMs e contêineres sejam configurados de maneira consistente.
- **Economia de Tempo:** Reduza horas de trabalho manual em tarefas como provisionamento, configuração e manutenção.
- **Segurança Aprimorada:** Scripts que seguem boas práticas, como configuração de chaves SSH, permissões de arquivos e backups.

---

## 📁 Estrutura de Scripts

Os scripts são organizados em diretórios modulares, cada um com seu próprio `README.md` detalhado.

| Categoria | Diretório | Descrição |
| :--- | :--- | :--- |
| **Gestão de VMs** | [`scripts-vms/`](./scripts-vms) | Criação e configuração completa de VMs Ubuntu e derivados. |
| **Gestão de Contêineres** | [`scripts-container-lxc/`](./scripts-container-lxc) | Criação e configuração de usuários em contêineres LXC. |
| **Docker** | [`scripts-docker/`](./scripts-docker) | Instalação e configuração do Docker em diferentes sistemas. |
| **OnlyOffice Server** | [`scripts-onlyoffice-server/`](./scripts-onlyoffice-server) | Instalação e manutenção do OnlyOffice Server. |
| **RabbitMQ** | [`scripts-rabbit-mq/`](./scripts-rabbit-mq) | Instalação e configuração do RabbitMQ. |
| **Automação (Ansible)** | [`scripts-ansible/`](./scripts-ansible) | Preparação de hosts para serem gerenciados pelo Ansible. |
| **Monitoramento** | [`scripts-prometheus/`](./scripts-prometheus) | Instalação do Node Exporter para Prometheus. |
| **Monitoramento (Zabbix)** | [`scripts-zabbix/`](./scripts-zabbix) | Instalação e configuração do Zabbix Agent. |
| **CI/CD** | [`scripts-self-hosted-runner/`](./scripts-self-hosted-runner) | Configuração de Self-Hosted Runners para GitHub Actions. |
| **Segurança e Acesso** | [`scripts-ssh/`](./scripts-ssh) | Gerenciamento avançado de chaves SSH com hardening. |
| **Backups** | [`scripts-backups/`](./scripts-backups) | Backup completo das configurações do Proxmox VE. |
| **Integração Proxmox** | [`scripts-qemu-agent/`](./scripts-qemu-agent) | Instalação do QEMU Guest Agent para comunicação com o host. |
| **Utilitários Git** | [`scripts-git/`](./scripts-git) | Ferramentas para gerenciamento de contas Github/GitLab e sincronização de branches. |
| **Utilitários de SO** | [`scripts-zorin-os/`](./scripts-zorin-os) | Scripts específicos para Zorin OS e derivados. |
| **Cluster K3s (HA)** | [`scripts-k3s-kubernetes/`](./scripts-k3s-kubernetes) | Automação completa de Cluster K3s em Alta Disponibilidade (Etcd HA), com MetalLB, Ingress e NFS. |
| **Antigravity (Vibe Coding)** | [`scripts-antigravity/`](./scripts-antigravity) | Instalação e configuração da plataforma de desenvolvimento integrado (IDE) baseado no VS Code que usa múltiplos agentes de IA (como Gemini 3) para planejar, escrever, testar e depurar código de forma autônoma |

---

## 🚀 Primeiros Passos

Siga estes passos para começar a usar os scripts em seu ambiente.

### 1. Clone o Repositório

Clone este repositório para o seu servidor Proxmox VE ou para a máquina que você usará para gerenciar seu ambiente.

```bash
git clone https://github.com/hugllaslima/proxmox-ve-workspace.git
cd proxmox-ve-workspace
```

### 2. Explore os Scripts

Navegue até o diretório do script que você deseja usar. Por exemplo, para criar uma nova VM:

```bash
cd scripts-vms
```

Leia o `README.md` do diretório para entender os pré-requisitos e as funcionalidades específicas do script.

### 3. Dê Permissão de Execução

Antes de executar um script, você precisa torná-lo executável:

```bash
chmod +x nome_do_script.sh
```

### 4. Execute com Segurança

A maioria dos scripts precisa de privilégios de superusuário para executar tarefas administrativas. Use `sudo` para executá-los:

```bash
sudo ./nome_do_script.sh
```

Siga as instruções interativas. Os scripts foram projetados para serem autoexplicativos e seguros.

---

## 💡 Casos de Uso

- **Provisionamento Rápido:** Crie e configure uma nova VM Ubuntu com Docker e um usuário `sudo` em minutos.
- **Ambiente de Desenvolvimento:** Automatize a criação de contêineres LXC para seus projetos de desenvolvimento.
- **Monitoramento Centralizado:** Instale e configure agentes do Prometheus ou Zabbix em toda a sua infraestrutura.
- **Integração Contínua:** Configure um Self-Hosted Runner para suas pipelines de CI/CD do GitHub Actions.

---

## 🛡️ Segurança em Primeiro Lugar

- **Revise o Código:** Sempre leia e entenda o que um script faz antes de executá-lo.
- **Teste em Ambiente Seguro:** Execute os scripts em um ambiente de teste ou em uma VM de laboratório antes de aplicá-los em produção.
- **Faça Backups:** Antes de qualquer operação crítica, garanta que você tenha um backup funcional do seu sistema.
- **Não Armazene Credenciais:** Nunca insira senhas ou chaves privadas diretamente no código. Use gerenciadores de segredos ou arquivos `.env` quando aplicável.

---

## 🤝 Como Contribuir

Contribuições são sempre bem-vindas! Se você tem uma ideia para um novo script ou uma melhoria, siga estes passos:

1.  **Faça um Fork** do projeto.
2.  **Crie uma Nova Branch** (`git checkout -b feature/sua-feature`).
3.  **Faça o Commit** de suas alterações (`git commit -m 'Adiciona sua feature'`).
4.  **Faça o Push** para a sua branch (`git push origin feature/sua-feature`).
5.  **Abra um Pull Request**.

---

## 📄 Licença

Este projeto está licenciado sob a **Licença MIT**. Veja o arquivo [LICENSE.md](./LICENSE.md) para mais detalhes.

---

## 👨‍💻 Autor

**Hugllas R S Lima**

- **GitHub:** [@hugllaslima](https://github.com/hugllaslima)
- **LinkedIn:** [hugllas-lima](https://www.linkedin.com/in/hugllas-lima/)

