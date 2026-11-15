#!/usr/bin/env bash
# logs-eleicao.sh - extrai dos logs dos containers os eventos de eleição do Raft.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

titulo "Eventos de eleição do Raft (extraídos dos logs)"
nota "became candidate/leader/follower, elected leader, lost leader..."

# Sed para trocar os IDs hex dos membros pelos nomes (via member list)
sed_ids=()
while IFS=, read -r id _ nome _; do
  id="${id// /}"; nome="${nome// /}"
  if [ -n "$id" ] && [ -n "$nome" ]; then sed_ids+=(-e "s/\\b$id\\b/$nome/g"); fi
done < <(ctl member list 2>/dev/null | filtra || true)

compose logs --no-color 2>/dev/null \
  | { grep -E 'became (pre-candidate|candidate|leader|follower)|elected leader|lost leader' || true; } \
  | sed -nE 's/^([^ ]+) *\| *\{.*"ts":"[0-9-]+T([0-9:.]+)[^"]*".*"msg":"([^"]*)".*/\2 \1 \3/p' \
  | sed -E 's/raft\.node: //' \
  | { if [ ${#sed_ids[@]} -gt 0 ]; then sed -E "${sed_ids[@]}"; else cat; fi; } \
  | sort
