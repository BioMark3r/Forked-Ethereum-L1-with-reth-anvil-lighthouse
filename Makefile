SHELL := /bin/bash

# Load .env if present (for Docker Compose variables)
-include .env

# === Default confirmations offset if not specified ===
CONFIRMATIONS ?= 5

# === Start all services (standard fork) ===
up:
	@echo "🚀 Starting full stack..."
	docker compose up -d

# === Bring up Anvil pinned at a specific block number ===
# Usage: make up-pin BLOCK=19304240
# If no BLOCK is passed, falls back to latest minus CONFIRMATIONS using reth itself.
up-pin:
ifeq ($(BLOCK),)
	@echo "❌ No BLOCK number provided. Usage: make up-pin BLOCK=<number>"
	@exit 1
else
	@echo "📌 Using user-provided block number $(BLOCK)"
	FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil
endif

# === Restart Anvil with a pinned block (preserves other containers) ===
restart-pin:
ifeq ($(BLOCK),)
	@echo "❌ No BLOCK number provided. Usage: make restart-pin BLOCK=<number>"
	@exit 1
else
	@echo "🔁 Restarting Anvil pinned at block $(BLOCK)"
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

logs-caddy:
	docker compose logs -f caddy

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
