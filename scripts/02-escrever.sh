#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 02-escrever.sh - grava chaves e mostra que replicaram em todos os nós.

titulo "Passo 2: escrita replicada"
nota "Um put vira uma entrada do log. O líder a envia aos seguidores via"
nota "AppendEntries e só a confirma (COMMIT) quando a MAIORIA a gravou."
nota "O etcdctl redireciona a escrita ao líder automaticamente."

rodar put /demo/universidade "UNISINOS" | filtra
rodar put /demo/autor1 "Gustavo" | filtra
rodar put /demo/autor2 "Pedro" | filtra

echo
nota "Lendo todas as chaves com prefixo /demo:"
rodar get /demo --prefix | filtra

echo
nota "Lendo /demo/universidade em CADA nó (--consistency=s: leitura local, sem passar pelo líder):"
for n in "${NOS[@]}"; do
  if is_running "$n"; then
    printf '%s[%s]%s ' "$NEGRITO" "$n" "$RESET"
    ctl_local "$n" get /demo/universidade --consistency=s --print-value-only 2>&1 | filtra
  fi
done

echo
nota "RAFT INDEX por nó (deve ser igual: todos aplicaram as mesmas entradas):"
status_table
ok "Dados replicados em todos os nós com o mesmo RAFT INDEX."
