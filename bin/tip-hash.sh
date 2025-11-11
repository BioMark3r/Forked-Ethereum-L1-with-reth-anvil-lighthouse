#!/usr/bin/env bash
set -euo pipefail

# Build endpoint list: env first (if set), then fallbacks
ENDPOINTS=()
[[ -n "${MAINNET_RPC_HTTPS:-}" ]] && ENDPOINTS+=("${MAINNET_RPC_HTTPS}")
ENDPOINTS+=("https://cloudflare-eth.com")
ENDPOINTS+=("https://ethereum-rpc.publicnode.com")

json_rpc() {
  curl -sS --max-time 6 -H 'Content-Type: application/json' -X POST "$1" --data "$2" || true
}

extract_hash() {
  # Prefer jq if present, otherwise regex
  if command -v jq >/dev/null 2>&1; then
    jq -r '.result.hash' 2>/dev/null
  else
    grep -oE '"hash":"0x[0-9a-fA-F]{64}"' | head -n1 | sed -E 's/.*"hash":"([^"]+)".*/\1/'
  fi
}

extract_num() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.result' 2>/dev/null
  else
    grep -oE '"result":"0x[0-9a-fA-F]+"' | head -n1 | sed -E 's/.*"result":"([^"]+)".*/\1/'
  fi
}

for URL in "${ENDPOINTS[@]}"; do
  [[ -n "$URL" ]] || continue
  >&2 echo "• trying $URL"

  # Primary: latest block directly
  RESP="$(json_rpc "$URL" '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}')"
  HASH="$(printf '%s' "$RESP" | extract_hash || true)"
  if [[ "$HASH" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    echo "$HASH"; exit 0
  fi

  # Fallback: get number then fetch by number
  BNRESP="$(json_rpc "$URL" '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}')"
  NUM="$(printf '%s' "$BNRESP" | extract_num || true)"
  if [[ "$NUM" =~ ^0x[0-9a-fA-F]+$ ]]; then
    RESP2="$(json_rpc "$URL" "$(printf '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["%s", false]}' "$NUM")")"
    HASH2="$(printf '%s' "$RESP2" | extract_hash || true)"
    if [[ "$HASH2" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
      echo "$HASH2"; exit 0
    fi
  fi
done

echo "null"

