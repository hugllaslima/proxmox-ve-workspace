# Atualização e Manutenção do Proxmox VE (No-Subscription)

Este diretório contém scripts para gerenciar, manter e atualizar com segurança o nó do **Proxmox VE**, especialmente para ambientes comunitários que utilizam o repositório oficial sem subscrição (*No-Subscription*).

## Estrutura do Diretório

```
scripts-proxmox-ve/
|-- README.md
`-- proxmox_upgrade.sh
```

---

## Compatibilidade

- **Versões Suportadas**: 
  - **Proxmox VE 8.x** (Debian 12 Bookworm)
  - **Proxmox VE 9.x** (Debian 13 Trixie)
- **Upgrade Maior**: Migração segura de **Proxmox VE 8.4 → Proxmox VE 9.2**
- **Modo de Repositório**: No-Subscription (`pve-no-subscription`)

---

### `proxmox_upgrade.sh`

Assistente interativo, visual e resiliente a falhas projetado para automação de upgrades maiores de versão e atualizações regulares de pacotes do Proxmox VE e do sistema base Debian.

#### 1. Principais Recursos

1. **Upgrade Maior Automatizado (Proxmox 8.4 → 9.2):**
   - Executa a ferramenta oficial de verificação prévia de compatibilidade (`pve8to9 --full`).
   - Migra os repositórios base para o **Debian 13 (Trixie)** e **Proxmox VE 9 No-Subscription**.
   - Desativa automaticamente arquivos conflitantes legados em `/etc/apt/sources.list.d/` (como versões antigas de `ceph.list` e repositórios enterprise não subscritos).
   - Realiza a instalação completa do Proxmox 9.2 e do novo kernel Linux com tratamento de interrupções.

2. **Validação Rigorosa de Pré-requisitos:**
   - Confirmação de execução com privilégios de superusuário (`root`).
   - Detecção dinâmica da versão do Proxmox (`pveversion`) e codename do Debian.
   - Verificação de locks ativos do gerenciador de pacotes (`dpkg` / `apt`).
   - Checagem preventiva de espaço livre em disco em `/` e `/var` (mínimo de 4GB recomendados).
   - Teste de conectividade com os espelhos oficiais do Proxmox e Debian.

3. **Backup Preventivo Abrangente:**
   - Cópia do banco de dados SQLite do cluster Proxmox (`/var/lib/pve-cluster/config.db`).
   - Backup de configurações essenciais (`/etc/pve`, `/etc/network/interfaces`, `/etc/hosts`, `/root/.ssh`, `/etc/corosync`).
   - Exportação de inventário completo de VMs (`qm list`) e Contêineres LXC (`pct list`).
   - Compactação em arquivo `.tar.gz` datado e organizado em `/root/proxmox-config-backup/`.

4. **Feedback Visual e Barra Animada de Progresso:**
   - Indicador visual animado (*spinner*) em tempo real durante operações demoradas.
   - Cronômetro decorrido `[MM:SS]` na tela.
   - Exibição dinâmica da última linha de atividade do APT (ex: baixando, descompactando, configurando).
   - Quadro de aviso prévio com estimativa de tempo para evitar cancelamentos acidentais.

5. **Verificação de Saúde Pós-Atualização:**
   - Validação da nova versão instalada via `pveversion`.
   - Checagem automática e inicialização de serviços críticos (`pve-manager`, `pvedaemon`, `pveproxy`, `pvestatd` e `corosync`).

6. **Gerenciamento Inteligente de Reinicialização (Reboot):**
   - Comparação do kernel Linux em execução (`uname -r`) com o novo kernel instalado em `/boot/`.
   - Detecção do gatilho `/var/run/reboot-required`.
   - Solicitação interativa de reboot com contagem regressiva de segurança (5 segundos) e suporte a cancelamento imediato.

---

#### 2. Como Utilizar

No nó Proxmox VE, execute o script como `root`:

```bash
chmod +x proxmox_upgrade.sh
./proxmox_upgrade.sh
```

Ou diretamente através do caminho completo:

```bash
sudo ./scripts-proxmox-ve/proxmox_upgrade.sh
```

---

#### 3. Menu de Opções

Ao iniciar, você terá acesso ao menu interativo:

```text
1) 🚀 Realizar Upgrade Maior: Proxmox VE 8.4 → 9.2 (Debian Trixie)
2) 🔄 Atualização Regular de Pacotes (Manter versão atual)
3) 🔍 Executar Verificação Prévia de Compatibilidade (pve8to9)
4) 💾 Apenas criar backup das configurações
5) ⚙️  Apenas configurar repositórios No-Subscription
6) ✅ Apenas verificar integridade dos serviços pós-atualização
7) 📄 Exibir log da execução atual
8) 🚪 Sair
```

* **Opção 1:** Recomendada para migração completa de versão (Proxmox 8 para Proxmox 9).
* **Opção 2:** Recomendada para a manutenção periódica e aplicação de patches de segurança no nó após o upgrade.
* **Opções 3 a 7:** Utilitários modulares para verificações avulsas, backups sob demanda e auditoria de logs.
