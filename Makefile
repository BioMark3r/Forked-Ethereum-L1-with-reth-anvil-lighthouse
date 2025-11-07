SHELL := /bin/bash

up:
\tdocker compose up -d

down:
\tdocker compose down

recreate:
\tdocker compose up -d --force-recreate --remove-orphans

logs:
\tdocker compose logs -f

logs-reth:
\tdocker compose logs -f reth-fork

logs-lh:
\tdocker compose logs -f lighthouse

logs-anvil:
\tdocker compose logs -f anvil

ps:
\tdocker compose ps

