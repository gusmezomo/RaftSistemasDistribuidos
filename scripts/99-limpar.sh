#!/usr/bin/env bash
# 99-limpar.sh - derruba o cluster e remove containers, rede e volumes.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

titulo "Limpando o ambiente"
compose down -v --remove-orphans
ok "Ambiente removido."
