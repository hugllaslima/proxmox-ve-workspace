# Instalação e Configuração do Zabbix Agent

Este diretório contém scripts para automatizar a instalação e configuração do Zabbix Agent, facilitando o monitoramento de hosts em ambientes Proxmox VE.

## compatibilidade

| Sistema Operacional | Arquitetura | Dependências |
| ------------------- | ----------- | ------------------------------------------------------------ |
| Ubuntu 24.04 LTS (Recomendado) | `amd64` | `bash`, `systemd`, `apt`, `curl`, `sudo`, `telnet` |
| Ubuntu 22.04 LTS | `amd64` | `bash`, `systemd`, `apt`, `curl`, `sudo`, `telnet` |
| Ubuntu 20.04 LTS | `amd64` | `bash`, `systemd`, `apt`, `curl`, `sudo`, `telnet` |

---

## Estrutura do Diretório

```
scripts-zabbix/
|-- README.md
`-- install_zabbix_agent_7.2_ubuntu.sh
```

---

## Descrição do Script

### `install_zabbix_agent_7.2_ubuntu.sh`

Este script robusto e interativo automatiza a instalação e configuração completa do Zabbix Agent 7.2 em sistemas Ubuntu 24.04 LTS. Ele foi projetado para funcionar em ambientes híbridos (Cloud e On-Premise), garantindo uma configuração segura e validada.

#### O que o script faz?

- **Instalação Automatizada:** Baixa e instala a versão oficial do Zabbix Agent 7.2 para Ubuntu.
- **Configuração Interativa:**
    - Solicita o **IP do Zabbix Server** e a **porta de comunicação** (padrão 10051).
    - Pede um **Hostname** para o agente, que será usado para identificar o host no Zabbix Server.
    - Permite a configuração de uma **subnet/gateway adicional** para cenários de rede mais complexos.
- **Validações Abrangentes:**
    - **Verificação de Privilégios:** Garante que o script seja executado com permissões de `root` (sudo).
    - **Validação de Entradas:** Verifica se o IP do servidor, a porta e o hostname estão em um formato válido.
    - **Teste de Conectividade:** Tenta se conectar ao Zabbix Server usando `telnet` para garantir que a comunicação seja possível antes de finalizar a instalação.
- **Backup e Logs:**
    - **Backup Automático:** Cria um backup do arquivo de configuração `zabbix_agentd.conf` existente antes de fazer qualquer alteração.
    - **Logs Detalhados:** Gera um arquivo de log completo em `/var/log/` com todos os passos da instalação.
    - **Resumo da Instalação:** Cria um arquivo de resumo em `/root/` com as principais informações da configuração.
- **Gerenciamento de Serviço:** Inicia e habilita o serviço `zabbix-agent` para que ele seja executado automaticamente na inicialização do sistema.

#### Quando utilizar?

Utilize este script para provisionar rapidamente novos hosts (VMs ou contêineres) que precisam ser monitorados pelo Zabbix. Ele é ideal para padronizar a configuração de agentes em seu ambiente e garantir que todos os hosts sejam configurados de maneira consistente e segura.

#### Recursos Principais

- **Foco em Ambientes Híbridos:** Projetado para cenários onde o Zabbix Server está na nuvem e os agentes estão em uma rede local (On-Premise).
- **Interatividade Guiada:** O script guia o usuário em cada etapa, com exemplos claros para cada campo solicitado.
- **Tratamento de Erros:** O script é construído para lidar com erros comuns e fornecer feedback claro se algo der errado.
- **Compatibilidade:** Otimizado para Ubuntu 24.04 LTS, mas também funciona com outras versões do Ubuntu (com um aviso).

#### Como Utilizar

1.  **Acesse o host de destino** (a máquina que será monitorada) via SSH ou console.
2.  **Copie o script** para o host.
3.  **Dê permissão de execução**:
    ```bash
    chmod +x install_zabbix_agent_7.2_ubuntu.sh
    ```
4.  **Execute o script com `sudo`**:
    ```bash
    sudo ./install_zabbix_agent_7.2_ubuntu.sh
    ```
5.  **Siga as instruções interativas**, fornecendo as informações solicitadas (IP do servidor, porta, hostname, etc.).

---

## Pré-requisitos

- Um sistema Ubuntu (preferencialmente 24.04 LTS) com acesso à internet.
- Acesso `root` ou um usuário com privilégios `sudo`.
- Um Zabbix Server 7.2 ou superior já configurado e acessível a partir do host do agente.
- As portas de firewall necessárias (padrão 10050 para o agente e 10051 para o servidor) devem estar abertas entre o agente e o servidor.

## Pós-instalação

Após a execução bem-sucedida do script, você precisa adicionar o host no dashboard do seu Zabbix Server:

1.  Navegue até **Data Collection > Hosts**.
2.  Clique em **Create Host**.
3.  Preencha os seguintes campos:
    - **Host Name:** Use o mesmo hostname que você configurou durante a execução do script.
    - **Templates:** Selecione um template apropriado, como `Linux by Zabbix agent`.
    - **Host Groups:** Adicione o host a um grupo, como `Linux Servers`.
    - **Interfaces:** Adicione uma nova interface de agente, fornecendo o endereço IP do host que está sendo monitorado.
4.  Aguarde alguns minutos para que o Zabbix Server comece a receber dados do agente.

## Troubleshooting

Se você encontrar problemas, verifique os seguintes pontos:

- **Logs do Agente:** `/var/log/zabbix/zabbix_agentd.log`
- **Status do Serviço:** `systemctl status zabbix-agent`
- **Teste de Conectividade:** `telnet <IP_DO_ZABBIX_SERVER> <PORTA>`
- **Verificação da Configuração:** `grep -E "^Server=|^ServerActive=|^Hostname=" /etc/zabbix/zabbix_agentd.conf`
