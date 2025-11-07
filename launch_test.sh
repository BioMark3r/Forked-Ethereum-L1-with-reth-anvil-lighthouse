#!/bin/bash

# Start
make up

# Verify endpoints (from another machine or the host)
# Anvil (prefunded dev accounts etc.)
curl -s -X POST http://<HOST_IP>:8547 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_accounts","params":[]}'

# Reth (backing fork)
curl -s -X POST http://<HOST_IP>:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'

curl -s http://<HOST_IP>:5052/eth/v1/node/health

