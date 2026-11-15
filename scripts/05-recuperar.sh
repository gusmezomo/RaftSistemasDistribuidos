#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 05-recuperar.sh - religa os nós parados; eles alcançam o log do líder.

titulo "Passo 5: recuperação"
parados="$(stopped_nodes | tr '\n' ' ')"
if [ -z "${parados// /}" ]; then nota "Nenhum nó parado."; fi
nota "Os nós religados voltam como FOLLOWERS, com o log que tinham ao cair."
nota "O líder detecta que estão atrasados e reenvia as entradas faltantes via"
nota "AppendEntries (log matching) até todos terem o mesmo log."

for n in $(stopped_nodes); do
  printf '%s$ docker start %s%s\n' "$AMARELO" "$n" "$RESET"
  docker start "$n" >/dev/null
done
esperar_cluster
sleep 2   # tempo para a replicação alcançar os nós religados
mostrar_cluster

echo
nota "RAFT INDEX por nó (devem ser iguais):"
for n in "${NOS[@]}"; do
  printf '  %s: %s\n' "$n" "$(raft_index_of "$n")"
done

echo
nota "Lendo /demo/depois-da-falha em CADA nó (leitura local):"
for n in "${NOS[@]}"; do
  printf '%s[%s]%s ' "$NEGRITO" "$n" "$RESET"
  ctl_local "$n" get /demo/depois-da-falha --consistency=s --print-value-only 2>&1 | filtra
done
ok "Todos os nós, inclusive o que estava fora, têm a entrada commitada pelo líder."
