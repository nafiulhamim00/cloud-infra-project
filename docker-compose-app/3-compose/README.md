# Lab 9: Getting Started with Docker: Deploying a Basic Web App

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Learning Objectives](#learning-objectives)
- [Prerequisites Setup](#prerequisites-setup)
- [Task 1 - The Stack _graded_](#task-1--the-stack-_graded_)
- [Task 2 - Dev Overrides and Debug Tools _graded_](#task-2--dev-overrides-and-debug-tools-_graded_)
- [Task 3 - Production Overrides _graded_](#task-3--production-overrides-_graded_)
- [Next Steps](#next-steps)

## Learning Objectives

- **Duration:** ~90 minutes
- **Prerequisites:** Completed Part 2. Working directory for this part: `../stack/`.

By the end of this part, you will be able to:

- Compose a multi-service stack (app, database, cache, reverse proxy) with health-gated startup
- Add development overrides that expose ports and debugging tools
- Add production overrides: replicas, resource limits, and file-based secrets

All tasks operate on [`../stack/`](../stack/), which builds the `app` service from [`../app/`](../app/) — there is exactly one Dockerfile in this lab, and you already completed it in Part 2.

## Prerequisites Setup

1. **Install Docker Compose on Ubuntu**

   ```console
   # For Ubuntu 24.04 (Compose V2)
   sudo apt update
   sudo apt install docker-compose-v2

   # Verify installation
   docker compose version

## Task 1 - The Stack _graded_

Complete the `TODO`s in [`stack/compose.yaml`](../stack/compose.yaml):

- `database` and `cache` healthchecks (`mysqladmin ping -h localhost`, `redis-cli ping`) with sensible `interval`/`timeout`/`retries`/`start_period`
- `nginx` should `depends_on` the `app` service

Then:

```console
cd ../stack
docker compose up -d --build
curl localhost:8080/ # through nginx
curl localhost:8080/counter
curl -X POST localhost:8080/messages -d '{"content":"hello"}'
curl localhost:8080/messages
docker compose down
docker compose up -d # data persists: /messages still has your entry
docker compose down -v # -v also removes the named volumes
```

## Task 2 - Dev Overrides and Debug Tools _graded_

Complete the `TODO`s in [`stack/compose.dev.yaml`](../stack/compose.dev.yaml):

- Expose `database` on host port `3306` and `cache` on host port `6379`
- Map `adminer`'s port `8080` to host port `8081`
- Map `redis-commander`'s port `8081` to host port `8082`

Then:

```console
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
curl localhost:8088/ # direct access to the app, bypassing nginx
```

Open `http://<host>:8081` (Adminer, server `database`, user `webuser`) and `http://<host>:8082` (Redis Commander) in a browser.

```console
docker compose -f compose.yaml -f compose.dev.yaml down
```

## Task 3 - Production Overrides _graded_

Complete the `TODO`s in [`stack/compose.prod.yaml`](../stack/compose.prod.yaml):

- `app.deploy.replicas`: run at least 2 instances
- `app.deploy.resources.limits.memory`: a memory limit
- `database`: use `MYSQL_PASSWORD_FILE` (matching the Docker secrets convention already used for `MYSQL_ROOT_PASSWORD_FILE`) instead of a plaintext password
- `nginx`: publish port `80:80`

Then:

```console
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --build
docker compose ps # two "app" replicas
for i in 1 2 3 4; do curl -s localhost:80/ | grep hostname; done # hostname alternates
docker compose exec app cat /run/secrets/db_password # the app authenticates using this file
```

## Next Steps

You have built the same application twice: once as a single container (Part 2) and once as a health-gated, horizontally-scaled, secret-managed stack (Part 3). [Part 7 of the Kubernetes lab](../../5kube/7-docker-to-kube/README.md) asks you to convert this stack into Kubernetes manifests.
