#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 03-derrubar-lider.sh - mata o líder e mede o tempo da nova eleição.

titulo "Passo 3: falha do líder"
antigo="$(leader)"
if [ -z "$antigo" ]; then erro "Sem líder atual. Rode ./scripts/00-subir.sh antes."; exit 1; fi
term_antigo="$(term_of "$antigo")"
nota "Líder atual: $antigo (term $term_antigo)."
nota "Usamos 'docker kill' (falha abrupta, sem desligamento limpo). Os seguidores"
nota "deixam de receber heartbeats; ao estourar o election timeout (~1-2 s) um"
nota "deles vira CANDIDATE com term+1, pede votos e, com maioria, vira LEADER."

t0="$(agora_ms)"
printf '%s$ docker kill %s%s\n' "$AMARELO" "$antigo" "$RESET"
docker kill "$antigo" >/dev/null

novo=""
for _ in $(seq 1 75); do   # 75 x 0,2s = ~15s
  novo="$(leader)"
  if [ -n "$novo" ] && [ "$novo" != "$antigo" ]; then break; fi
  novo=""
  sleep 0.2
done
t1="$(agora_ms)"

if [ -z "$novo" ]; then erro "Nenhum novo líder em ~15s."; exit 1; fi
term_novo="$(term_of "$novo")"
ok "Novo líder: $novo | term $term_antigo → $term_novo | eleição levou $((t1 - t0)) ms"
if [ "$term_novo" -gt "$term_antigo" ]; then
  ok "O term aumentou: cada eleição inicia um novo mandato."
fi

echo
mostrar_cluster
echo
nota "Os dados continuam disponíveis (estavam commitados na maioria):"
rodar get /demo --prefix | filtra
echo
nota "O cluster com 2 nós ainda tem quórum (2 de 3) e aceita escritas:"
rodar put /demo/depois-da-falha "escrito com o lider antigo fora" | filtra
ok "Escrita aceita pelo novo líder."
