# ☸️ Automação de Cluster K3s para Proxmox VE

Este projeto oferece uma solução de automação completa para implantar um cluster K3s de alta disponibilidade, otimizado especificamente para ambientes Proxmox VE com recursos computacionais limitados. A suíte de scripts `bash` foi desenvolvida para ser leve e eficiente, permitindo que você crie e gerencie um ambiente Kubernetes robusto, aproveitando a flexibilidade da virtualização sem a necessidade de hardware de ponta.

> [!NOTE]
> **Atualização Importante - Versão 2 (Gateway API & Traefik):**
> O projeto original utilizava o **'Ingress NGINX'** como controlador, mas devido ao [anúncio de fim de suporte](https://kubernetes.github.io/ingress-nginx/) desta ferramenta em 11 de novembro de 2025, migramos esta versão para o uso nativo do **Traefik** em conjunto com a moderna **Gateway API**.
> Essa mudança garante uma stack mais sustentável, performática e alinhada com o futuro do Kubernetes, sem depender de componentes legados.
 
## 🤔 Por que K3s? Uma Análise Comparativa

A escolha pelo **K3s** para este projeto foi estratégica, visando um equilíbrio ideal entre robustez, simplicidade e eficiência de recursos, especialmente em um ambiente virtualizado como o Proxmox VE.

O K3s é uma distribuição Kubernetes leve e certificada pela **CNCF (Cloud Native Computing Foundation)**, desenvolvida pela Rancher. Ele é projetado para cenários com recursos limitados (como Edge, IoT e desenvolvimento) por ser empacotado em um único binário com menos de 100MB. Essa abordagem simplifica drasticamente a instalação e o gerenciamento, mantendo total compatibilidade com as APIs do Kubernetes.

### K3s vs. K8s (Vanilla): Principais Diferenças

Para entender a decisão, veja um comparativo direto entre as duas abordagens:

#### **K8s (Kubernetes "Vanilla" / `kubeadm`)**
- **Implementação Completa**: É a versão oficial e mais abrangente do Kubernetes, contendo todos os componentes tradicionais (API Server, Scheduler, etcd, etc.).
- **Padrão da Indústria**: Considerado o "padrão ouro" que define o ecossistema Kubernetes.
- **Curva de Aprendizagem e Recursos**: A instalação e configuração, mesmo com `kubeadm`, exigem mais recursos de hardware e um conhecimento mais aprofundado da arquitetura.

#### **K3s (Lightweight Kubernetes)**
- **Certificado e 100% Compatível**: Passa em todos os testes de conformidade da CNCF, garantindo que suas aplicações funcionarão como esperado.
- **Otimizado para Leveza**:
    - Remove componentes legados e não essenciais (como drivers de armazenamento *in-tree*).
    - Empacota todos os processos em um **único binário**, o que reduz o *overhead* e a superfície de ataque.
    - Utiliza `containerd` como runtime padrão, que é mais leve e eficiente que o Docker para o contexto do Kubernetes.
- **Banco de Dados Flexível**:
    - Para nós únicos, pode usar **SQLite** embutido, tornando-o extremamente leve.
    - Para alta disponibilidade (HA), utiliza **Embedded Etcd** (nativamente), eliminando a necessidade de banco de dados externo. Esta é a abordagem utilizada neste projeto.

Em resumo, o K3s disponibiliza a compatibilidade total com as APIs do Kubernetes upstream, suportando recursos nativos como Secrets, Ingress, HPA e Gateway API, além de vir pré-configurado com o Traefik. Sua arquitetura otimizada reduz drasticamente a complexidade operacional, sendo ideal para ambientes de pequeno e médio porte com restrição de recursos.

## 📋 Planejamento e Pré-requisitos de Rede

Antes de iniciar a instalação, é fundamental planejar sua rede e acessos para garantir que a automação funcione corretamente.

### 1. Reserva de IPs (MetalLB)
O cluster utilizará o **MetalLB** como Load Balancer para expor serviços (como o Ingress Controller) na sua rede local.
- **Requisito**: Reserve uma faixa de IPs na sua rede (LAN) que não esteja sendo distribuída pelo seu servidor DHCP (roteador).
- **Quantidade**: Um pool pequeno é suficiente. Recomenda-se reservar entre 5 a 10 IPs.
- **Exemplo**: Se sua rede é `192.168.10.0/24` e o DHCP vai até `.200`, você pode reservar de `192.168.10.240` a `192.168.10.250`.

### 2. Usuário de Sistema
Os scripts assumem que você está utilizando um usuário padrão (como **`ubuntu`**) em todas as VMs, com privilégios de `sudo` sem senha (ou que você conheça a senha).
- Este usuário será utilizado para conexões SSH entre a máquina de gerenciamento e os nós do cluster.

## 🏗️ Arquitetura de Referência Utilizada no Proxmox VE

A arquitetura a seguir é a configuração de referência testada para este projeto. Utiliza três nós de controle (control planes) para garantir quorum no Etcd.

| VM | Nome | SO | IP/CIDR | CPU | RAM | Volume |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `k3s-control-plane-1` | Ubuntu 24.04 LTS | `192.168.10.20/24` | 2c | 4GB | 40GB |
| 2 | `k3s-control-plane-2` | Ubuntu 24.04 LTS | `192.168.10.21/24` | 2c | 4GB | 40GB |
| 3 | `k3s-control-plane-3` | Ubuntu 24.04 LTS | `192.168.10.22/24` | 2c | 4GB | 40GB |
| 4 | `k3s-worker-1` | Ubuntu 24.04 LTS | `192.168.10.23/24` | 4c | 6GB | 40GB |
| 5 | `k3s-worker-2` | Ubuntu 24.04 LTS | `192.168.10.24/24` | 4c | 6GB | 40GB |
| 6 | `k3s-storage-nfs` | Ubuntu 24.04 LTS | `192.168.10.25/24` | 2c | 4GB | 80GB |
| 7 | `k3s-management` | Ubuntu 24.04 LTS | `192.168.10.26/24` | 2c | 4GB | 30GB |

Neste projeto, o cluster Kubernetes é configurado com três nós de controle (control-planes-1, control-planes-2, control-planes-3) para garantir alta disponibilidade via Etcd embarcado, dois nós de trabalho (workers-1, workers-2), um servidor NFS para armazenamento persistente (k3s-storage-nfs) e, por fim, um servidor de gerenciamento (k3s-management) para facilitar a administração e o monitoramento do cluster.

### 🗺️ Diagrama da Topologia

O diagrama a seguir ilustra visualmente a arquitetura do cluster, destacando a comunicação entre os nós de controle, trabalhadores, servidor de armazenamento e a camada de gerenciamento externo.

```mermaid
graph LR
    User((User)) -->|SSH/HTTP| MetalLB
    User -->|SSH| Management
    Management -.->|kubectl/SSH| CP1 & CP2 & CP3
    
    subgraph Management_Net [Rede de Gerenciamento]
        Management[VM: Management]
        MetalLB[VIP: 192.168.10.x]
    end

    subgraph Cluster_K3s [Cluster K3s HA]
        direction TB
        
        subgraph Control_Plane [Control Plane Layer]
            direction TB
            CP1[Control Plane 1] <--> CP2[Control Plane 2]
            CP2 <--> CP3[Control Plane 3]
            CP3 <--> CP1
        end

        subgraph Data_Plane [Worker Layer]
            direction TB
            Worker1[Worker 1]
            Worker2[Worker 2]
            Gateway[Gateway API / Traefik]
        end
        
        MetalLB -->|Route| CP1 & CP2 & CP3
        
        CP1 & CP2 & CP3 --> Worker1 & Worker2
        
        Gateway --> Worker1 & Worker2
        MetalLB -->|Traffic| Gateway
    end

    subgraph Storage [Armazenamento]
        NFS[Server NFS]
    end

    Worker1 & Worker2 -->|PV Mount| NFS
```

## ⚙️ Como o Ambiente Funciona?

Esta seção detalha o papel de cada componente e como eles interagem para formar um cluster funcional e resiliente. ao seu ambiente.

### Papel de Cada VM

- **`k3s-control-plane-1`, `k3s-control-plane-2` e `k3s-control-plane-3` (Nós de Controle)**: Gerenciam o estado do cluster, distribui as cargas de trabalho entre os nós de trabalho, agendam aplicações e expõem a API do Kubernetes. 
- **`k3s-worker-1` e `k3s-worker-2` (Nós de Trabalho)**: Executam as aplicações e serviços (em Pods) conforme orquestrado pelos nós de controle.
- **`k3s-storage-nfs` (Armazenamento Persistente)**: Atua como um servidor NFS centralizado. Quando uma aplicação precisa de dados persistentes (através de um `PersistentVolumeClaim`), o K3s provisiona um diretório neste servidor. Isso garante que os dados sobrevivam a reinicializações de Pods e possam ser compartilhados entre eles.
- **`k3s-management` (Gerenciamento Centralizado)**: É a VM de onde todos os comandos de gerenciamento (`kubectl`, `helm`) são executados. Centralizar o gerenciamento em um nó dedicado é uma boa prática de segurança, pois isola as credenciais de acesso ao cluster.

## 🔒 Planejamento de Rede e Segurança (Redes Complexas)

A configuração correta das redes é crítica para a segurança e funcionamento do cluster. O script solicitará dois tipos de redes que você precisa distinguir com atenção:

**1. Rede LOCAL/LAN (`K3S_LAN_CIDR`)**
-   **O que é:** A faixa de IP física onde seus servidores estão conectados (ex: `192.168.10.0/24`).
-   **Para que serve:** O script usa este CIDR para liberar automaticamente no Firewall (UFW) todo o tráfego **interno do cluster** (API Server, Banco de Dados Etcd, Kubelet e Flannel VXLAN).
-   **Importante:** Se você informar isso errado, os nós não conseguirão se comunicar entre si (Join falhará).

**2. Redes de Administração (`ADMIN_NETWORK_CIDRS`)**
-   **O que é:** As redes de onde seu computador, VPN ou Jump Server acessará o cluster via SSH ou `kubectl`.
-   **Para que serve:** Libera as portas SSH (22) e API (6443) para gerenciamento externo.
-   **Segurança:** Isso permite fechar o cluster para o resto do mundo, aceitando comandos apenas de IPs confiáveis.
-   **Acesso Remoto Via VPN:** O script lhe perguntará se deseja adicionar "Redes de Administração". Se você acessa via VPN ou algum jump server (ex: 172.20.1.0/16, 53.136.46.128/32), adicione esse CIDR quando solicitado. O script configurará o Firewall (UFW) para permitir sua conexão sem alterar perigosamente as rotas do sistema. 
 
**3. Cuidado com Conflitos (Hijacking de Rede):**
-   **Atenção:** Nunca defina a **Rede de PODS** (`--cluster-cidr`, padrão `10.42.0.0/16`) sobrepondo sua rede física. Se você fizer isso, o Kubernetes "roubará" o tráfego da sua placa de rede e você perderá acesso ao servidor.

## 💿 O que é Armazenado em Cada Nó?

- **Nós Control Plane**: A configuração e o estado do cluster (objetos Kubernetes como `Deployments`, `Services`, etc.), que são mantidos no banco de dados **Etcd** embarcado.
- **Nós Worker**: As imagens de contêiner das aplicações em execução e dados temporários.
- **Nó de Armazenamento (NFS)**: Todos os dados persistentes das aplicações. É o "disco rígido" do cluster.
- **Nó de Gerenciamento**: Os arquivos de configuração do `kubectl`, charts do Helm e manifestos YAML usados para gerenciar o cluster.

## 📊 Onde Encontrar os Logs?

A localização dos logs depende do que você está tentando depurar:

- **Logs das Aplicações (Pods)**
  - **Método Principal**: Use o comando `kubectl` a partir da VM de gerenciamento. Este é o método padrão para ver a saída das suas aplicações.
    ```bash
    kubectl logs <nome-do-pod>
    ```

- **Logs da Infraestrutura (Serviços K3s, NFS, etc.)**
  - **Método Recomendado (`journalctl`)**: Para inspecionar os logs dos serviços K3s nos nós master e worker, o `journalctl` é a ferramenta ideal, pois o K3s roda como um serviço `systemd`.
    ```bash
    # Nos masters ou workers
    journalctl -u k3s
    ```
  - **Arquivos de Log Diretos**: Para inspeção manual ou uso de ferramentas como `grep`, os arquivos de log brutos podem ser encontrados nos seguintes locais:
    - **Nós Master e Worker**: `/var/log/k3s/` (logs específicos do K3s) e `/var/log/` (logs gerais do sistema).
    - **Servidor NFS**: `/var/log/` (para logs do serviço NFS e outros logs do sistema).

## 📜 Scripts Disponíveis 

### Scripts de Instalação

- **`install_nfs_server.sh`**: Configura uma VM para atuar como um servidor NFS, que fornecerá armazenamento persistente para o cluster.
- **`install_k3s_control_plane.sh`**: Instala e configura um nó de controle (control plane) do K3s. Possui lógica para diferenciar o primeiro control plane (que configura o banco de dados) do segundo, para criar um ambiente de alta disponibilidade (HA).
- **`install_k3s_worker.sh`**: Instala e configura um nó de trabalho (worker) e o junta ao cluster K3s. Instala automaticamente dependências de sistema como `nfs-common` para garantir o funcionamento de volumes persistentes.
- **`install_k3s_management.sh`**: Deve ser executado em uma máquina de gerenciamento. Instala `kubectl`, `helm`, `k9s` (Terminal UI) e implanta addons essenciais: NFS Provisioner (para StorageClasses), MetalLB (para Load Balancers) e os CRDs da **Gateway API** (para roteamento via Traefik).

### Scripts de Verificação

- **`verify_k3s_cluster_health.sh`**: Realiza um diagnóstico completo da saúde do cluster. Verifica o status dos nós, se os pods essenciais do sistema (`kube-system`) estão rodando e valida a consistência do cluster. Ideal para rodar logo após a instalação.
- **`verify_k3s_management_addons.sh`**: Executa testes funcionais nos addons (NFS, MetalLB, Ingress). Ele cria recursos temporários para garantir que o armazenamento está gravando e que o LoadBalancer está distribuindo IPs corretamente. Deve ser executado na máquina de gerenciamento.

### Scripts de Demonstração

- **`deploy_demo_app.sh`**: Implanta uma aplicação simples ("Hello World") para validar o fluxo completo: Deployment > Service > Gateway > MetalLB > Acesso Externo. Ideal para ver seu cluster funcionando na prática.

### Scripts de Manutenção

- **`cluster_maintenance_tool.sh`**: Ferramenta interativa (menu) para facilitar tarefas rotineiras de manutenção. Permite:
    - Excluir nós antigos ou duplicados (limpeza de nós "órfãos").
    - Drenar nós para manutenção (Drain).
    - Forçar a exclusão de Pods travados em estado `Terminating`.
    - Gerenciar e excluir Namespaces inteiros.
    - Executar verificações de saúde rápidas.

### Scripts de Limpeza

- **`cleanup_nfs_server.sh`**: Reverte a instalação do servidor NFS.
- **`cleanup_k3s_control_plane.sh`**: Realiza uma limpeza profunda em um nó de controle: desinstala K3s, remove binários, limpa regras de firewall (UFW), remove entradas no `/etc/hosts` e exclui arquivos de variáveis.
- **`cleanup_k3s_worker.sh`**: Realiza uma limpeza profunda em um nó de trabalho: desinstala o agente, limpa firewall e configurações de sistema.
- **`cleanup_k3s_management.sh`**: Remove todos os addons (NFS Provisioner, MetalLB, Nginx) e a configuração local do `kubectl`.

## 📂 Organização de Diretórios (Recomendação)

Para facilitar a organização e a gestão futura do seu cluster, recomendamos criar um diretório padrão `/opt/k3s` em todos os servidores. Centralizar os scripts e arquivos de configuração neste local ajuda a manter o ambiente limpo e padronizado.

```bash
# Exemplo de criação e organização
sudo mkdir -p /opt/k3s
sudo chown $USER:$USER /opt/k3s
# Copie os scripts para este diretório
cp -r k3s_cluster_vars.sh /opt/k3s/
cd /opt/k3s
```

## 🔑 Pré-requisitos: Configuração SSH

Para garantir a automação fluida (especialmente para a máquina de gerenciamento), é altamente recomendado configurar a autenticação via chaves SSH. Isso evita que os scripts parem para pedir senhas repetidamente.

**Onde executar:** Na máquina `k3s-management` (ou onde você rodará o script de gerenciamento).

1.  **Gere um par de chaves SSH (caso não tenha):**
    ```bash
    ssh-keygen -t ed25519 -C "k3s-management"
    # Pressione ENTER para todas as perguntas para aceitar o padrão (sem passphrase).
    ```

2.  **Copie a chave pública para os nós Control Plane:**
    O script de gerenciamento precisará acessar o `control-plane-1` (principalmente) para buscar configurações.
    ```bash
    # Substitua 'usuario' pelo seu usuário nos servidores (ex: ubuntu)
    ssh-copy-id usuario@192.168.10.20  # k3s-control-plane-1
    ssh-copy-id usuario@192.168.10.21  # k3s-control-plane-2 (Opcional, mas recomendado para redundância)
    ssh-copy-id usuario@192.168.10.22  # k3s-control-plane-3 (Opcional, mas recomendado para redundância)
    ```

Com isso, a máquina de gerenciamento terá acesso seguro e sem senha aos servidores, permitindo que o `install_k3s_management.sh` funcione de forma totalmente automatizada. 

## 🚀 Ordem de Execução (Fluxo Automatizado)

Com a refatoração dos scripts, o processo de implantação se tornou mais inteligente e seguro. O script `install_k3s_control_plane.sh` agora detecta automaticamente o seu papel (primeiro, segundo ou terceiro control plane), eliminando a necessidade de intervenção manual para gerenciar tokens.

Lembre-se de dar permissão de execução (`chmod +x *.sh`) a todos os scripts antes de começar.

1.  **VM de Armazenamento (`k3s-storage-nfs`)**
    - Execute o script para configurar o servidor NFS. Este passo continua o mesmo.
    ```bash
    sudo ./install_nfs_server.sh
    ```

2.  **Primeiro Control Plane (`k3s-control-plane-1`)**
    - Execute o script de instalação do master.
    ```bash
    sudo ./install_k3s_control_plane.sh
    ```
    - Como o script não encontrará um arquivo de configuração, ele fará uma série de perguntas para coletar os dados do cluster.
    - Ao final, ele gerará o arquivo `k3s_cluster_vars.sh` no diretório atual com todas as informações e instalará o K3s. O token do cluster será **salvo automaticamente** neste arquivo.

3.  **Transferência dos Scripts para o Segundo Control Plane**
    - Antes de configurar o segundo control plane, copie todo o diretório de scripts (que agora contém o `k3s_cluster_vars.sh` com o token) para o `k3s-control-plane-2`.
    - Use o `scp` a partir do `k3s-control-plane-1`:
    ```bash
    # Exemplo: Copiando para a home do usuário 'ubuntu' no control-plane-2
    scp -r ~/opt/k3s/k3s_cluster_vars.sh ubuntu@192.168.10.21:~/opt/k3s/
    ```
    - **Importante**: O script precisa do arquivo de configuração gerado na etapa anterior para ingressar no cluster automaticamente.

4.  **Segundo Control Plane (`k3s-control-plane-2` e `k3s-control-plane-3`)**
    - Execute o **mesmo script** de instalação.
    ```bash
    sudo ./install_k3s_control_plane.sh
    ```
    - O script detectará o arquivo `k3s_cluster_vars.sh`, carregará todas as variáveis (incluindo o token) e configurará o segundo master em modo de alta disponibilidade (HA) sem fazer nenhuma pergunta.

5.  **Nós Workers (`k3s-worker-1`, `k3s-worker-2`)**
    - Assim como nos control planes, copie o diretório de scripts (contendo `k3s_cluster_vars.sh`) para cada worker.
    ```bash
    # Exemplo: Copiando do control-plane-1 para o worker-1
    scp -r ~/opt/k3s/k3s_cluster_vars.sh ubuntu@192.168.10.22:~/opt/k3s/
    ```
    - Execute o script de instalação do worker:
    ```bash
    sudo ./install_k3s_worker.sh
    ```
    - **Instalação Automática**: O script detectará o arquivo de configuração e ingressará no cluster automaticamente, solicitando apenas uma confirmação final para segurança.
    - **Fallback**: Se você não copiar o arquivo de configuração, o script perguntará manualmente o IP do Control Plane e o Token.

6.  **Máquina de Gerenciamento (`k3s-management`)**
    - Assim como nos control planes, copie o diretório de scripts (contendo `k3s_cluster_vars.sh`) para a máquina de gerenciamento.
    - Após o cluster estar no ar, execute o script de configuração dos addons para instalar `kubectl`, `helm` e os componentes essenciais.
    - **Atenção:** Execute este script **SEM sudo**, pois ele configura o ambiente para o seu usuário atual.
    - **Pré-requisito**: Certifique-se de ter configurado as chaves SSH (passo "Pré-requisitos: Configuração SSH" acima) antes de rodar este script.
    ```bash
    ./install_k3s_management.sh
    ```

## 🩺 Guia de Verificação e Solução de Problemas

Esta seção detalha os scripts auxiliares criados para garantir a saúde do cluster e resolver conflitos comuns. Use-os para validar sua instalação ou diagnosticar problemas.

### 1. `verify_k3s_cluster_health.sh` (Saúde do Cluster)

**O que faz:** Realiza um "check-up" completo do cluster, verificando nós, pods do sistema e o banco de dados Etcd.

- **Quando usar:**
  - Logo após terminar a instalação dos Control Planes e Workers.
  - Antes de realizar manutenções ou upgrades.
  - Sempre que suspeitar de lentidão ou falhas nos nós.
- **Como usar:**
  Execute em qualquer nó do cluster (Control Plane ou Worker) com `sudo`:
  ```bash
  sudo ./verify_k3s_cluster_health.sh
  ```
- **Por que usar:**
  Para ter certeza de que a base do seu cluster (o K3s em si) está sólida antes de tentar rodar aplicações nele. Ele detecta nós "NotReady", valida a consistência do quórum do Etcd (em setups HA) e identifica pods do sistema (`kube-system`) travados ou em loop de erro.

### 2. `verify_k3s_management_addons.sh` (Teste de Funcionalidade)

**O que faz:** Testa se os "Addons" de gerenciamento (NFS, MetalLB, Ingress) estão realmente funcionando, criando recursos de teste temporários.

- **Quando usar:**
  - Após rodar o script de instalação da máquina de gerenciamento (`install_k3s_management.sh`).
  - Se suas aplicações não estiverem pegando IP externo (LoadBalancer).
  - Se seus volumes persistentes (PVCs) ficarem presos em "Pending".
- **Como usar:**
  Execute **apenas** na máquina de gerenciamento (`k3s-management`):
  ```bash
  ./verify_k3s_management_addons.sh
  ```
- **Por que usar:**
  Diferente do *health check*, este script prova que o cluster é **funcional** para o usuário final. Ele garante que o Storage (NFS) consegue gravar dados reais e que a Rede (MetalLB) consegue atribuir IPs válidos, simulando o uso real de uma aplicação.


### 4. `k9s` (Monitoramento Interativo)

**O que faz:** Uma interface de terminal (TUI) poderosa para gerenciar e monitorar o cluster em tempo real. Pense nele como um "Gerenciador de Tarefas" para o Kubernetes.

- **Quando usar:**
  - Para monitorar logs de pods em tempo real.
  - Para navegar rapidamente entre namespaces e recursos.
  - Para deletar pods travados ou editar configurações YAML na hora.
- **Como usar:**
  Na máquina de gerenciamento, basta digitar:
  ```bash
  k9s
  ```
- **Comandos Úteis:**

  **Navegação Básica:**
  - `:ns` + `Enter`: Ver e trocar de **Namespaces**.
  - `:pods` + `Enter`: Ver **Pods** (pressione `0` para ver de todos os namespaces).
  - `:nodes` + `Enter`: Ver **Nós** do cluster.
  - `:svc` + `Enter`: Ver **Services** (Serviços).
  - `:deploy` + `Enter`: Ver **Deployments**.
  - `:ing` + `Enter`: Ver **Ingresses**.
  - `/`: Iniciar busca/filtro na lista atual.
  - `Esc`: Voltar para a tela anterior.
  - `Ctrl+C`: Sair do K9s.

  **Interagindo com Pods (Selecione um pod e use):**
  - `l`: Ver **Logs** em tempo real (`Esc` para sair).
  - `s`: Abrir um **Shell** dentro do container do pod.
  - `y`: Ver o manifesto **YAML** do recurso.
  - `d`: Ver a descrição detalhada (**Describe**).
  - `shift+f`: Criar um **Port-Forward** (redirecionar porta) temporário.
  - `ctrl+d`: **Deletar** o pod (útil para forçar reinício).

  **Dicas de Ouro:**
  - `0`: Mostrar recursos de todos os namespaces (pressione `1` para voltar ao namespace `default`).
  - Pressione `?` a qualquer momento para ver a lista completa de atalhos.
  - Use as setas `↑` e `↓` para navegar e `Enter` para entrar nos detalhes de um recurso.

## 🔒 Nota sobre Segurança e o `.gitignore`

Você notará um arquivo `.gitignore` neste diretório. Sua finalidade é ser uma medida de segurança preventiva para o seu ambiente de desenvolvimento local.

Durante testes, é possível que você execute os scripts na sua própria máquina, o que geraria o arquivo de configuração `k3s_cluster_vars.sh` com dados sensíveis. O `.gitignore` está configurado para ignorar explicitamente este tipo de arquivo gerado localmente, garantindo que você nunca o envie acidentalmente para o seu repositório público no GitHub.

Ele garante que apenas os scripts principais do projeto sejam rastreados pelo Git, mantendo seus dados de configuração seguros.

## 🧹 Limpeza do Ambiente

Para desmontar o ambiente, utilize os scripts `cleanup_*.sh`. É recomendado seguir a ordem inversa da instalação:

1.  **Na máquina de gerenciamento**: Execute `./cleanup_k3s_management.sh` (sem sudo).
2.  **Nos nós workers**: Execute `sudo ./cleanup_k3s_worker.sh`.
3.  **Nos nós control planes**: Execute `sudo ./cleanup_k3s_control_plane.sh`.
4.  **Na VM de armazenamento**: Execute `sudo ./cleanup_nfs_server.sh`.

Isso garantirá que os servidores fiquem em um estado limpo e prontos para serem reutilizados.

## 💾 Estratégias de Backup e Recuperação

A alta disponibilidade (HA) protege contra falhas de hardware, mas não contra erros humanos ou corrupção catastrófica de dados. Implementar uma rotina de backup é obrigatório.

### 1. Nível Proxmox VE (Infraestrutura)

O Proxmox Backup Server (PBS) ou os backups nativos do Proxmox são a primeira linha de defesa.

-   **O que backupear**:
    -   Todas as VMs do Control Plane (`k3s-control-plane-*`).
    -   A VM de Storage NFS (`k3s-storage-nfs`).
-   **Frequência Recomendada**: Diária.
-   **Modo**: Utilize o modo "Snapshot" para evitar downtime das VMs.

### 2. Nível Kubernetes/K3s (Aplicação e Estado)

Para recuperações granulares ou migração de cluster, você deve fazer backup do estado do K3s (Etcd).

-   **Backup do Etcd (Automático pelo K3s)**:
    -   O K3s, por padrão, já realiza snapshots do etcd a cada 12 horas e retém os últimos 5.
    -   Localização: `/var/lib/rancher/k3s/server/db/snapshots/`
-   **Backup Manual do Etcd**:
    -   Você pode forçar um backup a qualquer momento executando no control plane:
        ```bash
        sudo k3s etcd-snapshot save
        ```
-   **Recuperação (Disaster Recovery)**:
    -   Em caso de perda total do cluster, você pode restaurar o estado usando um desses snapshots durante a instalação de um novo nó inicial.

### 3. Nível de Armazenamento (Dados Persistentes)

-   Os dados das suas aplicações vivem na VM `k3s-storage-nfs`.
-   Garanta que o diretório exportado (`/mnt/k3s-share-nfs` ou similar) esteja incluído nos backups da VM ou sincronizado com um local externo (ex: via `rsync` ou backup em nuvem).

## 🏭 Considerações para Produção

Este ambiente K3s foi projetado para ser robusto e funcional, utilizando componentes reais de produção (MetalLB, Gateway API, Etcd HA). Ele é adequado para ambientes de desenvolvimento, homelab avançado e pequenas/médias empresas.

No entanto, para ambientes de **Produção Crítica** ("Enterprise"), esteja ciente dos seguintes **Pontos de Atenção**:

1.  **Banco de Dados (Etcd)**:
    - Este projeto utiliza Etcd embarcado em alta disponibilidade (3 nós). O cluster pode sobreviver à perda de 1 nó de controle sem interrupção.
    - **Risco**: Se você perder 2 nós de controle simultaneamente, perderá o Quorum e o cluster parará.
    - **Recomendação**: Mantenha backups dos snapshots do Etcd (veja seção de Backup).

2.  **Storage NFS (SPOF)**:
    - O armazenamento persistente depende de uma única VM (`k3s-storage-nfs`). Falhas nela afetarão todos os Pods com volumes persistentes.
    - **Recomendação**: Utilize RAID no host Proxmox e faça snapshots regulares da VM de NFS.

Mantendo uma rotina de backups adequada, este cluster entregará alta disponibilidade para a API e eficiência de recursos superior a um cluster Kubernetes tradicional.

---

## 👨‍💻 Autor

**Hugllas R S Lima**

- **GitHub:** [@hugllaslima](https://github.com/hugllaslima)
- **LinkedIn:** [hugllas-lima](https://www.linkedin.com/in/hugllas-lima/)
