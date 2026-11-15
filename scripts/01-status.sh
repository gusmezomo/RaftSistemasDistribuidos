#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# 01-status.sh - mostra membros e status (líder, term, índice do log).

titulo "Passo 1: membros e status do cluster"
nota "member list: quem faz parte da configuração do Raft."
rodar member list -w table | filtra
echo
nota "endpoint status: IS LEADER indica o líder; RAFT TERM é o 'mandato' atual"
nota "(incrementa a cada eleição); RAFT INDEX é a posição no log replicado."
mostrar_cluster
