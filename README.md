# 🧱 Forked Ethereum L1 Dev Environment  
### Reth (Execution) • Lighthouse (Consensus) • Anvil (Dev RPC)

This stack lets you:

- Run a **mainnet-pruned** Ethereum L1 Execution Layer (Reth) for OP Stack testing  
- Use **Lighthouse** as your Beacon/Consensus Layer  
- Spin up **Anvil** for local testing & prefunded accounts  
- Bootstrap Reth with a **pruned snapshot** or full sync  
- Auto-start Reth at the latest tip (`--debug.tip`)  
- Aggressively **prune** to stay under ~300–400 GB of disk usage (≈1 month history)  

---

## 🪜 Setup Guide

### 1️⃣ Directory & JWT
```bash
mkdir eth-fork && cd eth-fork
openssl rand -hex 32 > jwt.hex
```

---

### 2️⃣ `.env`

```bash
# Upstream Ethereum RPCs
MAINNET_RPC_HTTPS=https://ethereum-rpc.publicnode.com
MAINNET_RPC_WSS=wss://ethereum-rpc.publicnode.com

# Mainnet pruned snapshot URL (replace with your trusted provider)
RETH_ERA_URL=https://<provider>/ethereum/pruned-era/

# Docker Compose project & Reth engine URLs
COMPOSE_PROJECT_NAME=ethfork
RETH_ENGINE_URL=http://10.200.0.10:8551
RETH_RPC_URL=http://10.200.0.10:8545

# Optional; set automatically when using make up-auto
RETH_TIP_HASH=
LIGHTHOUSE_NETWORK=mainnet
```

---

### 3️⃣ `reth.toml` (Aggressive Pruning)
```toml
# reth.toml — ~1 month (~220k blocks) of state & logs

[prune]
block_interval = 5

[prune.segments]
sender_recovery     = "full"
transaction_lookup  = "full"        # prune old tx lookup index
account_history     = { distance = 220_000 }
storage_history     = { distance = 220_000 }
receipts            = { distance = 250_000 }
```

Mount it to `/data/reth.toml` in your compose file.

---

### 4️⃣ `docker-compose.yml`

(… full compose omitted here for brevity; same as previous message …)

---

### 5️⃣ `start-reth.sh`

```bash
#!/usr/bin/env sh
set -eu

BASE_ARGS="node --chain mainnet --datadir /data   --http --http.addr 0.0.0.0 --http.port 8545   --authrpc.addr 0.0.0.0 --authrpc.port 8551   --authrpc.jwtsecret /secrets/jwt.hex"

if [ "${RETH_TIP_HASH:-}" != "" ] && [ "${RETH_TIP_HASH}" != "null" ] && [ "${RETH_TIP_HASH}" != "undefined" ]; then
  echo "Using debug tip: ${RETH_TIP_HASH}"
  exec reth $BASE_ARGS --debug.tip "${RETH_TIP_HASH}"
else
  echo "No RETH_TIP_HASH provided; starting without --debug.tip"
  exec reth $BASE_ARGS
fi
```

Make it executable:
```bash
chmod +x start-reth.sh
```

---

### 6️⃣ `Makefile`

(… includes bootstrap-auto, bootstrap-import-url, prune-now, size, up-auto, etc. …)

---

## ✅ Typical Workflow

```bash
# One-time snapshot import
make bootstrap-import-url

# Start everything with auto-tip
make up-auto

# Monitor pruning & disk usage
make size
make prune-now
make size
```

---

## ⚙️ Disk Targets

| Mode | History kept | Expected Disk |
|------|---------------|----------------|
| Aggressive (~100k blocks) | ~2 weeks | ~200–300 GB |
| Balanced (~220k blocks) | ~1 month | ~300–450 GB |
| Relaxed (~500k blocks) | ~2 months | ~500–700 GB |

---

## 💡 Notes

- Use a **pruned** snapshot (not archive) for bootstrap to stay < 400 GB.  
- Your pruning config keeps about 1 month of history (~220–250k blocks).  
- `make prune-now` reclaims space; otherwise pruning runs automatically.  
- For OP Stack contract testing, this gives you a real EL + CL with low disk usage.  
