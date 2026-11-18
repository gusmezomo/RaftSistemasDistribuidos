#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 01-status.sh - mostra membros e status (líder, term, índice do log).

titulo "Passo 1: membros e status do cluster"
nota "member list: quem faz parte da configuração do Raft."
rodar member list -w table | filtra
echo
nota "Status por nó: PAPEL indica o líder; SEGUE é quem o nó reconhece como líder;"
nota "TERM é o 'mandato' atual (incrementa a cada eleição); RAFT INDEX é a posição"
nota "no log replicado e APPLIED é até onde o nó já aplicou (commit)."
mostrar_cluster
