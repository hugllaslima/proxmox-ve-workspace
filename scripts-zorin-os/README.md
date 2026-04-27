# 🖥️ Scripts para Zorin OS

Este diretório contém scripts úteis e de manutenção para o **Zorin OS**.

## compatibilidade

| Sistema Operacional | Arquitetura | Dependências |
| ------------------- | ----------- | ------------------------------------ |
| Zorin OS (todas as versões) | `amd64` | `bash`, `sudo`, `ntfs-3g`, `fuser` |
| Ubuntu (e derivados) | `amd64` | `bash`, `sudo`, `ntfs-3g`, `fuser` |

---

## 📜 Estrutura de Diretórios

```
scripts-zorin-os/
├── read_only_mounted_disk.sh
└── README.md
```

## 🚀 Scripts Disponíveis

### 1. `read_only_mounted_disk.sh`

- **Função**:
  Corrige o problema de permissão "somente leitura" em partições NTFS, que frequentemente ocorre em sistemas de dual boot com Windows devido ao recurso "Fast Startup". O script automatiza o processo de desmontar a partição, corrigir o sistema de arquivos e remontá-la.

- **Quando Utilizar**:
  Use este script quando você não conseguir escrever dados em uma partição Windows (NTFS) a partir do Zorin OS, recebendo erros de "sistema de arquivos somente leitura". Isso geralmente acontece após o Windows ter sido desligado usando o modo de inicialização rápida ou hibernação.

- **Recursos Principais**:
  - **Desmontagem Forçada**: Utiliza `fuser` para encerrar processos que possam estar usando a partição, garantindo que ela possa ser desmontada com segurança.
  - **Correção do NTFS**: Executa o comando `ntfsfix` para limpar o estado de "hibernado" e corrigir inconsistências menores no sistema de arquivos NTFS.
  - **Remontagem Automática**: Tenta remontar todos os sistemas de arquivos listados no `/etc/fstab` após a correção, aplicando as permissões corretas.
  - **Verificação**: Exibe o status da montagem da partição após a execução para confirmar que o processo foi bem-sucedido.

- **Como Utilizar**:
  1. **Identificar o Disco**: Antes de executar, certifique-se de que os caminhos no script (`/media/hugllas-lima/Documentos` e `/dev/sdb1`) correspondem à sua configuração. Se necessário, edite o script para refletir seus pontos de montagem e dispositivo corretos.
  2. **Tornar o script executável**:
     ```bash
     chmod +x read_only_mounted_disk.sh
     ```
  3. **Executar com `sudo`**:
     ```bash
     sudo ./read_only_mounted_disk.sh
     ```
     O script solicitará a senha de superusuário para executar os comandos de montagem e correção.

## ⚠️ Pré-requisitos

- **Sistema Operacional**: Zorin OS ou outra distribuição baseada em Ubuntu.
- **Acesso**: Um usuário com privilégios `sudo`.
- **Utilitários**: `ntfs-3g` (geralmente instalado por padrão) e `fuser`.
- **Configuração**: O script assume uma configuração específica de ponto de montagem e dispositivo. **É crucial verificar e ajustar os caminhos dentro do script antes da primeira execução.**

## 💡 Dicas de Configuração (`/etc/fstab`)

Para garantir que sua partição NTFS seja montada corretamente durante o boot com as permissões adequadas, você pode adicioná-la ao arquivo `/etc/fstab`. O script `read_only_mounted_disk.sh` contém um guia detalhado sobre como fazer isso:

1.  **Obtenha o UUID** do seu disco com `sudo blkid /dev/sdb1`.
2.  **Edite o fstab**: `sudo nano /etc/fstab`.
3.  **Adicione a linha de configuração**, substituindo o UUID e o ponto de montagem pelos seus. Exemplo:
    ```
    UUID=FCEC347BEC34326E  /media/hugllas-lima/Documentos  ntfs-3g  uid=1000,gid=1000,umask=0022,defaults  0  0
    ```
Esta configuração ajuda a prevenir problemas de permissão no futuro, embora o Fast Startup do Windows ainda possa exigir a execução deste script ocasionalmente.
