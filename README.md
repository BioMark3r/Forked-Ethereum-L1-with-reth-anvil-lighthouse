# Forked-Ethereum-L1-with-reth-anvil-lighthouse

# 🧱 Ethereum L1 Fork Dev Environment  
### Reth (Execution) • Lighthouse (Consensus) • Anvil (Dev RPC) • Caddy (TLS Proxy)

This setup lets you:

- Fork Ethereum L1 using **Reth** in debug/RPC-consensus mode  
- Connect **Lighthouse** to Reth using JWT auth (Engine API)  
- Use **Anvil** for testing with prefunded dev accounts (Anvil front-ends Reth)  
- Securely expose everything over **HTTPS** using **Caddy** with optional IP allow-lists and Basic Auth  

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

# Your domain (must have DNS pointing to your server)
DOMAIN_BASE=example.com
EMAIL_ACME=you@example.com

DOMAIN_LH=lh.${DOMAIN_BASE}
DOMAIN_ANVIL=anvil.${DOMAIN_BASE}
DOMAIN_RETH=reth.${DOMAIN_BASE}

# Optional: Basic Auth (see below to generate a hash)
BASIC_AUTH_USER=nick
BASIC_AUTH_HASHED_PASS=
# Optional: restrict access by IPs (CIDR list)
ALLOWLIST_CIDRS=
```

---

### 4️⃣ Generate a bcrypt password hash (optional, but recommended)

```bash
make auth PASS="YourStrongPassword"
```

Copy the printed hash and paste it into `BASIC_AUTH_HASHED_PASS` in your `.env`.

---

### 5️⃣ Add the Docker Compose & Makefile

Ensure you have the following files in your directory:

- `docker-compose.yml` (Reth, Lighthouse, Anvil, Caddy setup)  
- `Caddyfile` (TLS & proxy config)  
- `Makefile` (handy shortcuts)  
- `jwt.hex` (JWT secret)  
- `.env` (your environment variables)

*(Use the exact files from our setup conversation above.)*

---

### 6️⃣ DNS Setup

In your DNS provider, create **A** or **CNAME** records pointing to your server:

| Subdomain | Target | Purpose |
|------------|---------|----------|
| `reth.example.com` | your-server-ip | Reth JSON-RPC (HTTPS) |
| `anvil.example.com` | your-server-ip | Anvil dev RPC (HTTPS) |
| `lh.example.com` | your-server-ip | Lighthouse REST (HTTPS) |

> You must expose TCP **80** and **443** for Caddy to request Let’s Encrypt certificates.

---

### 7️⃣ Launch everything 🚀

```bash
make up
```

Docker will start all four services:

- **reth-fork** — Ethereum L1 fork using your upstream RPC  
- **lighthouse** — Beacon node connecting to Reth’s Engine API  
- **anvil** — Dev RPC layer for test accounts  
- **caddy** — Reverse proxy providing HTTPS and access control  

Wait about a minute for Caddy to fetch SSL certificates.

---

### 8️⃣ Verify endpoints

```bash
# Lighthouse REST API
curl -s https://lh.example.com/eth/v1/node/health

# Anvil RPC (with prefunded accounts)
curl -s -X POST https://anvil.example.com   -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_accounts","params":[]}'   -u nick:YourStrongPassword

# Reth RPC
curl -s -X POST https://reth.example.com   -H 'Content-Type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'   -u nick:YourStrongPassword
```

If Basic Auth is enabled, include the `-u username:password` flag.

---

### 9️⃣ Useful Make commands

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
| `make auth PASS="password"` | Generate Basic Auth bcrypt hash |
| `make clean` | Remove all containers & volumes |
| `make status` | Print container status & endpoint URLs |

---

### 🔐 Security Recommendations

- Restrict inbound access to ports **80/443** only — do **not** expose 8545/8547/5052 directly.  
- Use `ALLOWLIST_CIDRS` to limit which IPs can access your RPC endpoints.  
- Use Basic Auth for any public-facing instance.  
- Back up your `jwt.hex` — both Reth and Lighthouse must share the same secret.  
- For LAN-only testing, switch Caddy to use its internal CA:  
  Add `tls internal` inside each site block in the `Caddyfile`.

---

### 🧰 Troubleshooting

| Symptom | Likely cause | Fix |
|----------|---------------|-----|
| `Error: bn not found` | Missing entrypoint on Lighthouse | Fixed in current compose (uses `entrypoint: ["lighthouse"]`) |
| Caddy fails ACME challenge | Port 80 blocked or DNS wrong | Ensure ports 80/443 open and domain resolves |
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
| **Anvil (HTTPS)** | `https://anvil.example.com` | Local test RPC (prefunded accounts) |
| **Reth (HTTPS)** | `https://reth.example.com` | Forked Ethereum L1 execution layer |
| **Lighthouse (HTTPS)** | `https://lh.example.com` | Beacon node REST API |
| **Caddy (proxy)** | Handles SSL, auth, and network exposure |

---

Happy hacking 🧑‍💻⚡  
