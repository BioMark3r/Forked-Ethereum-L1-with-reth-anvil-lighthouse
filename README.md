# 🧱 Forked Ethereum L1 Dev Environment  
### Reth (Execution) • Lighthouse (Consensus) • Anvil (Dev RPC) • Prometheus • Grafana

This stack lets you:

- Run a **mainnet-pruned** Ethereum L1 Execution Layer (Reth) for OP Stack testing  
- Use **Lighthouse** as your Beacon/Consensus Layer  
- Spin up **Anvil** for local testing & prefunded accounts  
- Bootstrap Reth with a **pruned snapshot** or full sync  
- Auto-start Reth at the latest tip (`--debug.tip`)  
- Aggressively **prune** to stay under ~400 GB disk (≈1 month history)  
- Monitor health and metrics via **Prometheus** and **Grafana**  
- Snapshot & restore Reth’s data volume anytime  

---

## 🪜 Setup Overview

1️⃣ Generate a JWT secret  
```bash
mkdir eth-fork && cd eth-fork
openssl rand -hex 32 > jwt.hex
```

2️⃣ Create `.env`
```bash
MAINNET_RPC_HTTPS=https://ethereum-rpc.publicnode.com
MAINNET_RPC_WSS=wss://ethereum-rpc.publicnode.com
RETH_ERA_URL=https://<provider>/ethereum/pruned-era/
COMPOSE_PROJECT_NAME=ethfork
RETH_ENGINE_URL=http://10.200.0.10:8551
RETH_RPC_URL=http://10.200.0.10:8545
RETH_TIP_HASH=
LIGHTHOUSE_NETWORK=mainnet
```

3️⃣ Create `reth.toml`
```toml
[prune]
block_interval = 5

[prune.segments]
sender_recovery     = "full"
transaction_lookup  = "full"
account_history     = { distance = 220_000 }
storage_history     = { distance = 220_000 }
receipts            = { distance = 250_000 }
```

4️⃣ Create `start-reth.sh`
```bash
#!/usr/bin/env sh
set -eu

BASE_ARGS="node --chain mainnet --datadir /data   --http --http.addr 0.0.0.0 --http.port 8545   --authrpc.addr 0.0.0.0 --authrpc.port 8551   --authrpc.jwtsecret /secrets/jwt.hex   --metrics --metrics.addr 0.0.0.0 --metrics.port 9001"

if [ "${RETH_TIP_HASH:-}" != "" ] && [ "${RETH_TIP_HASH}" != "null" ] && [ "${RETH_TIP_HASH}" != "undefined" ]; then
  echo "Using debug tip: ${RETH_TIP_HASH}"
  exec reth $BASE_ARGS --debug.tip "${RETH_TIP_HASH}"
else
  echo "No RETH_TIP_HASH provided; starting without --debug.tip"
  exec reth $BASE_ARGS
fi
```
Make it executable: `chmod +x start-reth.sh`

---

## 📦 `docker-compose.yml` (key services)

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
      - ./reth.toml:/data/reth.toml:ro
      - ./start-reth.sh:/usr/local/bin/start-reth.sh:ro
    networks:
      ethnet:
        ipv4_address: 10.200.0.10
    ports:
      - "8545:8545"
      - "8551:8551"
      - "9001:9001"   # Reth Prometheus metrics
    entrypoint: ["/usr/local/bin/start-reth.sh"]

  lighthouse:
    image: sigp/lighthouse:latest
    container_name: lighthouse
    restart: unless-stopped
    depends_on:
      reth-fork:
        condition: service_started
    entrypoint: ["lighthouse"]
    networks:
      ethnet:
        ipv4_address: 10.200.0.11
    volumes:
      - ./jwt.hex:/secrets/jwt.hex:ro
    ports:
      - "5052:5052"   # Beacon REST
      - "5054:5054"   # Lighthouse metrics
    command:
      - bn
      - --network
      - mainnet
      - --execution-endpoint
      - http://10.200.0.10:8551
      - --execution-jwt
      - /secrets/jwt.hex
      - --checkpoint-sync-url
      - https://mainnet.checkpoint.sigp.io
      - --http
      - --http-address
      - 0.0.0.0
      - --http-port
      - "5052"
      - --metrics
      - --metrics-address
      - 0.0.0.0
      - --metrics-port
      - "5054"

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    networks:
      ethnet:
        ipv4_address: 10.200.0.13
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    networks:
      ethnet:
        ipv4_address: 10.200.0.14
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro

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

---

## 🩺 Health Check

Script: `scripts/health-check.sh`  
Run it anytime to verify Lighthouse, Reth, and Anvil connectivity + lag.

```bash
bash scripts/health-check.sh   --reth http://127.0.0.1:8545   --lighthouse http://127.0.0.1:5052   --anvil http://127.0.0.1:8547   --lag 3
```

Outputs ✅ / ❌ per service and exits non-zero on failure.

---

## 📈 Monitoring (Prometheus + Grafana)

**Prometheus** scrapes:  
- Reth → `http://10.200.0.10:9001`  
- Lighthouse → `http://10.200.0.11:5054`

**Grafana** auto-provisions via files under `grafana/provisioning/`.

Access:
- Prometheus UI → http://localhost:9090  
- Grafana UI → http://localhost:3000 (admin / admin)

Dashboard: *OP Stack • Reth + Lighthouse* auto-imports at startup.

---

## 📦 Snapshots

Makefile targets:

```bash
make snapshot-reth     # Create a .tar.zst snapshot of reth_data (stops Reth briefly)
make snapshots          # List snapshots
make restore-reth FILE=backups/reth-2025xxxx-HHmmss.tar.zst  # Restore
```

---

## ⚙️ Typical Workflow

```bash
make bootstrap-import-url   # or make bootstrap-auto
make up-auto
make size                   # check disk usage
make prune-now              
bash scripts/health-check.sh
```

---

**✅ Done — you now have:**  
- Full EL+CL stack for mainnet (pruned)  
- Anvil dev fork environment  
- Metrics, dashboards, health checks, and snapshots  
- Pruning keeps disk ~350 GB, 1 month of history

**Happy hacking! ⚡**
