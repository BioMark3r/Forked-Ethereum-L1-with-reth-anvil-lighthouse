SHELL := /bin/bash

# Load .env if present (for Docker Compose variables)
-include .env

# === Default confirmations offset if not specified ===
CONFIRMATIONS ?= 5

# === Start all services (standard fork) ===
up:
	@echo "🚀 Starting Reth + Lighthouse + Anvil (latest head)…"
	docker compose up -d reth-fork lighthouse
	# wait for reth JSON-RPC to be reachable
	for i in {1..60}; do \
	  curl -sf http://127.0.0.1:8545 >/dev/null && break || sleep 1; \
	done
	docker compose up -d anvil

# Pin to a specific block: make up-pin BLOCK=19304240
up-pin:
ifeq ($(BLOCK),)
	@echo "❌ No BLOCK provided. Usage: make up-pin BLOCK=<number>"; exit 1
else
	@echo "📌 Starting Reth + Lighthouse, then Anvil pinned to $(BLOCK)…"
	docker compose up -d reth-fork lighthouse
	for i in {1..60}; do \
	  curl -sf http://127.0.0.1:8545 >/dev/null && break || sleep 1; \
	done
	FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil
endif

restart-pin:
ifeq ($(BLOCK),)
	@echo "❌ No BLOCK provided. Usage: make restart-pin BLOCK=<number>"; exit 1
else
	@echo "🔁 Restarting Anvil pinned to $(BLOCK)…"
	FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d --force-recreate anvil
endif

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
