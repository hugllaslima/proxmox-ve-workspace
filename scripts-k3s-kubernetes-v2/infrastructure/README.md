# Infraestrutura Kubernetes (K3s)

Este diretório contém os manifestos de infraestrutura base para o cluster K3s, com foco especial na configuração de rede moderna utilizando o **Kubernetes Gateway API** em conjunto com o Traefik.

> ⚠️ **NOTA TÉCNICA IMPORTANTE:**
> No K3s, o Traefik é configurado por padrão para escutar na porta `8000` dentro do container (mapeada para a porta `80` do host via Service). Para que a Gateway API funcione corretamente, o Listener do Gateway deve apontar para a porta `8000` e possuir a anotação `traefik.io/gateway.entrypoints: web`. Caso contrário, o status permanecerá como `PortUnavailable`.

---

## 📂 Modelo de Arquitetura de Diretórios

Para manter a organização e escalabilidade do cluster, recomendamos e seguimos a seguinte estrutura de diretórios como modelo para os projetos:

```text
k3s-proxmox-cluster/ 
 ├── traefik-gateway-rbac.yaml  # Configuração RBAC para o Traefik Gateway API
 ├── bootstrap/                # Arquivos de inicialização do cluster (CRDs) 
 │   └── gateway-api-crds.yaml 
 ├── infrastructure/           # Ferramentas que dão suporte ao cluster 
 │   ├── networking/           # Traefik, Gateway, Certificados 
 │   │   ├── gateway-class.yaml 
 │   │   ├── gateway.yaml 
 │   │   ├── http-route-template.yaml 
 │   │   ├── reference-grant.yaml 
 │   │   └── traefik-gateway-rbac.yaml 
 │   ├── cert-manager/ 
 │   │   └── cert-manager-values.yaml 
 │   └── monitoring/ 
 │       └── prometheus-values.yaml 
 ├── apps/                     # Suas aplicações de fato 
 │   ├── awx/                  # Projeto AWX 
 │   │   ├── arquivo_01.yaml  
 │   │   └── arquivo_02.yaml 
 │   ├── prometheus/           # Projeto Prometheus 
 │   │   ├── arquivo_01.yaml  
 │   │   └── arquivo_02.yaml 
 │   ├── staging/              # Apps de teste 
 │   │   └── hello-world.yaml 
 │   └── production/           # Apps de produção 
 │   │   └── hello-world.yaml 
 └── scripts/                  # Scripts auxiliares (ex: limpeza, backup) 
     └── install-all.sh
```

Para criar rapidamente esta estrutura de diretórios base no seu ambiente, você pode executar o seguinte comando:

```bash
mkdir -p k3s-cluster/{bootstrap,infrastructure/networking,infrastructure/cert-manager,infrastructure/monitoring,apps/awx,apps/staging,apps/production,scripts}
```

---

## 🌐 Networking (Gateway API)

A pasta `networking/` possui as configurações essenciais para expor aplicações para fora do cluster de forma segura e estruturada, substituindo a antiga abordagem de Ingress tradicional pela nova especificação Gateway API.

### 🏛️ Arquitetura de Roteamento

O modelo de roteamento segue a seguinte estrutura lógica:

```mermaid
graph TD
    Client[Cliente/Navegador] -->|Requisição HTTP| Traefik[Traefik Ingress Controller]
    
    subgraph Cluster Kubernetes
        subgraph Namespace: networking
            Traefik
            GatewayClass[GatewayClass: traefik] -.->|Controla| Traefik
            Gateway[Gateway: cluster-gateway] -.->|Implementado por| GatewayClass
        end
        
        subgraph Namespace: my-app-namespace
            HTTPRoute[HTTPRoute: my-app-route] -->|Refere-se ao| Gateway
            RefGrant[ReferenceGrant: allow-gateway-traffic] -.->|Permite tráfego cross-namespace| Gateway
            HTTPRoute -->|Roteia tráfego para| Service[Service: my-app-service]
            Service --> Pods[Pods da Aplicação]
        end
    end
```

### 📄 Descrição dos Arquivos

| Arquivo | Propósito | Onde/Quando Aplicar |
| :--- | :--- | :--- |
| `traefik-gateway-rbac.yaml` | Concede as permissões (ClusterRole e RoleBinding) necessárias para que o Traefik possa ler e interagir com os recursos da Gateway API. | Uma única vez, na configuração inicial do cluster. |
| `gateway-class.yaml` | Define a classe de Gateway (`traefik`), indicando qual controlador (`traefik.io/gateway-controller`) será responsável por gerenciar os Gateways criados a partir dela. | Uma única vez, na configuração inicial do cluster. |
| `gateway.yaml` | Cria o ponto de entrada principal (`cluster-gateway` no namespace `networking`). Ele escuta o tráfego HTTP e permite que aplicações de **qualquer namespace** criem rotas (`HTTPRoute`) apontando para ele. | Uma única vez, na configuração inicial do cluster. |
| `http-route-template.yaml` | Arquivo de **modelo** (template) que ensina como expor sua aplicação. Ele vincula um hostname (ex: `app.example.local`) ao seu `Service` interno, usando o `cluster-gateway`. | Sempre que for fazer o deploy de uma **nova aplicação**. |
| `reference-grant.yaml` | Arquivo de **modelo** (template) para segurança cross-namespace. Como o Gateway está em `networking` e sua aplicação em outro namespace, isso permite explicitamente que o Gateway encaminhe tráfego para o seu `Service`. | Sempre que for expor uma aplicação que está em um **namespace diferente** do Gateway. |

---

## 🚀 Como Utilizar (Passo a Passo)

### 1. Configuração Base da Infraestrutura (Admin)
Estes passos são realizados apenas uma vez, pelo administrador do cluster, para preparar o ambiente:

```bash
# Entre no diretório networking do infrastructure
cd infrastructure/networking/

# 1. Aplicar as permissões de RBAC para o Traefik gerenciar o Gateway API
kubectl apply -f traefik-gateway-rbac.yaml

# 2. Criar a classe do Gateway (indica que usaremos o Traefik)
kubectl apply -f gateway-class.yaml

# 3. Subir o Gateway central do cluster
kubectl apply -f gateway.yaml
```

### 2. Expondo uma Aplicação (Desenvolvedor)
Sempre que você criar uma nova aplicação no cluster e quiser expô-la (por exemplo, `meu-site.local`), utilize os templates:

1. **Copie e ajuste o HTTPRoute:**
   Pegue o `http-route-template.yaml`, ajuste o `namespace`, `name`, `hostname` e aponte para o nome e a porta do seu `Service`.
   
2. **Copie e ajuste o ReferenceGrant:**
   Pegue o `reference-grant.yaml`, ajuste o `namespace` (para o namespace da sua aplicação) e altere o `name` do Service no final do arquivo para liberar a comunicação do Gateway até sua aplicação.

3. **Aplique no cluster:**
   ```bash
   kubectl apply -f seu-http-route.yaml
   kubectl apply -f seu-reference-grant.yaml
   ```

### 📝 Notas Importantes
- **Gateway API CRDs:** O cluster já deve possuir as Custom Resource Definitions (CRDs) do Gateway API instaladas.
- **Resolução DNS Local (Hosts):** Como estamos usando domínios locais (ex: `app.example.local`) que não existem na internet pública, seu computador não sabe para qual IP enviar a requisição. Para acessar as aplicações pelo navegador, você precisa adicionar uma entrada no arquivo `hosts` da sua máquina (em `/etc/hosts` no Linux/Mac ou `C:\Windows\System32\drivers\etc\hosts` no Windows) apontando o IP do Traefik/MetalLB para o domínio:
  ```text
  <ip_do_MetalLB>  app.example.local
  ```

---

## 🛠️ Troubleshooting e Comandos Úteis

Se você encontrar problemas com o roteamento, permissões ou status do Gateway, utilize os comandos abaixo para diagnosticar e resolver falhas comuns.

### 🔍 Verificação de Status

**Verificar o status geral do Gateway:**
```bash
kubectl get gateway -n networking
```
> *O que faz:* Lista todos os Gateways no namespace `networking`. Você deve verificar se o status está como `Programmed: True` ou se há alguma indicação de erro (como `PortUnavailable`).

**Acompanhar mudanças no Gateway em tempo real:**
```bash
kubectl get gateway -n networking -w
```
> *O que faz:* O parâmetro `-w` (watch) mantém o terminal aberto e exibe atualizações no status do Gateway assim que elas acontecem. Útil logo após aplicar correções.

**Inspecionar os detalhes e eventos do Gateway:**
```bash
kubectl describe gateway cluster-gateway -n networking
```
> *O que faz:* Exibe informações profundas sobre o Gateway (substitua `cluster-gateway` pelo nome correto caso tenha alterado). Verifique a seção `Events` no final da saída para identificar falhas de criação, portas indisponíveis ou problemas de RBAC.

**Checar os logs do Traefik Ingress Controller:**
```bash
kubectl logs -n networking -l app.kubernetes.io/name=traefik --tail=50
```
> *O que faz:* Puxa as últimas 50 linhas de log do Pod do Traefik. Fundamental para identificar se o Traefik está reclamando de falta de permissões (RBAC) para ler objetos do Gateway API.

### 🔄 Recarregamento e Aplicação

**Testar o tráfego simulando um Hostname local:**
```bash
curl -v -H "Host: awx.local" http://<ip_do_MetalLB>
```
> *O que faz:* Envia uma requisição HTTP forçando o cabeçalho `Host`. Isso é perfeito para testar se a rota (`HTTPRoute`) está funcionando antes mesmo de configurar um servidor DNS local.

**Aplicar permissões de RBAC:**
```bash
kubectl apply -f traefik-gateway-rbac.yaml
```
> *O que faz:* Aplica (ou reaplica) as permissões necessárias para que o Traefik possa interagir com a Gateway API. Deve ser rodado se os logs do Traefik indicarem `permission denied` para listar `httproutes` ou `gateways`.

**Aplicar a permissão cross-namespace (ReferenceGrant):**
```bash
kubectl apply -f reference-grant.yaml
```
> *O que faz:* Aplica o arquivo que permite que o Gateway (em `networking`) envie tráfego para a sua aplicação (em outro namespace). Se você receber erro `404 Not Found` no navegador e a rota estiver certa, o ReferenceGrant pode estar faltando.

**Forçar o recarregamento do Traefik:**
```bash
kubectl rollout restart deployment traefik -n networking
```
> *O que faz:* Reinicia os Pods do Traefik de forma suave. Útil após aplicar novas regras de RBAC ou CRDs, forçando o Traefik a ler todas as configurações do zero.

### 🗑️ Recriar Recursos (Último Recurso)

Se o Gateway estiver preso em um estado de erro permanente, pode ser necessário recriá-lo:

```bash
# Deleta o Gateway atual
kubectl delete -f gateway.yaml

# Aplica novamente do zero
kubectl apply -f gateway.yaml
```
> *O que faz:* Remove o recurso de forma limpa e o cria novamente. Ideal para limpar estados inválidos (ex: se o Listener travou por configuração errada de portas).