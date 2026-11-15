#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 00-subir.sh - sobe o cluster de 3 nós e espera a primeira eleição de líder.

titulo "Passo 0: subindo o cluster etcd (3 nós)"
nota "Ao iniciar, os 3 nós são FOLLOWERS. Nenhum ouve um líder, então o primeiro"
nota "cujo election timeout expira vira CANDIDATE (term 1), pede votos e, com a"
nota "maioria (2 de 3), vira LEADER. Depois disso envia heartbeats periódicos."

compose up -d --quiet-pull 2>&1 | { grep -vE "^ (Image|Network|Container|[0-9a-f]{12}) " || true; }
nota "Aguardando o primeiro líder ser eleito..."
esperar_cluster
mostrar_cluster
ok "Cluster pronto: um líder eleito e os demais seguidores."
