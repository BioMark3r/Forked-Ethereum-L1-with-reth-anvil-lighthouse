SHELL := /bin/bash

up:
  docker compose up -d

down:
  docker compose down

recreate:
  docker compose up -d --force-recreate --remove-orphans

logs:
  docker compose logs -f

logs-reth:
  docker compose logs -f reth-fork

logs-lh:
  docker compose logs -f lighthouse

logs-anvil:
  docker compose logs -f anvil

ps:
  docker compose ps

