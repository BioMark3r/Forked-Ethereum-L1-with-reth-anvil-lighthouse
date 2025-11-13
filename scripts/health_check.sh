#!/usr/bin/env bash
set -euo pipefail

RETH_RPC_URL="${RETH_RPC_URL:-http://127.0.0.1:8545}"
LIGHTHOUSE_URL="${LIGHTHOUSE_URL:-http://127.0.0.1:5052}"
ANVIL_RPC_URL="${ANVIL_RPC_URL:-http://127.0.0.1:8547}"
MAX_BLOCK_LAG="${MAX_BLOCK_LAG:-3}"

usage() {
  cat <<USAGE
Health check for Reth (EL), Lighthouse (CL), and Anvil.
Environment overrides:
  RETH_RPC_URL      (default: $RETH_RPC_URL)
  LIGHTHOUSE_URL    (default: $LIGHTHOUSE_URL)
  ANVIL_RPC_URL     (default: $ANVIL_RPC_URL)
  MAX_BLOCK_LAG     (default: $MAX_BLOCK_LAG)
Exits non-zero on failure.
USAGE
}

jq_check() { command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 2; }; }

hex_to_dec() {
  python3 - <<'PY' "$1"
import sys
x=sys.argv[1]
print(int(x,16))
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --reth) RETH_RPC_URL="$2"; shift 2 ;;
    --lighthouse) LIGHTHOUSE_URL="$2"; shift 2 ;;
    --anvil) ANVIL_RPC_URL="$2"; shift 2 ;;
    --lag) MAX_BLOCK_LAG="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" ; usage ; exit 1 ;;
  esac
done

jq_check

fail() { echo "❌ $*"; exit 1; }
ok()   { echo "✅ $*"; }

# 1) Lighthouse health
LH_CODE="$(curl -s -o /dev/null -w "%{http_code}" "$LIGHTHOUSE_URL/eth/v1/node/health" || true)"
if [[ "$LH_CODE" != "200" && "$LH_CODE" != "206" ]]; then
  fail "Lighthouse health expected 200/206, got $LH_CODE at $LIGHTHOUSE_URL/eth/v1/node/health"
else
  ok "Lighthouse health $LH_CODE"
fi

# 2) Reth blockNumber
EL_NUM_HEX="$(curl -s -X POST "$RETH_RPC_URL" -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' | jq -r '.result' || true)"
[[ "$EL_NUM_HEX" =~ ^0x[0-9a-fA-F]+$ ]] || fail "Invalid EL block number from $RETH_RPC_URL: $EL_NUM_HEX"
EL_NUM="$(hex_to_dec "$EL_NUM_HEX")"
ok "Reth blockNumber: $EL_NUM ($EL_NUM_HEX)"

# 3) Anvil blockNumber + chainId
AN_NUM_HEX="$(curl -s -X POST "$ANVIL_RPC_URL" -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}' | jq -r '.result.number' || true)"
[[ "$AN_NUM_HEX" =~ ^0x[0-9a-fA-F]+$ ]] || fail "Invalid Anvil latest.number from $ANVIL_RPC_URL: $AN_NUM_HEX"
AN_NUM="$(hex_to_dec "$AN_NUM_HEX")"

CHAIN_ID_HEX="$(curl -s -X POST "$ANVIL_RPC_URL" -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":2,"method":"eth_chainId","params":[]}' | jq -r '.result' || true)"
[[ "$CHAIN_ID_HEX" =~ ^0x[0-9a-fA-F]+$ ]] || fail "Invalid chainId from $ANVIL_RPC_URL: $CHAIN_ID_HEX"
CHAIN_ID="$(hex_to_dec "$CHAIN_ID_HEX")"

if [[ "$CHAIN_ID" -ne 1 ]]; then
  fail "Anvil chainId=$CHAIN_ID (expected 1)"
fi
ok "Anvil blockNumber: $AN_NUM ($AN_NUM_HEX), chainId: $CHAIN_ID"

# 4) Compare EL vs Anvil tip
DELTA=$(( EL_NUM - AN_NUM ))
if (( DELTA < 0 )); then DELTA=$(( -DELTA )); fi
if (( DELTA > MAX_BLOCK_LAG )); then
  fail "Block lag too high: delta=$DELTA (max $MAX_BLOCK_LAG)"
else
  ok "Block lag within threshold: delta=$DELTA (<= $MAX_BLOCK_LAG)"
fi

echo "🎯 Health checks passed"
