# 📊 Scripts para Monitoramento com Prometheus

Este diretório contém scripts para instalar e configurar agentes de monitoramento (exporters) para o **Prometheus**, uma poderosa ferramenta de monitoramento e alerta de código aberto.

## 📜 Estrutura de Diretórios

```
scripts-prometheus/
├── install_node_exporter_v2.sh
├── install_node_exporter.sh
└── README.md
```

##  Compatibilidade

Os scripts de instalação do Node Exporter são projetados para sistemas operacionais baseados em Debian que utilizam `systemd` para gerenciamento de serviços e `UFW` (Uncomplicated Firewall) para configuração de firewall. A compatibilidade inclui, mas não se limita a:

- **Ubuntu Server**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Debian**: 10, 11, 12

Embora possam funcionar em outras distribuições Linux com `systemd`, a automação do firewall é específica para `UFW`, que é padrão no Ubuntu.

## 🚀 Scripts Disponíveis

### 1. `install_node_exporter_v2.sh` (Recomendado)

- **Função**:
  Instala e configura o **Node Exporter**, um agente oficial do Prometheus que expõe uma ampla variedade de métricas de hardware e do sistema operacional da máquina onde está instalado.

- **Quando Utilizar**:
  Execute este script em **todas as máquinas (físicas ou virtuais)** que você deseja monitorar com o Prometheus. O Node Exporter é a base para o monitoramento de infraestrutura, coletando dados como:
  - Uso de CPU
  - Consumo de memória e swap
  - I/O de disco e uso do sistema de arquivos
  - Estatísticas de rede
  - Métricas do kernel e do sistema operacional

- **Recursos Principais**:
  - **Download Automatizado**: Baixa a versão mais recente do Node Exporter diretamente do GitHub.
  - **Criação de Usuário**: Cria um usuário de sistema dedicado (`node_exporter`) para executar o serviço com privilégios mínimos, seguindo as melhores práticas de segurança.
  - **Instalação Segura**: Move o binário para `/usr/local/bin` e ajusta as permissões para garantir que apenas o usuário `root` possa modificá-lo.
  - **Configuração como Serviço**: Cria, configura e habilita um serviço do `systemd` (`node_exporter.service`) para garantir que o agente inicie com o sistema e seja gerenciado de forma robusta.
  - **Firewall (UFW)**: Abre a porta `9100` (padrão do Node Exporter) no UFW para permitir que o servidor Prometheus colete as métricas.
  - **Feedback Completo**: Fornece instruções claras sobre como adicionar o novo alvo (`target`) ao arquivo de configuração do Prometheus (`prometheus.yml`).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_node_exporter_v2.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_node_exporter_v2.sh
     ```
  3. **Configurar o Prometheus**: Adicione o IP da máquina e a porta `9100` à sua configuração do Prometheus, conforme instruído pela saída do script.

### 2. `install_node_exporter.sh` (Legado)

- **Função**:
  Versão mais antiga e simplificada do script de instalação. Embora funcional, é menos segura e robusta.

- **Quando Utilizar**:
  Apenas para referência ou em ambientes de teste. A **versão 2 é fortemente recomendada** para qualquer cenário de produção devido às suas práticas de segurança e automação aprimoradas.

- **Diferenças Notáveis**:
  - Não cria um usuário dedicado; executa o processo com o usuário que invoca o script.
  - Menos validações e feedback.
  - Não configura o firewall automaticamente.

## ⚙️ Pós-Instalação: Configurando o Prometheus

Após executar o script de instalação em um novo alvo, você precisa informar ao seu servidor Prometheus onde encontrá-lo. Adicione o seguinte bloco ao seu arquivo `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<IP_DA_MAQUINA_AQUI>:9100']
```

- Substitua `<IP_DA_MAQUINA_AQUI>` pelo endereço IP da máquina onde você instalou o Node Exporter.
- Reinicie o serviço do Prometheus para aplicar as alterações.

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Linux (testado em Ubuntu/Debian).
- **Acesso**: Um usuário com privilégios `sudo`.
- **Servidor Prometheus**: Uma instância do Prometheus já em execução na sua rede.
- **Conectividade**: A máquina a ser monitorada precisa ser acessível pelo servidor Prometheus na porta `9100`.
