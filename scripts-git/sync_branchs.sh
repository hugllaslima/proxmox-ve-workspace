#!/bin/bash

# ==============================================================================
# SCRIPT PARA SINCRONIZAR BRANCHES COM O REPOSITÓRIO REMOTO (ORIGIN)
# ==============================================================================
#
# Este script automatiza o processo de atualização das branches locais `main`
# e `develop` com suas respectivas versões no repositório remoto (`origin`).
# Ele foi projetado para garantir que seu ambiente de desenvolvimento local
# esteja sempre alinhado com as branches principais do projeto.
#
# O que o script faz?
# 1. Salva a branch atual em que você está trabalhando.
# 2. Muda para a branch `main`, baixa e aplica as últimas alterações (`git pull`).
# 3. Muda para a branch `develop`, baixa e aplica as últimas alterações (`git pull`).
# 4. Retorna para a branch original que você estava usando antes de executar o script.
# 5. Exibe um resumo das suas branches locais.
#
# Pré-requisitos:
# - O repositório deve ter um remote chamado `origin`.
# - As branches `main` e `develop` devem existir tanto localmente quanto no `origin`.
#
# Como usar:
# 1. Navegue até a raiz do seu repositório Git.
# 2. Execute o comando: ./sync_branchs.sh
#
# ==============================================================================

# Salva o nome da branch atual
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🔄 Sincronizando branches... Você está na branch: $CURRENT_BRANCH"
echo "----------------------------------------------------"

# Sincroniza a branch 'main'
echo "➡️  Mudando para a branch 'main'..."
git checkout main
echo "⏬  Atualizando 'main' a partir do 'origin'..."
git pull origin main
echo "✅  Branch 'main' atualizada com sucesso."
echo "----------------------------------------------------"

# Sincroniza a branch 'develop'
echo "➡️  Mudando para a branch 'develop'..."
git checkout develop
echo "⏬  Atualizando 'develop' a partir do 'origin'..."
git pull origin develop
echo "✅  Branch 'develop' atualizada com sucesso."
echo "----------------------------------------------------"

# Retorna para a branch original
echo "↪️  Retornando para a branch '$CURRENT_BRANCH'..."
git checkout "$CURRENT_BRANCH"

echo "🚀 Pronto para trabalhar!"
echo "✅ Todas as branches foram sincronizadas com sucesso!"
echo "----------------------------------------------------"
echo "Resumo das branches locais:"
git branch -v
