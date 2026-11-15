# raft-etcd-demo

Demonstração prática do algoritmo de consenso **Raft** usando um cluster **etcd de 3 nós** com Docker Compose.

Trabalho de Sistemas Distribuídos — UNISINOS.
Autores: **Gustavo Mezomo** e **Pedro Gustavo Thomas**.

## Objetivo

Mostrar, na prática, como o Raft funciona dentro do etcd: eleição de líder, replicação do log, commit por maioria, tolerância a falha de um nó, perda de quórum e recuperação de um nó atrasado.

## O que é o Raft (resumo)

Raft é um algoritmo de consenso que mantém um **log replicado** consistente entre vários nós. Cada nó é *follower*, *candidate* ou *leader*. O líder recebe as escritas, as replica via **AppendEntries** e só as confirma (**commit**) quando a **maioria (quórum)** gravou. O líder envia **heartbeats**; se um seguidor fica sem ouvi-lo por um **election timeout**, vira candidato e inicia uma eleição num novo **term** (mandato). Exigir maioria impede o **split-brain**: com n = 2f+1 nós, o cluster tolera f falhas (3 nós → 1 falha).

## Requisitos

- Docker + Docker Compose v2
- bash
- Linux, macOS ou WSL

## Estrutura

```
raft-etcd-demo/
├── docker-compose.yml       # cluster de 3 nós etcd (comentado)
├── README.md
└── scripts/
    ├── common.sh            # funções compartilhadas
    ├── 00-subir.sh          # sobe o cluster e espera o 1º líder
    ├── 01-status.sh         # member list + status (líder, term, índice do log)
    ├── 02-escrever.sh       # grava chaves e mostra a replicação nos nós
    ├── 03-derrubar-lider.sh # mata o líder e mede a nova eleição
    ├── 04-sem-quorum.sh     # mata mais um nó: sem maioria, sem commit
    ├── 05-recuperar.sh      # religa os nós; eles alcançam o log
    ├── logs-eleicao.sh      # extrai dos logs os eventos de eleição
    ├── observar.sh          # painel ao vivo (2º terminal)
    ├── demo.sh              # roda tudo com pausa entre os passos
    └── 99-limpar.sh         # remove containers, rede e volumes
```

## Como rodar

Demo completa (pausa com Enter entre os passos):

```bash
./scripts/demo.sh
```

Sem pausas: `SEM_PAUSA=1 ./scripts/demo.sh`

Passo a passo:

```bash
./scripts/00-subir.sh
./scripts/01-status.sh
./scripts/02-escrever.sh
./scripts/03-derrubar-lider.sh
./scripts/04-sem-quorum.sh
./scripts/05-recuperar.sh
./scripts/logs-eleicao.sh
./scripts/99-limpar.sh
```

**Dica:** deixe `./scripts/observar.sh` aberto em um segundo terminal para ver líder, term e RAFT INDEX mudando ao vivo.

Todo acesso ao cluster é via `docker exec <nó> etcdctl ...` (nenhuma porta é exposta).

## O que cada passo mostra

| Passo | O que mostra | Conceito do Raft |
|-------|--------------|------------------|
| 00 | Cluster sobe e elege um líder | Follower → candidate → leader, term, election timeout |
| 01 | Membros, líder, term e índice do log | Estado do cluster, term |
| 02 | Escritas aparecem nos 3 nós com o mesmo RAFT INDEX | AppendEntries, commit por maioria, replicação do log |
| 03 | `docker kill` no líder; novo líder com term maior e tempo em ms; dados e novas escritas continuam | Heartbeat, election timeout, nova eleição, tolerância a f falhas |
| 04 | Com 1 nó vivo, `put` e leitura linearizável falham; leitura `--consistency=s` funciona | Quórum, impossibilidade de commit, prevenção de split-brain |
| 05 | Nós religados alcançam o log; RAFT INDEX igual nos 3 | Log matching, catch-up via AppendEntries |
| logs | Linha do tempo das eleições com nomes dos nós | Pre-vote, candidate, leader, term |

## Capturas de tela

A pasta `capturas/` traz uma imagem (`.png`) e o texto (`.txt`) da saída de cada etapa de uma execução real do `demo.sh`.

## Trocar a versão do etcd

```bash
ETCD_VERSION=v3.5.16 ./scripts/demo.sh
```

(Rode `./scripts/99-limpar.sh` antes ao trocar de versão.)

## Solução de problemas

- **Nome de container já em uso:** sobrou um cluster anterior. Rode `./scripts/99-limpar.sh` (ou `docker rm -f etcd1 etcd2 etcd3`).
- **Imagem não baixa:** verifique a internet e o acesso a `quay.io`; teste `docker pull quay.io/coreos/etcd:v3.5.17`.
- **Cluster não sobe:** veja `docker compose logs` (na raiz do projeto) e confirme que `99-limpar.sh` foi executado para apagar volumes antigos.

## Referências

- Ongaro, D.; Ousterhout, J. *In Search of an Understandable Consensus Algorithm*. USENIX ATC, 2014.
- Ongaro, D. *Consensus: Bridging Theory and Practice* (tese de doutorado), Stanford, 2014.
- https://raft.github.io
- Documentação do etcd: https://etcd.io/docs/
