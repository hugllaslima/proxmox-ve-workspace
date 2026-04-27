# Política de Segurança

## 🛡️ Visão Geral

Este documento descreve as políticas de segurança para o repositório **Proxmox VE Automation Scripts**. Como este projeto contém scripts que executam com privilégios elevados em infraestruturas críticas, a segurança é uma prioridade fundamental.

## 🔒 Versões Suportadas

Atualmente, oferecemos suporte de segurança para as seguintes versões:

| Versão | Suporte de Segurança |
| ------- | ------------------- |
| main (latest) | ✅ |
| Releases anteriores | ❌ |

## 🚨 Relatando Vulnerabilidades

### Como Reportar

Se você descobrir uma vulnerabilidade de segurança, **NÃO** abra uma issue pública. Em vez disso:

1. **Envie um email para:** hugllaslima@gmail.com
2. **Assunto:** `[SECURITY] Vulnerabilidade em proxmox-ve-workspace`
3. **Inclua:**
   - Descrição detalhada da vulnerabilidade
   - Passos para reproduzir o problema
   - Impacto potencial
   - Versão afetada
   - Sugestões de correção (se houver)

### Processo de Resposta

- **Confirmação:** Responderemos em até 48 horas
- **Investigação:** Análise completa em até 7 dias
- **Correção:** Patch de segurança em até 14 dias (dependendo da complexidade)
- **Divulgação:** Coordenada após a correção estar disponível

## ⚠️ Considerações de Segurança Críticas

### 🔐 Execução com Privilégios Elevados

**ATENÇÃO:** Todos os scripts deste repositório requerem privilégios de root/sudo e podem:

- Modificar configurações críticas do sistema
- Alterar configurações de SSH e firewall
- Instalar/remover pacotes do sistema
- Acessar e modificar dados sensíveis
- Reiniciar serviços críticos

### 🚫 Riscos Identificados

#### 1. **Scripts SSH (CRÍTICO)**
- `add_ssh_key_public_login_block.sh` pode **bloquear acesso SSH** se mal configurado
- Desabilitação de autenticação por senha sem chave SSH válida = **lockout total**
- Configuração `NOPASSWD` para sudo reduz significativamente a segurança

#### 2. **Scripts de Backup (ALTO)**
- Acesso a dados sensíveis durante backup
- Possível exposição de credenciais em logs
- Dependência de dispositivos externos (USB)

#### 3. **Scripts de VM/Container (MÉDIO)**
- Modificação de configurações do Proxmox VE
- Criação de recursos com configurações inseguras
- Possível consumo excessivo de recursos

#### 4. **Scripts de Monitoramento (BAIXO)**
- Exposição de métricas do sistema
- Possível vazamento de informações sobre infraestrutura

## 🛡️ Práticas de Segurança Recomendadas

### Para Usuários

#### ✅ SEMPRE Faça:

1. **Backup Completo** antes de executar qualquer script
2. **Teste em ambiente isolado** primeiro
3. **Revise o código** dos scripts antes da execução
4. **Mantenha acesso alternativo** (console físico/IPMI) ao executar scripts SSH
5. **Use usuários dedicados** para automação (não root direto)
6. **Monitore logs** durante e após execução
7. **Valide configurações** após execução dos scripts

#### ❌ NUNCA Faça:

1. **Execute scripts em produção** sem teste prévio
2. **Modifique scripts** sem entender completamente o impacto
3. **Compartilhe credenciais** em código ou logs
4. **Execute múltiplos scripts** simultaneamente sem coordenação
5. **Ignore avisos** ou confirmações dos scripts
6. **Use em sistemas críticos** sem plano de recuperação

### Para Desenvolvedores

#### 🔒 Diretrizes de Código Seguro:

1. **Validação de Entrada:**
   - Sempre validar dados de entrada do usuário
   - Sanitizar caminhos de arquivo
   - Verificar permissões antes de operações

2. **Gerenciamento de Credenciais:**
   - Nunca hardcode credenciais
   - Use variáveis de ambiente ou arquivos `.env`
   - Implemente rotação de credenciais

3. **Logging Seguro:**
   - Não registre informações sensíveis
   - Use níveis de log apropriados
   - Implemente rotação de logs

4. **Tratamento de Erros:**
   - Falhe de forma segura
   - Não exponha informações internas em mensagens de erro
   - Implemente rollback quando possível

## 🔍 Auditoria e Monitoramento

### Logs Recomendados

Monitore os seguintes logs após execução dos scripts:

```bash
# Logs do sistema
sudo journalctl -u ssh.service -f
sudo journalctl -u sshd.service -f

# Logs de autenticação
sudo tail -f /var/log/auth.log

# Logs do Proxmox VE
sudo tail -f /var/log/pve/tasks/active

# Logs de sudo
sudo tail -f /var/log/sudo.log
```

### Indicadores de Comprometimento

Fique atento a:

- Logins SSH não autorizados
- Modificações inesperadas em arquivos de configuração
- Processos desconhecidos em execução
- Tráfego de rede anômalo
- Alterações não documentadas em usuários/grupos

## 🚨 Resposta a Incidentes

### Em Caso de Comprometimento:

1. **Isolamento Imediato:**
   - Desconecte o sistema da rede
   - Preserve evidências (logs, memória)

2. **Avaliação:**
   - Identifique o escopo do comprometimento
   - Determine vetores de ataque

3. **Contenção:**
   - Revogue credenciais comprometidas
   - Aplique patches de segurança
   - Restaure a partir de backups limpos

4. **Recuperação:**
   - Reconfigure sistemas afetados
   - Implemente controles adicionais
   - Monitore atividade anômala

## 📞 Contatos de Segurança

- **Email Principal:** hugllaslima@gmail.com
- **GitHub:** [@hugllaslima](https://github.com/hugllaslima)
- **Resposta Esperada:** 48 horas

## 📋 Histórico de Segurança

| Data | Tipo | Descrição | Status |
|------|------|-----------|--------|
| 2024-01-XX | Inicial | Criação da política de segurança | ✅ Implementado |

---

**⚠️ LEMBRETE IMPORTANTE:** Este repositório contém scripts poderosos que podem afetar significativamente a segurança e estabilidade de seus sistemas. Use com responsabilidade e sempre em conformidade com as políticas de segurança de sua organização.