# Scripts de Limpeza para Templates Cloud-Init

Estes scripts de limpeza foram desenvolvidos para preparar as máquinas virtuais antes que elas se tornem Templates.

Antes de transformar a VM em um template, é necessário acessá-la e executar o script correspondente ao seu sistema operacional. O objetivo principal destes scripts é realizar tarefas de preparação da imagem, tais como:

- Instalação do `qemu-guest-agent`.
- Limpeza de logs do sistema.
- Limpeza do histórico de comandos aplicados (bash history, etc).
- Outras remoções necessárias para garantir que o template seja uma imagem "limpa" e pronta para ser clonada via Cloud-Init.

## Scripts e Distribuições

Utilize o script adequado para a imagem do sistema operacional em questão:

- **`alpine-version.sh`**: Para a imagem **Alpine Linux**.
- **`debian_versions.sh`**: Para as imagens **Debian**.
- **`oracle-versions.sh`**: Para as imagens **Oracle Linux**.
- **`rhel_versions.sh`**: Para as imagens **RHEL**, **AlmaLinux**, **Rocky Linux** e **CentOS**.
- **`ubuntu_versions.sh`**: Para as imagens **Ubuntu**.
