# Forked-Ethereum-L1-with-reth-anvil-lighthouse

# 🧱 Ethereum L1 Fork Dev Environment  
### Reth (Execution) • Lighthouse (Consensus) • Anvil (Dev RPC)

This setup lets you:

- Fork Ethereum L1 using **Reth** in debug/RPC-consensus mode  
- Connect **Lighthouse** to Reth using JWT auth (Engine API)  
- Use **Anvil** for testing with prefunded dev accounts (Anvil front-ends Reth)

---

## 🪜 Step-by-Step Setup Guide

### 1️⃣ Clone or create your working folder

```bash
mkdir eth-fork && cd eth-fork
```

---

### 2️⃣ Generate a JWT secret

```bash
openssl rand -hex 32 > jwt.hex
```

This secret is shared between Reth and Lighthouse for Engine API authentication.

---

### 3️⃣ Create an `.env` file

```bash
# .env
MAINNET_RPC_WSS=wss://eth-mainnet.g.alchemy.com/v2/<YOUR_KEY>
LIGHTHOUSE_NETWORK=mainnet
```

---

### 4️⃣ Generate a bcrypt password hash (optional, but recommended)

If you’re using authentication layers in the future (not needed in this minimal version):

```bash
make auth PASS="YourStrongPassword"
```

---

### 5️⃣ Add the Docker Compose & Makefile

Ensure you have the following files in your directory:

- `docker-compose.yml` (Reth, Lighthouse, and Anvil setup)  
- `Makefile` (handy shortcuts)  
- `jwt.hex` (JWT secret)  
- `.env` (your environment variables)

*(Use the files from the previous setup.)*

---

### 6️⃣ Launch everything 🚀

```bash
make up
```

Docker will start all three services:

- **reth-fork** — Ethereum L1 fork using your upstream RPC  
- **lighthouse** — Beacon node connecting to Reth’s Engine API  
- **anvil** — Dev RPC layer for test accounts  

---

### 7️⃣ Verify endpoints

```bash
# Lighthouse REST API
curl -s http://localhost:5052/eth/v1/node/health

# Anvil RPC (with prefunded accounts)
curl -s -X POST http://localhost:8547   -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_accounts","params":[]}'

# Reth RPC
curl -s -X POST http://localhost:8545   -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

---

### 8️⃣ Useful Make commands

| Command | Description |
|----------|-------------|
| `make up` | Start all services |
| `make down` | Stop everything |
| `make restart` | Restart stack |
| `make logs` | Stream all logs |
| `make logs-reth` | Logs from Reth |
| `make logs-anvil` | Logs from Anvil |
| `make logs-lh` | Logs from Lighthouse |
| `make jwt` | Regenerate JWT secret |
| `make clean` | Remove all containers & volumes |
| `make status` | Print container status |

---

### 🔐 Security Recommendations

- Restrict inbound access to the ports you expose (8545, 8547, 5052).  
- Keep `jwt.hex` private; both Reth and Lighthouse must share the same secret.  
- Use firewall or Docker network settings to limit exposure.

---

### 🧰 Troubleshooting

| Symptom | Likely cause | Fix |
|----------|---------------|-----|
| `Error: bn not found` | Missing entrypoint on Lighthouse | Fixed in current compose (uses `entrypoint: ["lighthouse"]`) |
| Lighthouse says “unauthorized EL” | JWT mismatch | Delete and re-generate `jwt.hex` for both |
| Anvil RPC fails | Reth not healthy yet | Wait a bit or check `make logs-reth` |

---

### 🧹 Quick Reset / Full Rebuild

If you want to start clean (new volumes, fresh state, new JWT):

```bash
make down        # stop services
make clean       # remove volumes and networks
make jwt         # generate new jwt.hex
make up          # relaunch
```

> This wipes your Reth data directory and resets the fork to the latest state from your upstream RPC.

---

### ✅ Summary

After setup, you’ll have:

| Service | URL | Role |
|----------|------|------|
| **Anvil** | `http://localhost:8547` | Local test RPC (prefunded accounts) |
| **Reth** | `http://localhost:8545` | Forked Ethereum L1 execution layer |
| **Lighthouse** | `http://localhost:5052` | Beacon node REST API |

---

Happy hacking 🧑‍💻⚡  
