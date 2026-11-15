#!/usr/bin/env bash
# =============================================================================
# common.sh - funções compartilhadas pelos scripts da demonstração.
# Deve ser carregado com `source` (não é executado diretamente).
# =============================================================================

# Diretórios do projeto (resolvidos a partir deste arquivo)
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJETO_DIR="$(dirname "$SCRIPTS_DIR")"
COMPOSE_FILE="$PROJETO_DIR/docker-compose.yml"

NOS=(etcd1 etcd2 etcd3)
ENDPOINTS="http://etcd1:2379,http://etcd2:2379,http://etcd3:2379"

# --- Cores ANSI (somente quando a saída é um terminal) -----------------------
if [ -t 1 ]; then
  VERMELHO=$'\033[31m'; VERDE=$'\033[32m'; AMARELO=$'\033[33m'
  AZUL=$'\033[34m'; NEGRITO=$'\033[1m'; RESET=$'\033[0m'
else
  VERMELHO=""; VERDE=""; AMARELO=""; AZUL=""; NEGRITO=""; RESET=""
fi

titulo() { printf '\n%s== %s ==%s\n' "$NEGRITO$AZUL" "$*" "$RESET"; }
nota()   { printf '%s# %s%s\n' "$AZUL" "$*" "$RESET"; }
ok()     { printf '%s✔ %s%s\n' "$VERDE" "$*" "$RESET"; }
erro()   { printf '%s✘ %s%s\n' "$VERMELHO" "$*" "$RESET"; }

# compose: usa `docker compose` (v2) ou cai para `docker-compose` (v1)
compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" "$@"
  else
    docker-compose -f "$COMPOSE_FILE" "$@"
  fi
}

# is_running <nó>: sucesso se o container está em execução
is_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" = "true" ]
}

# running_nodes / stopped_nodes: listam os nós vivos / parados (um por linha)
running_nodes() {
  local n
  for n in "${NOS[@]}"; do
    if is_running "$n"; then echo "$n"; fi
  done
}
stopped_nodes() {
  local n
  for n in "${NOS[@]}"; do
    if ! is_running "$n"; then echo "$n"; fi
  done
}

# first_running: primeiro nó vivo (vazio se nenhum)
first_running() {
  local n
  for n in "${NOS[@]}"; do
    if is_running "$n"; then echo "$n"; return 0; fi
  done
  return 0
}

# ctl: executa etcdctl dentro de um nó vivo, contra os 3 endpoints.
# A imagem é distroless (sem shell): chamamos o etcdctl diretamente.
ctl() {
  local no
  no="$(first_running)"
  if [ -z "$no" ]; then erro "Nenhum nó em execução."; return 1; fi
  docker exec "$no" etcdctl --endpoints="$ENDPOINTS" \
    --dial-timeout=1s --command-timeout=3s "$@"
}

# ctl_local <nó> ...: etcdctl falando apenas com o próprio nó
ctl_local() {
  local no="$1"; shift
  docker exec "$no" etcdctl --endpoints=http://127.0.0.1:2379 \
    --dial-timeout=1s --command-timeout=3s "$@"
}

# rodar ...: mostra o comando em amarelo e o executa via ctl
rodar() {
  printf '%s$ etcdctl %s%s\n' "$AMARELO" "$*" "$RESET"
  ctl "$@"
}

# filtra: esconde os logs JSON de retry do cliente etcdctl
filtra() { grep -v '^{"level"' || true; }

# leader: imprime o nome do nó líder (vazio se não houver).
# O líder é o nó cujo "member_id" é igual ao campo "leader" do status.
leader() {
  local n json mid lid
  for n in $(running_nodes); do
    json="$(ctl_local "$n" endpoint status -w json 2>/dev/null || true)"
    mid="$(grep -o '"member_id":[0-9]*' <<<"$json" | head -n1 | cut -d: -f2 || true)"
    lid="$(grep -o '"leader":[0-9]*' <<<"$json" | head -n1 | cut -d: -f2 || true)"
    if [ -n "$mid" ] && [ "$mid" = "$lid" ]; then
      echo "$n"; return 0
    fi
  done
  return 0
}

# term_of <nó>: term atual do Raft segundo o nó
term_of() {
  ctl_local "$1" endpoint status -w json 2>/dev/null \
    | grep -oE '"raft_?[Tt]erm":[0-9]+' | head -n1 | cut -d: -f2 || true
}

# status_table: tabela de status dos 3 endpoints (líder, term, índice do log)
status_table() {
  # endpoint morto faz o etcdctl sair com erro; toleramos para continuar
  { ctl endpoint status -w table 2>&1 || true; } | filtra
}

# mostrar_cluster: tabela + nós rodando/parados + líder atual
mostrar_cluster() {
  status_table
  local r p l
  r="$(running_nodes | tr '\n' ' ')"; p="$(stopped_nodes | tr '\n' ' ')"
  printf 'Rodando: %s%s%s\n' "$VERDE" "${r:-nenhum}" "$RESET"
  printf 'Parados: %s%s%s\n' "$VERMELHO" "${p:-nenhum}" "$RESET"
  l="$(leader)"
  if [ -n "$l" ]; then
    printf '%sLíder: %s (term %s)%s\n' "$NEGRITO" "$l" "$(term_of "$l")" "$RESET"
  else
    printf '%sSem líder%s\n' "$VERMELHO" "$RESET"
  fi
}

# esperar_cluster: espera (até 40s) o cluster ficar saudável e com líder
esperar_cluster() {
  local i
  for i in $(seq 1 40); do
    if [ -n "$(first_running)" ] && ctl endpoint health >/dev/null 2>&1 \
       && [ -n "$(leader)" ]; then
      return 0
    fi
    sleep 1
  done
  erro "Cluster não ficou saudável em 40s (veja: docker compose logs)."
  return 1
}

# agora_ms: instante atual em milissegundos (fallback: segundos * 1000)
agora_ms() {
  local t
  t="$(date +%s%3N)"
  case "$t" in
    *N*) echo $(( $(date +%s) * 1000 )) ;;
    *)   echo "$t" ;;
  esac
}

# pausa: espera Enter, a menos que SEM_PAUSA=1
pausa() {
  if [ "${SEM_PAUSA:-0}" = "1" ]; then return 0; fi
  printf '\n%s[Enter para continuar]%s ' "$NEGRITO" "$RESET"
  read -r _ || true
  echo
}

# raft_index_of <nó>: RAFT INDEX do nó (campo raftIndex do status)
raft_index_of() {
  ctl_local "$1" endpoint status -w json 2>/dev/null \
    | grep -oE '"raftIndex":[0-9]+' | head -n1 | cut -d: -f2 || true
}
