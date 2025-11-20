#!/usr/bin/env sh
set -eu

BASE_ARGS="node --chain mainnet --datadir /data \
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --http.api eth,net,web3 \
  --authrpc.addr 0.0.0.0 --authrpc.port 8551 \
  --authrpc.jwtsecret /secrets/jwt.hex \
  --metrics 0.0.0.0:9001"

if [ "${RETH_TIP_HASH:-}" != "" ] && [ "${RETH_TIP_HASH}" != "null" ] && [ "${RETH_TIP_HASH}" != "undefined" ]; then
  echo "Using debug tip: ${RETH_TIP_HASH}"
  exec reth $BASE_ARGS --debug.tip "${RETH_TIP_HASH}"
else
  echo "No RETH_TIP_HASH provided; starting without --debug.tip"
  exec reth $BASE_ARGS
fi
