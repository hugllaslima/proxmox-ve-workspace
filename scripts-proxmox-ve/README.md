# Atualização e Manutenção do Proxmox VE (No-Subscription)

Este diretório contém scripts para gerenciar, manter e atualizar com segurança o nó do **Proxmox VE**, especialmente para ambientes comunitários que utilizam o repositório oficial sem subscrição (*No-Subscription*).

## Estrutura do Diretório

```
scripts-proxmox-ve/
|-- README.md
`-- proxmox-upgrade.sh
```

---

## Compatibilidade

- **Proxmox VE**: 8.x (Debian 12 Bookworm)
- **Modo de Repositório**: No-Subscription (`pve-no-subscription`)

---

### `proxmox-upgrade.sh`

Assistente interativo e resiliente a falhas para atualização completa de pacotes do Proxmox VE e do sistema base Debian.

#### 1. Principais Recursos

1. **Validação de Pré-requisitos:**
   - Confirmação de execução como usuário `root`.
   - Detecção automática da versão do Proxmox (`pveversion`) e codename do Debian (`bookworm`).
   - Verificação de locks ativos do APT/dpkg.
   - Checagem de espaço livre em disco em `/` e `/var` (mínimo de 4GB recomendados).
   - Teste de conectividade com os espelhos oficiais do Proxmox.

2. **Backup Automático Preventivo:**
   - Salva a base SQLite do cluster Proxmox (`/var/lib/pve-cluster/config.db`).
   - Copia configurações críticas (`/etc/pve`, `/etc/network/interfaces`, `/etc/hosts`, `/root/.ssh`, `/etc/corosync`).
   - Exporta inventário de VMs e Containers (`qm list` e `pct list`).
   - Compacta todo o backup em um arquivo `.tar.gz` datado em `/root/proxmox-config-backup/`.

3. **Configuração Correta de Repositórios:**
   - Desativa repositórios corporativos restritos (`pve-enterprise` e `ceph-enterprise`) em `/etc/apt/sources.list` e `/etc/apt/sources.list.d/pve-enterprise.list`.
   - Adiciona o repositório oficial sem subscrição (`pve-no-subscription`) para Debian Bookworm.
   - Garante a presença dos repositórios oficiais do Debian 12 (`bookworm`, `bookworm-updates`, `bookworm-security`).

4. **Atualização Segura de Pacotes:**
   - Executa `apt-get dist-upgrade` de forma não-interativa segura.
   - Realiza limpeza de pacotes obsoletos (`autoremove`) e esvaziamento de cache (`clean`).

5. **Verificação de Saúde Pós-Atualização:**
   - Valida se os serviços críticos do Proxmox (`pve-manager`, `pvedaemon`, `pveproxy`, `pvestatd`, `corosync`) estão em execução normal.
   - Exibe a nova versão do Proxmox VE instalada.

6. **Gerenciamento Inteligente de Reinicialização (Reboot):**
   - Compara o kernel Linux atualmente em execução (`uname -r`) com o último kernel instalado em `/boot/`.
   - Detecta sinalização do sistema em `/var/run/reboot-required`.
   - Pergunta interativamente ao operador se deseja reiniciar o host de imediato ou adiar.

---

#### 2. Como Utilizar

Execute o script no nó Proxmox VE como `root`:

```bash
chmod +x proxmox-upgrade.sh
./proxmox-upgrade.sh
```

Ou diretamente através de um comando no terminal:

```bash
sudo ./scripts-proxmox-ve/proxmox-upgrade.sh
```

---

#### 3. Menu de Opções

Ao iniciar, você terá acesso ao menu:

```
1) Realizar atualização completa do Proxmox VE (Recomendado)
2) Apenas verificar pré-requisitos e status do sistema
3) Apenas criar backup das configurações
4) Apenas configurar repositórios No-Subscription
5) Apenas verificar integridade dos serviços pós-atualização
6) Exibir log da execução atual
7) Sair
```
