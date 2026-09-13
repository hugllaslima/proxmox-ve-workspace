# Atualização e Manutenção do Proxmox VE (No-Subscription)

Este diretório contém scripts para gerenciar, manter e atualizar com segurança o nó do **Proxmox VE**, especialmente para ambientes comunitários que utilizam o repositório oficial sem subscrição (*No-Subscription*).

---

> [!CAUTION]
> **Ambiente de Produção — Leia antes de executar**
>
> Estes scripts realizam operações críticas no sistema operacional do Proxmox VE (atualização de kernel, migração de repositórios, regeneração do `initramfs`). Embora projetados para serem seguros e interativos, **todo upgrade de versão maior carrega riscos inerentes**, especialmente em ambientes com:
>
> - **Storages externos via USB** — O script detecta e aplica automaticamente um fix de compatibilidade ([veja a seção específica](#fix-de-compatibilidade-usb-storage-quirks)). Avalie o impacto antes de aplicar em produção.
> - **VMs/Containers em execução** — Recomenda-se pausar ou migrar cargas de trabalho críticas antes do upgrade.
> - **Clusters multi-nó** — Realize o upgrade de um nó por vez e valide o quórum do corosync entre cada etapa.
> - **Storages compartilhados (Ceph, NFS, iSCSI)** — Verifique a compatibilidade dos drivers e do cliente com a nova versão do kernel antes de prosseguir.
>
> **Recomendação:** Teste sempre em um ambiente não-produtivo antes de aplicar em produção. Em ambientes single-node domésticos ou de laboratório, o risco é significativamente menor.

---

## Estrutura do Diretório

```
scripts-proxmox-ve/
├── README.md
├── proxmox_upgrade_v6_to_v7.sh   ← Upgrade: Proxmox 6.4 → 7.4  (Debian Buster → Bullseye)
├── proxmox_upgrade_v7_to_v8.sh   ← Upgrade: Proxmox 7.4 → 8.x  (Debian Bullseye → Bookworm)
└── proxmox_upgrade_v8_to_v9.sh   ← Upgrade: Proxmox 8.4 → 9.2  (Debian Bookworm → Trixie)
```

---

## Convenção de Nomenclatura

Todos os scripts seguem o padrão:

```
proxmox_upgrade_v{ORIGEM}_to_v{DESTINO}.sh
```

Isso facilita a identificação, ordenação por listagem (`ls`) e automação futura.

---

## Compatibilidade e Mapeamento de Versões

| Script | Proxmox Origem | Proxmox Destino | Debian Origem | Debian Destino |
|--------|---------------|-----------------|---------------|----------------|
| `proxmox_upgrade_v6_to_v7.sh` | 6.4 | 7.4 | Debian 10 Buster | Debian 11 Bullseye |
| `proxmox_upgrade_v7_to_v8.sh` | 7.4 | 8.x | Debian 11 Bullseye | Debian 12 Bookworm |
| `proxmox_upgrade_v8_to_v9.sh` | 8.4 | 9.2 | Debian 12 Bookworm | Debian 13 Trixie |

- **Modo de Repositório**: No-Subscription (`pve-no-subscription`) — nenhum script requer subscrição paga.

---

## Principais Recursos (Comuns a todos os scripts)

1. **Upgrade Maior Automatizado:**
   - Executa a ferramenta oficial de verificação prévia de compatibilidade (`pveXtoY --full`).
   - Migra os repositórios base para a versão-alvo do Debian e Proxmox VE No-Subscription.
   - Desativa automaticamente arquivos conflitantes legados em `/etc/apt/sources.list.d/` (como versões antigas de `ceph.list` e repositórios enterprise).
   - Realiza a instalação completa do novo Proxmox e do novo kernel Linux com tratamento de interrupções.

2. **Validação Rigorosa de Pré-requisitos:**
   - Confirmação de execução com privilégios de superusuário (`root`).
   - Detecção dinâmica da versão do Proxmox (`pveversion`) e codename do Debian.
   - Verificação de locks ativos do gerenciador de pacotes (`dpkg` / `apt`).
   - Checagem preventiva de espaço livre em disco em `/` e `/var` (mínimo de 4GB recomendados).
   - Teste de conectividade com os espelhos oficiais do Proxmox e Debian.

3. **Backup Preventivo Abrangente:**
   - Cópia do banco de dados SQLite do cluster Proxmox (`/var/lib/pve-cluster/config.db`).
   - Backup de configurações essenciais: `/etc/pve`, `/etc/fstab`, `/etc/network/interfaces`, `/etc/hosts`, `/root/.ssh`, `/etc/corosync`, `/etc/modprobe.d`.
   - Cópia explícita de `/etc/pve/storage.cfg` (configuração de todos os storages do Proxmox).
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

## Como Utilizar

No nó Proxmox VE, execute o script como `root`. **Escolha o script correto para a sua versão atual**:

```bash
# Upgrade de Proxmox 6.x para 7.x
chmod +x proxmox_upgrade_v6_to_v7.sh
./proxmox_upgrade_v6_to_v7.sh

# Upgrade de Proxmox 7.x para 8.x
chmod +x proxmox_upgrade_v7_to_v8.sh
./proxmox_upgrade_v7_to_v8.sh

# Upgrade de Proxmox 8.x para 9.x
chmod +x proxmox_upgrade_v8_to_v9.sh
./proxmox_upgrade_v8_to_v9.sh
```

Ou diretamente pelo caminho completo:

```bash
sudo bash ./scripts-proxmox-ve/proxmox_upgrade_v8_to_v9.sh
```

---

## Menu de Opções

Ao iniciar qualquer script, você terá acesso ao menu interativo:

```text
1) 🚀 Realizar Upgrade Maior: Proxmox VE X.x → Y.y (Debian <Codename>)
2) 🔄 Atualização Regular de Pacotes (Manter versão atual)
3) 🔍 Executar Verificação Prévia de Compatibilidade (pveXtoY)
4) 💾 Apenas criar backup das configurações
5) ⚙️  Apenas configurar repositórios No-Subscription
6) ✅ Apenas verificar integridade dos serviços pós-atualização
7) 💽 Verificar storages externos e aplicar fix USB (quirks)   ← v8→v9 apenas
8) 📄 Exibir log da execução atual
9) 🚪 Sair
```

> **Nota:** A opção 7 está disponível atualmente apenas no script `proxmox_upgrade_v8_to_v9.sh`.

- **Opção 1:** Recomendada para migração completa de versão.
- **Opção 2:** Recomendada para manutenção periódica e aplicação de patches de segurança no nó após o upgrade.
- **Opções 3 a 8:** Utilitários modulares para verificações avulsas, backups sob demanda e auditoria de logs.

---

## Fix de Compatibilidade: USB Storage Quirks

> [!NOTE]
> Esta funcionalidade é **específica do script `proxmox_upgrade_v8_to_v9.sh`** e foi adicionada para tratar um problema real documentado durante a migração Proxmox 8 → 9 com discos de backup em USB.

### O que é e por que ocorre

Durante o upgrade de kernel (Proxmox 8 → 9), o novo kernel Linux pode alterar o modo de operação de dispositivos USB de armazenamento de **UAS** (*USB Attached SCSI*) para **BOT** (*Bulk-Only Transport*), ou simplesmente não reconhecer corretamente o dispositivo, tornando o storage inacessível após o reboot.

### O que o script faz automaticamente

1. **Antes do upgrade:** detecta todos os storages montados em `/mnt/pve/*` e identifica quais são USB.
2. **Após o `dist-upgrade`:** se USB foi detectado, aplica automaticamente:
   ```bash
   echo "options usb-storage quirks=*:u" >> /etc/modprobe.d/usb-storage.conf
   update-initramfs -u -k all
   ```
3. O fix entra em vigor na próxima reinicialização.

### ⚠️ Avaliação para uso em produção

| Cenário | Impacto do fix | Recomendação |
|---|---|---|
| HDD/SSD USB externo para backup | ✅ Nenhum impacto de performance perceptível | Aplicar normalmente |
| Pendrive USB para ISOs ou templates | ✅ Sem impacto relevante | Aplicar normalmente |
| SSD NVMe USB (alta velocidade via UAS) | ⚠️ Pode reduzir throughput (UAS desativado) | Avaliar antes de aplicar |
| USB integrado ao servidor (IPMI, iDRAC) | ✅ Não afetado (não é `usb-storage`) | Aplicar normalmente |

> [!IMPORTANT]
> O parâmetro `quirks=*:u` aplica o fallback para **todos** os dispositivos USB de armazenamento sem distinção de fabricante/modelo. Se você possui um storage USB de alta performance onde a velocidade é crítica (ex.: SSD NVMe via USB 3.2), considere especificar o ID exato do dispositivo em vez do curinga:
> ```bash
> # Exemplo com ID específico (obtenha com: lsusb)
> echo "options usb-storage quirks=1234:5678:u" >> /etc/modprobe.d/usb-storage.conf
> update-initramfs -u -k all
> ```
> Para a grande maioria dos ambientes domésticos e de laboratório com HDs externos USB para backup, o curinga `*:u` é completamente adequado.

---

## Arquivos de Log

Cada execução gera um arquivo de log datado em `/var/log/`:

| Script | Log gerado |
|--------|-----------|
| `proxmox_upgrade_v6_to_v7.sh` | `/var/log/proxmox-upgrade-v6-to-v7-YYYYMMDD-HHMMSS.log` |
| `proxmox_upgrade_v7_to_v8.sh` | `/var/log/proxmox-upgrade-v7-to-v8-YYYYMMDD-HHMMSS.log` |
| `proxmox_upgrade_v8_to_v9.sh` | `/var/log/proxmox-upgrade-YYYYMMDD-HHMMSS.log` |

---

## Compatibilidade com Diferentes Configurações de Storage

Os scripts foram desenvolvidos para funcionar corretamente nos cenários mais comuns do Proxmox VE:

| Tipo de Storage | Compatibilidade | Observação |
|---|---|---|
| Disco local (`/var/lib/vz`) | ✅ Total | Nenhuma interação do script |
| SSD/HD adicional em `/mnt/pve/*` | ✅ Total | Detectado e inventariado antes do upgrade |
| Disco USB externo em `/mnt/pve/*` | ✅ Total | Fix de quirks aplicado automaticamente se necessário |
| NFS mount em `/mnt/pve/*` | ✅ Total | Detectado; sem impacto (fix USB não se aplica) |
| Ceph (storage distribuído) | ⚠️ Parcial | O repositório Ceph enterprise é desativado; verifique a versão do cliente Ceph pós-upgrade |
| iSCSI / ZFS | ✅ Total | Nenhuma interação direta; pacotes são atualizados via `dist-upgrade` normalmente |
