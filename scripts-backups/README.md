# Automação de Backups no Proxmox VE

Este diretório contém scripts para automatizar rotinas de backup no Proxmox VE, incluindo o backup das configurações do host e a montagem de dispositivos de armazenamento externo.

## Estrutura do Diretório

```
scripts-backups/
|-- README.md
|-- backup_full_proxmox_ve.sh
`-- backups_usb_external.sh
```

---

## Compatibilidade

Os scripts deste diretório são projetados para serem executados diretamente no **Proxmox VE**.

- **Proxmox VE**: 7.x, 8.x

Como o Proxmox VE é baseado em Debian, os scripts utilizam comandos e estruturas de diretórios padrão do Debian. A execução em um sistema Debian puro pode ser possível com adaptações, mas o foco principal é o ambiente Proxmox.



### 1. `backup_full_proxmox_ve.sh`

Este script realiza um backup completo e essencial das configurações do nó (host) do Proxmox VE. Ele é projetado para salvar todos os arquivos críticos necessários para reconstruir o host em caso de falha.

#### 1.1. O que o script faz?

- **Cria um diretório de backup** nomeado com o hostname e a data/hora atual (ex: `pve.240825-1030`).
- **Faz backup de diretórios críticos** do Proxmox e do sistema, incluindo:
    - `/var/lib/pve-cluster`: Configurações do cluster Proxmox.
    - `/root/.ssh`: Chaves SSH do usuário root.
    - `/etc/corosync`: Configurações do Corosync (comunicação do cluster).
    - `/etc/iscsi`: Configurações de iSCSI.
    - `/etc`: Diretório completo de configurações do sistema.
    - `/etc/apt`: Fontes de repositórios de software.
- **Salva arquivos de configuração de rede**:
    - `/etc/hosts`
    - `/etc/network/interfaces`
- **Gera uma lista de todos os pacotes instalados** no sistema.
- **Compacta todos os arquivos de backup** em um único arquivo `tar.gz` e remove o diretório temporário.

#### 1.2. Quando utilizar?

Utilize este script para criar um ponto de restauração completo das configurações do seu host Proxmox. É ideal para ser executado:

- **Antes de atualizações importantes** do sistema ou do Proxmox.
- **Periodicamente (via `cron`)** para manter um backup regular das configurações do host.
- **Como parte de uma estratégia de recuperação de desastres**.

> **Nota:** Este script **não** faz backup dos dados das VMs e contêineres, apenas das configurações do host. Para o backup das máquinas virtuais, utilize a funcionalidade nativa de backup do Proxmox.

#### 1.3. Recursos Principais

- **Backup Abrangente:** Cobre os arquivos de configuração mais importantes do Proxmox e do Debian subjacente.
- **Organização:** Salva cada backup em um arquivo compactado com data e hora, facilitando a identificação.
- **Automatizável:** Pode ser facilmente agendado com `cron` para execuções regulares.

#### 1.4. Como Utilizar

1.  **Acesse o host Proxmox** via SSH ou console como `root`.
2.  **Copie o script** para um diretório (ex: `/root/scripts`).
3.  **Dê permissão de execução**:
    ```bash
    chmod +x backup_full_proxmox_ve.sh
    ```
4.  **Execute o script**:
    ```bash
    ./backup_full_proxmox_ve.sh
    ```
    O backup será salvo no diretório `/root/backup/`.

---

### 2. `backups_usb_external.sh`

Este é um script auxiliar simples para montar um dispositivo de armazenamento USB externo, geralmente usado como um destino para backups.

#### 2.1. O que o script faz?

- **Monta uma partição específica** (`/dev/sdc1`) em um diretório de destino (`/mnt/pve/backups-usb`).
- **Exibe o espaço em disco** dos sistemas de arquivos montados (`df -h`).
- **Exibe uma mensagem de sucesso** confirmando que o disco foi montado.

#### 2.2. Quando utilizar?

Use este script para montar rapidamente um disco USB que será usado para armazenar backups. Ele é útil em cenários onde o disco não é mantido permanentemente montado.

> **Atenção:** Este script é **estático** e assume que o dispositivo a ser montado é sempre `/dev/sdc1`. Em sistemas com múltiplos discos, essa identificação pode mudar. Para uma solução mais robusta, considere o uso de `UUID` ou `LABEL` no arquivo `/etc/fstab`.

#### 2.3. Recursos Principais

- **Simplicidade:** Monta o disco com um único comando.
- **Feedback:** Confirma a montagem e exibe o uso do disco.

#### 2.4. Como Utilizar

1.  **Conecte o disco USB** ao host Proxmox.
2.  **Identifique o nome do dispositivo** (ex: `fdisk -l`). Se não for `/dev/sdc1`, edite o script.
3.  **Certifique-se de que o diretório de montagem exista**:
    ```bash
    mkdir -p /mnt/pve/backups-usb
    ```
4.  **Execute o script** como `root`:
    ```bash
    ./backups_usb_external.sh
    ```

---

## Pré-requisitos

- Acesso `root` ao host Proxmox VE.
- Para `backups_usb_external.sh`, um dispositivo de armazenamento USB formatado com um sistema de arquivos compatível (ex: `ext4`).

## Dicas e Boas Práticas

- **Agendamento de Backups:** Para automatizar o `backup_full_proxmox_ve.sh`, adicione-o ao `crontab` do root. Exemplo para executar todo dia às 2h da manhã:
    ```crontab
    0 2 * * * /root/scripts/backup_full_proxmox_ve.sh
    ```
- **Armazenamento Externo:** Combine os dois scripts. Use `backups_usb_external.sh` para montar um disco e, em seguida, modifique `backup_full_proxmox_ve.sh` para salvar os backups nesse disco montado. Não se esqueça de desmontar o disco após o backup para protegê-lo.
- **UUID para Montagem:** Para evitar problemas com a nomeação de dispositivos, modifique `backups_usb_external.sh` para usar o UUID do disco. Encontre o UUID com `blkid` e use-o no comando `mount`.
