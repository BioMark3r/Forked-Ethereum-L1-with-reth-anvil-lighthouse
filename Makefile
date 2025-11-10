SHELL := /bin/bash

# Load .env if present (for Docker Compose variables)
-include .env

# === Default confirmations offset if not specified ===
CONFIRMATIONS ?= 5

SHELL := /bin/bash
-include .env
.ONESHELL:

discover-el:
	@EL_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' reth-fork 2>/dev/null || true); \
	if [ -z "$$EL_IP" ]; then echo "Starting reth…" ; docker compose up -d reth-fork ; \
	sleep 2 ; EL_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' reth-fork); fi; \
	echo "$$EL_IP"

up-auto:
	@EL_IP=$$(make -s discover-el); \
	echo "EL at $$EL_IP"; \
	RETH_ENGINE_URL="http://$$EL_IP:8551" \
	RETH_RPC_URL="http://$$EL_IP:8545" \
	docker compose up -d lighthouse; \
	RETH_ENGINE_URL="http://$$EL_IP:8551" \
	RETH_RPC_URL="http://$$EL_IP:8545" \
	docker compose up -d anvil; \
	echo "Lighthouse and Anvil pointed at $$EL_IP"

# Helper: get latest execution tip hash from your MAINNET_RPC_HTTPS
# Requires: jq installed locally
tip-hash:
	@if [ -z "$(MAINNET_RPC_HTTPS)" ]; then \
	  echo "MAINNET_RPC_HTTPS not set; cannot auto-compute tip" >&2; exit 2; \
	fi
	@curl -s -X POST "$(MAINNET_RPC_HTTPS)" \
	  -H 'Content-Type: application/json' \
	  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest", false]}' \
	  | jq -r .result.hash

# Start everything, auto tip if no BLOCK is provided (Anvil follows latest unless pinned)
up-auto:
	@echo "🚀 Starting Reth (auto-tip if available) + Lighthouse + Anvil…"
	@if [ -n "$(MAINNET_RPC_HTTPS)" ]; then \
	  T=$$(make -s tip-hash); \
	else \
	  T=""; \
	fi; \
	if [ -n "$$T" ] && [ "$$T" != "null" ]; then \
	  echo "📌 Using Reth tip $$T"; \
	  RETH_TIP_HASH=$$T docker compose up -d reth-fork; \
	else \
	  echo "ℹ️ No tip available (or MAINNET_RPC_HTTPS unset); starting Reth without --debug.tip"; \
	  docker compose up -d reth-fork; \
	fi; \
	docker compose up -d lighthouse; \
	if [ -n "$(BLOCK)" ]; then \
	  echo "📎 Pinning Anvil at block $(BLOCK)"; \
	  FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil; \
	else \
	  docker compose up -d anvil; \
	fi


up-pin:
	@if [ -z "$(BLOCK)" ]; then echo "Usage: make up-pin BLOCK=<number>"; exit 1; fi
	@docker compose up -d reth-fork lighthouse
	@FORK_BLOCK_NUMBER=$(BLOCK) docker compose up -d anvil

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
