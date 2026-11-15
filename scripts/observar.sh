#!/usr/bin/env bash
# observar.sh - painel ao vivo (atualiza a cada 1s). Use em um 2º terminal.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

while true; do
  saida="$( { printf '%sPainel Raft/etcd - %s (Ctrl+C sai)%s\n\n' "$NEGRITO" "$(date +%T)" "$RESET"
              if [ -n "$(first_running)" ]; then mostrar_cluster; else echo "Nenhum nó rodando."; fi; } 2>&1 )"
  clear
  printf '%s\n' "$saida"
  sleep 1
done
