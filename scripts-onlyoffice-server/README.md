# 🏢 Scripts de Gerenciamento do OnlyOffice Document Server

Este diretório contém um conjunto de scripts para instalar, configurar, limpar e solucionar problemas do **OnlyOffice Document Server**, garantindo sua integração com serviços como RabbitMQ e Nextcloud.

## 📜 Estrutura de Diretórios

```
onlyoffice-server/
├── install_onlyoffice_server_v2.sh
├── install_onlyoffice_server.sh
├── cleanup_onlyoffice.sh
├── onlyoffice_troubleshooting_kit.sh
└── README.md
```

## Compatibilidade

Os scripts deste diretório são compatíveis com as seguintes distribuições Linux baseadas em Debian:

- **Ubuntu Server**: 22.04 LTS, 24.04 LTS
- **Debian**: 11, 12

A recomendação oficial é utilizar **Ubuntu Server** para garantir a melhor compatibilidade com as dependências do OnlyOffice Document Server.



### 1. `install_onlyoffice_server_v2.sh`

- **Função**:
  Realiza a instalação e configuração completas do **OnlyOffice Document Server**, integrando-o com o **RabbitMQ** para otimização de desempenho e com o **Nextcloud** para edição de documentos.

- **Quando Utilizar**:
  Use este script para uma nova implantação do OnlyOffice em um ambiente de produção que requer alta performance e integração com o Nextcloud. É a versão recomendada para a maioria dos casos de uso.

- **Recursos Principais**:
  - Instala o RabbitMQ como pré-requisito para o modo de cluster do OnlyOffice.
  - Adiciona o repositório oficial do OnlyOffice e instala o `onlyoffice-documentserver`.
  - Configura o Nginx para expor o Document Server com um certificado SSL/TLS (se fornecido).
  - Automatiza a configuração da integração com o Nextcloud, definindo a URL do servidor e a chave secreta (`secret.json`).
  - Reinicia os serviços para aplicar as configurações.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x install_onlyoffice_server_v2.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./install_onlyoffice_server_v2.sh
     ```

### 2. `install_onlyoffice_server.sh` (Legado)

- **Função**:
  Versão anterior do script de instalação. Realiza uma instalação básica do OnlyOffice Document Server.

- **Quando Utilizar**:
  Este script é considerado **legado**. Use-o apenas se houver requisitos específicos de compatibilidade ou para fins de teste em ambientes mais antigos. Para novas instalações, prefira a `v2`.

### 3. `cleanup_onlyoffice.sh`

- **Função**:
  Remove completamente a instalação do OnlyOffice Document Server e suas dependências, incluindo configurações do Nginx e pacotes associados.

- **Quando Utilizar**:
  Use este script para desinstalar o OnlyOffice de forma limpa, seja para uma reinstalação do zero ou para liberar recursos do servidor. Ele garante que não restem arquivos de configuração órfãos.

- **Recursos Principais**:
  - Para os serviços `nginx` e `ds-converter`.
  - Remove os pacotes `onlyoffice-documentserver` e suas dependências.
  - Exclui os arquivos de configuração do Nginx relacionados ao OnlyOffice.
  - Limpa o cache de pacotes (`autoremove` e `autoclean`).

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x cleanup_onlyoffice.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./cleanup_onlyoffice.sh
     ```

### 4. `onlyoffice_troubleshooting_kit.sh`

- **Função**:
  Fornece um conjunto de ferramentas para diagnosticar e solucionar problemas comuns na instalação do OnlyOffice.

- **Quando Utilizar**:
  Execute este script quando encontrar erros de conexão, falhas na edição de documentos ou problemas de serviço. Ele ajuda a identificar a causa raiz, verificando logs, status de serviços e configurações.

- **Recursos Principais**:
  - **Verificação de Status**: Checa se os serviços essenciais (Nginx, RabbitMQ, OnlyOffice) estão ativos.
  - **Análise de Logs**: Exibe os logs mais recentes do Nginx e do OnlyOffice para identificar mensagens de erro.
  - **Teste de Conectividade**: Realiza testes de `curl` para verificar se o Document Server está acessível localmente.
  - **Validação de Configuração**: Verifica se os arquivos de configuração importantes existem e possuem as permissões corretas.

- **Como Utilizar**:
  1. **Tornar o script executável**:
     ```bash
     chmod +x onlyoffice_troubleshooting_kit.sh
     ```
  2. **Executar com `sudo`**:
     ```bash
     sudo ./onlyoffice_troubleshooting_kit.sh
     ```

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Distribuição baseada em Debian (Ubuntu Server recomendado).
- **Acesso**: Permissões de `root` ou um usuário com privilégios `sudo`.
- **Recursos**: Memória RAM e CPU suficientes para executar o Document Server (consulte a documentação oficial do OnlyOffice para requisitos detalhados).
- **Nome de Domínio**: Um FQDN (Fully Qualified Domain Name) é recomendado para acesso via HTTPS.

## 🔒 Notas de Segurança

- **Chave Secreta**: A integração entre o OnlyOffice e o Nextcloud depende de uma chave secreta. Certifique-se de que esta chave seja forte e mantida em sigilo.
- **Firewall**: Configure regras de firewall para permitir tráfego nas portas `80` (HTTP) e `443` (HTTPS), limitando o acesso apenas a redes confiáveis.
