#!/bin/bash
# 1) Create working dir and JWT
mkdir eth-fork && cd eth-fork
openssl rand -hex 32 > jwt.hex

# 2) Save .env, docker-compose.yml, and Makefile (above)

# 3) Start
make up

# 4) Verify endpoints (from another machine or the host)
# Anvil (prefunded dev accounts etc.)
curl -s -X POST http://<HOST_IP>:8547 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_accounts","params":[]}'

# Reth (backing fork)
curl -s -X POST http://<HOST_IP>:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'

curl -s http://<HOST_IP>:5052/eth/v1/node/health

