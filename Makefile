SHELL := /bin/bash

# Load .env if present (for Docker Compose variables)
-include .env

# Bootstrapping

# Stop just the EL so /data is free for writes
stop-reth:
	@docker compose stop reth-fork >/dev/null 2>&1 || true

# Show whether /data looks initialized
data-status:
	@docker compose run --rm --no-deps --entrypoint sh reth-fork -lc \
		'ls -la /data; echo; [ -d /data/db ] && echo "DB present ✅" || echo "DB missing ❌"'

# Smart bootstrap:
# 1) If `reth download` exists in your image → use it (recommended)
# 2) Else, if RETH_ERA_URL is set → import ERA from that URL
# 3) Else → fail with a helpful message
bootstrap-auto: stop-reth
	@echo "🔎 Checking if 'reth download' is available…"
	if docker compose run --rm --no-deps --entrypoint reth reth-fork download --help >/dev/null 2>&1; then \
		echo "✅ Using 'reth download' (this may take a while)"; \
		docker compose run --rm --no-deps --entrypoint reth reth-fork \
			download --chain mainnet --datadir /data; \
	elif [ -n "$$RETH_ERA_URL" ]; then \
		echo "⚠️  'download' not found — importing ERA from $$RETH_ERA_URL"; \
		docker compose run --rm --no-deps --entrypoint reth reth-fork \
			import-era --url "$$RETH_ERA_URL" --datadir /data; \
	else \
		echo "❌ No bootstrap method available."; \
		echo "   - Use a reth image that has 'reth download' OR"; \
		echo "   - Set RETH_ERA_URL in .env to a hosted ERA snapshot"; \
		exit 3; \
	fi
	@$(MAKE) data-status

# Optional: import ERA from a local path (run with: make bootstrap-import-path ERA_DIR=/abs/path/to/era)
bootstrap-import-path: stop-reth
	@[ -n "$$ERA_DIR" ] || { echo "Usage: make bootstrap-import-path ERA_DIR=/abs/path/to/era"; exit 2; }
	@echo "⏬ Importing ERA from local path: $$ERA_DIR"
	@docker compose run --rm --no-deps \
		-v "$$ERA_DIR":/era:ro \
		--entrypoint reth reth-fork \
		import-era --path /era --datadir /data
	@$(MAKE) data-status


# === Default confirmations offset if not specified ===
CONFIRMATIONS ?= 5

discover-el:
	@EL_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' reth-fork 2>/dev/null || true); \
	if [ -z "$$EL_IP" ]; then echo "Starting reth…" ; docker compose up -d reth-fork ; \
	sleep 2 ; EL_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' reth-fork); fi; \
	echo "$$EL_IP"

# Helper: get latest execution tip hash from your MAINNET_RPC_HTTPS

tip-hash:
	@bin/tip-hash.sh

up-auto:
	@TIP=$$(bin/tip-hash.sh); \
	echo "tip: $$TIP"; \
	if [ "$$TIP" != "null" ]; then \
	  echo "📌 Using Reth tip $$TIP"; \
	  RETH_TIP_HASH=$$TIP docker compose up -d --force-recreate reth-fork; \
	else \
	  echo "⚠️  No tip available; Reth will sync from genesis (slow)."; \
	  RETH_TIP_HASH= docker compose up -d --force-recreate reth-fork; \
	fi; \
	docker compose up -d lighthouse; \
	docker compose up -d anvil

# Handy: show the exact argv the reth container is running with
reth-argv:
	@docker exec reth-fork sh -lc 'tr "\0" " " < /proc/1/cmdline' | sed 's/ \+/\n  /g' | sed '1s/^/reth argv:\n  /'

up-pin:
	@if [ -z "$(BLOCK)" ]; then echo "Usage: make up-pin BLOCK=<number>"; exit 1; fi
	@docker compose up -d reth-fork lighthouse
	@FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil

size:
	@docker compose run --rm --no-deps --entrypoint sh reth-fork -lc 'du -sh /data || true'

# Forces a prune pass immediately (use sparingly; pruning already runs on interval)
prune-now:
	@docker compose run --rm --no-deps --entrypoint reth reth-fork \
		prune --datadir /data

restart-pin:
	@if [ -z "$(BLOCK)" ]; then echo "Usage: make restart-pin BLOCK=<number>"; exit 1; fi
	@FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d --force-recreate anvil

down:
	@echo "🧹 Stopping and removing all containers..."
	docker compose down

restart:
	@echo "🔁 Restarting stack..."
	docker compose down
	docker compose up -d

recreate:
	@echo "♻️  Forcing full recreation of all services..."
	docker compose up -d --force-recreate --remove-orphans

ps:
	docker compose ps

logs:
	docker compose logs -f

logs-reth:
	docker compose logs -f reth-fork

logs-lh:
	docker compose logs -f lighthouse

logs-anvil:
	docker compose logs -f anvil

# === System & Utility Commands ===

clean:
	@echo "🧽 Removing containers, networks, and volumes..."
	docker compose down -v --remove-orphans

prune:
	@echo "🔥 Full Docker cleanup (dangling images, networks, volumes)..."
	docker system prune -af --volumes

# === Auth Helper ===
# Example: make auth PASS=myStrongPassword
auth:
	@echo "🔐 Generating bcrypt hash for BASIC_AUTH_HASHED_PASS..."
	@docker run --rm caddy:2-alpine caddy hash-password --plaintext '$(PASS)'

# === JWT Helper ===
jwt:
	@echo "🪪 Generating new jwt.hex secret..."
	@openssl rand -hex 32 > jwt.hex && echo "✅ Created jwt.hex"

# === Diagnostics ===
status:
	@echo "🌐 Checking container health..."
	docker compose ps
	@echo ""
	@echo "🔎 Lighthouse REST  : https://$$(grep DOMAIN_LH .env | cut -d= -f2)"
	@echo "🔎 Anvil RPC        : https://$$(grep DOMAIN_ANVIL .env | cut -d= -f2)"
	@echo "🔎 Reth RPC         : https://$$(grep DOMAIN_RETH .env | cut -d= -f2)"

check-fork:
	@echo "Reth latest:"
	@curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
	@curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
	  --data '{"jsonrpc":"2.0","id":2,"method":"eth_getBlockByNumber","params":["latest", false]}' | jq -r '.result.hash'
	@echo "Anvil latest:"
	@curl -s -X POST http://127.0.0.1:8547 -H 'Content-Type: application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
	@curl -s -X POST http://127.0.0.1:8547 -H 'Content-Type: application/json' \
	  --data '{"jsonrpc":"2.0","id":2,"method":"eth_getBlockByNumber","params":["latest", false]}' | jq -r '.result.hash'

