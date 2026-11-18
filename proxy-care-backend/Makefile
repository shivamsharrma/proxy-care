# Developer shortcuts. Every target is a thin wrapper over Gradle or Docker Compose;
# on Windows without make, run the commands shown in README.md directly.

GRADLE  := ./gradlew
COMPOSE := docker compose --env-file .env -f docker/compose.yaml

.DEFAULT_GOAL := help
.PHONY: help env build test format format-check lock run db-up db-down db-reset clean

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

env: ## Create .env from .env.example (never overwrites)
	@test -f .env && echo ".env already exists" || (cp .env.example .env && echo "Created .env")

build: ## Full build: compile, format check, tests, coverage report
	$(GRADLE) clean build

test: ## Run all tests (needs Docker)
	$(GRADLE) test

format: ## Apply formatting
	$(GRADLE) spotlessApply

format-check: ## Verify formatting
	$(GRADLE) spotlessCheck

lock: ## Re-resolve and record dependency versions in gradle.lockfile
	$(GRADLE) resolveAndLockAll --write-locks --no-configuration-cache

run: ## Start the app with the local profile (needs `make env db-up`)
	SPRING_PROFILES_ACTIVE=local $(GRADLE) bootRun

db-up: ## Start the local PostGIS database
	$(COMPOSE) up -d --wait

db-down: ## Stop the local database (keeps data)
	$(COMPOSE) down

db-reset: ## Stop the local database and delete its data
	$(COMPOSE) down -v

clean: ## Delete build output
	$(GRADLE) clean
