# Forked-Ethereum-L1-with-reth-anvil-lighthouse

# 🧱 Forked Ethereum L1 Dev Environment
### Reth (Execution) • Lighthouse (Consensus) • Anvil (Dev RPC)

This stack lets you:
- Fork Ethereum L1 using **Reth** with automatic `--debug.tip` from the latest block
- Run **Lighthouse** as the consensus layer driving Reth
- Use **Anvil** for testing, prefunded accounts, and local transactions
- Access everything on your LAN via static IPs
- Optionally pin Anvil to a specific block number

---

## 🪜 Setup Guide

### 1️⃣ Directory & JWT
```bash
mkdir eth-fork && cd eth-fork
openssl rand -hex 32 > jwt.hex
```

### 2️⃣ `.env`
```bash
MAINNET_RPC_HTTPS=https://ethereum-rpc.publicnode.com
MAINNET_RPC_WSS=wss://ethereum-rpc.publicnode.com
LIGHTHOUSE_NETWORK=mainnet
RETH_ENGINE_URL=http://10.200.0.10:8551
RETH_RPC_URL=http://10.200.0.10:8545
COMPOSE_PROJECT_NAME=ethfork
RETH_TIP_HASH=
```

### 3️⃣ `docker-compose.yml`
```yaml
services:
  reth-fork:
    image: ghcr.io/paradigmxyz/reth:latest
    container_name: reth-fork
    restart: unless-stopped
    env_file: [.env]
    volumes:
      - reth_data:/data
      - ./jwt.hex:/secrets/jwt.hex:ro
    networks:
      ethnet:
        ipv4_address: 10.200.0.10
    ports:
      - "8545:8545"
      - "8551:8551"
    entrypoint: ["/bin/sh","-c"]
    command: ["if [ -n "$RETH_TIP_HASH" ] && [ "$RETH_TIP_HASH" != "undefined" ] && [ "$RETH_TIP_HASH" != "null" ]; then echo Using debug tip: $RETH_TIP_HASH; exec reth node --chain mainnet --datadir /data --http --http.addr 0.0.0.0 --http.port 8545 --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /secrets/jwt.hex --debug.tip $RETH_TIP_HASH; else echo No RETH_TIP_HASH provided; exec reth node --chain mainnet --datadir /data --http --http.addr 0.0.0.0 --http.port 8545 --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /secrets/jwt.hex; fi"]

  lighthouse:
    image: sigp/lighthouse:latest
    container_name: lighthouse
    restart: unless-stopped
    depends_on:
      - reth-fork
    entrypoint: ["lighthouse"]
    env_file: [.env]
    networks:
      ethnet:
        ipv4_address: 10.200.0.11
    volumes:
      - ./jwt.hex:/secrets/jwt.hex:ro
    ports:
      - "5052:5052"
    command:
      - bn
      - --network
      - ${LIGHTHOUSE_NETWORK:-mainnet}
      - --execution-endpoint
      - ${RETH_ENGINE_URL}
      - --execution-jwt
      - /secrets/jwt.hex
      - --checkpoint-sync-url
      - https://mainnet.checkpoint.sigp.io
      - --http
      - --http-address
      - 0.0.0.0
      - --http-port
      - "5052"

  anvil:
    image: ghcr.io/foundry-rs/foundry:latest
    container_name: anvil
    restart: unless-stopped
    depends_on:
      - reth-fork
    networks:
      ethnet:
        ipv4_address: 10.200.0.12
    ports:
      - "8547:8547"
    entrypoint: ["anvil"]
    command:
      - --fork-url
      - http://10.200.0.10:8545
      - --host
      - 0.0.0.0
      - --port
      - "8547"
      - --chain-id
      - "1"

volumes:
  reth_data:

networks:
  ethnet:
    driver: bridge
    ipam:
      config:
        - subnet: 10.200.0.0/16
```

### 4️⃣ `Makefile`
```makefile
SHELL := /bin/bash
.ONESHELL:
-include .env

up-auto:
	@TIP=""
	@if [ -n "$(MAINNET_RPC_HTTPS)" ]; then 	  TIP=$$(curl -s -X POST "$(MAINNET_RPC_HTTPS)" 	    -H 'Content-Type: application/json' 	    --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}' 	    | jq -r '.result.hash'); 	fi ; 	if [ -n "$$TIP" ] && [ "$$TIP" != "null" ]; then 	  echo "📌 Using Reth tip $$TIP"; 	  RETH_TIP_HASH=$$TIP docker compose up -d reth-fork; 	else 	  echo "ℹ️ No valid tip; starting Reth without --debug.tip"; 	  RETH_TIP_HASH= docker compose up -d reth-fork; 	fi ; 	docker compose up -d lighthouse ; 	docker compose up -d anvil

up:
	docker compose up -d reth-fork lighthouse anvil

up-pin:
	@[ -n "$(BLOCK)" ] || { echo "Usage: make up-pin BLOCK=<number>"; exit 1; }
	docker compose up -d reth-fork lighthouse
	FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil

logs:
	docker compose logs -f

check-fork:
	@echo "Reth latest:"
	@curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' 	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}' | jq -r '.result.hash'
	@echo "Anvil latest:"
	@curl -s -X POST http://127.0.0.1:8547 -H 'Content-Type: application/json' 	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}' | jq -r '.result.hash'
```

---

## ✅ Usage
```bash
make up-auto      # start with auto-tip
make up-pin BLOCK=19304240  # pin Anvil to a block
make up           # no auto-tip
```

---

## 🔍 Verify
```bash
curl -s -o /dev/null -w "%{http_code}
" http://127.0.0.1:5052/eth/v1/node/health
curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
curl -s -X POST http://127.0.0.1:8547 -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
make check-fork
```

---

## ⚙️ Troubleshooting

| Symptom | Likely Cause | Fix |
|----------|---------------|-----|
| Lighthouse `000` | Port not exposed or host firewall | Ensure `ports: "5052:5052"` and open port |
| Lighthouse `timeout` | Wrong EL IP | Check `.env → RETH_ENGINE_URL` and `docker inspect` |
| Anvil not listening | Bad flag or fork URL | Use minimal command, confirm Reth RPC IP |
| ChainId ≠ 1 | Anvil started before Reth ready | Restart Anvil |
| `WARN RETH_TIP_HASH not set` | Cosmetic Compose warning | Add `RETH_TIP_HASH=` to `.env` |

---

## 🧹 Reset
```bash
docker compose down -v --remove-orphans
docker network prune -f
docker compose up -d
```

**Happy hacking! ⚡**
