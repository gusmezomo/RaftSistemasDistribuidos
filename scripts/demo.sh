#!/usr/bin/env bash
# demo.sh - roda toda a demonstração (00 → 05 + logs) com pausa entre os passos.
# Use SEM_PAUSA=1 para rodar sem esperar Enter.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

for passo in 00-subir 01-status 02-escrever 03-derrubar-lider 04-sem-quorum 05-recuperar logs-eleicao; do
  "$SCRIPTS_DIR/$passo.sh"
  pausa
done
ok "Demonstração concluída. Para limpar: ./scripts/99-limpar.sh"
