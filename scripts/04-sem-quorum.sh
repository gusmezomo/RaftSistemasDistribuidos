#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 04-sem-quorum.sh - mata mais um nó: sem maioria, nada é commitado.

titulo "Passo 4: perda de quórum"
vivos="$(running_nodes | wc -l)"
if [ "$vivos" -lt 2 ]; then
  erro "São necessários pelo menos 2 nós vivos (rode 05-recuperar.sh e depois 03)."; exit 1
fi
lider="$(leader)"
if [ -z "$lider" ]; then erro "Sem líder atual."; exit 1; fi

nota "Matamos o líder atual ($lider). Sobra 1 nó: 1 de 3 NÃO é maioria."
nota "O sobrevivente tenta se eleger repetidamente (fase pre-candidate / pre-vote,"
nota "que evita inflar o term), mas nunca recebe votos suficientes. Sem líder"
nota "não há commit: isso evita SPLIT-BRAIN (dois líderes aceitando escritas"
nota "divergentes em partições diferentes)."
printf '%s$ docker kill %s%s\n' "$AMARELO" "$lider" "$RESET"
docker kill "$lider" >/dev/null
sleep 3

sobrev="$(first_running)"
echo
nota "Estado visto pelo sobrevivente ($sobrev):"
status_table
echo

nota "Tentando ESCREVER (precisa de quórum):"
printf '%s$ etcdctl put /demo/sem-quorum x%s\n' "$AMARELO" "$RESET"
if ctl_local "$sobrev" put /demo/sem-quorum x >/dev/null 2>&1; then
  erro "Inesperado: a escrita foi aceita."
else
  ok "escrita recusada (sem maioria não há commit)"
fi

nota "Tentando LER de forma linearizável (padrão; exige confirmar com o líder/quórum):"
printf '%s$ etcdctl get /demo/universidade%s\n' "$AMARELO" "$RESET"
if ctl_local "$sobrev" get /demo/universidade >/dev/null 2>&1; then
  erro "Inesperado: leitura linearizável funcionou."
else
  ok "leitura linearizável recusada (não dá para garantir o dado mais recente)"
fi

nota "Leitura serializável (--consistency=s): responde com o dado LOCAL, que pode estar desatualizado:"
printf '%s$ etcdctl get /demo/universidade --consistency=s%s\n' "$AMARELO" "$RESET"
ctl_local "$sobrev" get /demo/universidade --consistency=s 2>&1 | filtra
ok "leitura local funciona, mas sem garantia de ser a mais recente"
