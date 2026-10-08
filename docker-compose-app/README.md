# Lab 9: Getting Started with Docker: Deploying a Basic Web App

| Lab 9:           | Getting Started with Docker: Deploying a Basic Web App |
| ---------------- | ------------------------------------------------------ |
| Subject:         | DAT515 Cloud Computing                                 |
| Deadline:        | **September 13, 2026 23:59**                           |
| Expected effort: | 4-6 hours                                              |
| Score limit:     | 85                                                     |
| Grading:         | Pass/fail                                              |
| Submission:      | Individually                                           |

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Prerequisites](#prerequisites)
- [Lab Structure](#lab-structure)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Getting Help](#getting-help)
- [Resources](#resources)
- [Next Steps](#next-steps)

This lab series introduces you to Docker containerization technology through hands-on exercises.
The labs are designed to be completed in sequence, building upon concepts from previous labs.

Two foundations are used throughout: a single Go HTTP service in [`app/`](app/), and a multi-service stack in [`stack/`](stack/) that runs that same service alongside MySQL, Redis, and nginx. You edit these files in place — there are no per-task directories to copy files into.

[!IMPORTANT]
**Lab Track Choice:**
You only need to complete **either** Lab 9 (`9docker`) **or** Lab 4 (`4docker`).

- **Lab 9 (3-part track):** Integrated, code-first track working directly on a Go microservice (`app/`) and multi-container stack (`stack/`).
- **Lab 4 (5-part track):** Step-by-step modular tutorial covering fundamentals, Dockerfile, Compose, and multi-arch builds across separate task directories.

Choose the track you prefer; both satisfy the Docker lab requirement.

## Prerequisites

- Access to UiS campus network (required for certain parts)
- Basic understanding of Linux command line

## Lab Structure

### [Part 1: Setup and Container Basics](1-setup/README.md) (~90 minutes)

- Virtual Machine setup on UiS Cloud (OpenStack), or Docker Desktop locally
- Docker installation and the OpenStack MTU fix
- Container lifecycle, port mapping, and inspection
- Configuration, named volumes, and debugging a container that fails to start

### [Part 2: Building and Shipping Images](2-build/README.md) (~90 minutes)

All tasks build on [`app/`](app/), a single Go service:

- A simple single-stage build, and how Docker's layer cache works
- A production multi-stage Dockerfile: non-root user, healthcheck, OCI labels _graded_
- Vulnerability scanning, registries, and multi-architecture builds with `buildx`
- Publishing images automatically with GitHub Actions

### [Part 3: Composing a Multi-Service Stack](3-compose/README.md) (~90 minutes)

All tasks build on [`stack/`](stack/), which wires the `app/` service up to MySQL, Redis, and nginx:

- The base stack: healthchecks gate startup order _graded_
- Development overrides: exposed ports, Adminer, Redis Commander _graded_
- Production overrides: replicas, resource limits, file-based secrets _graded_

## Quick Reference

```console
# Images
docker build -t NAME:TAG .
docker images
docker scout quickview NAME:TAG

# Containers
docker run -d -p HOST:CONTAINER --name NAME IMAGE
docker ps / docker ps -a
docker logs [-f] CONTAINER
docker exec -it CONTAINER sh
docker stop/start/rm CONTAINER

# Compose
docker compose up -d --build
docker compose -f compose.yaml -f compose.dev.yaml up -d
docker compose ps / docker compose logs
docker compose down [-v]

# Cleanup
docker container prune / docker image prune / docker system df
```

## Troubleshooting

- **`exec format error`** when running a container: you built for the wrong CPU architecture. Use `docker buildx build --platform` for the target platform, or run with `--platform` matching the image.
- **Compose service stuck "starting"**: check `docker compose logs <service>` and the service's `healthcheck` — a dependent service will not start until its `depends_on` condition (`service_healthy`) is met.
- **Docker permission denied**: your user is not in the `docker` group yet, or you have not logged out/in since being added — run `groups` to check.
- **SSH connection failed**: confirm you are on the UiS campus network or using the jump host, and that your floating IP and security group rules are correct.

## Getting Help

- **Lab Sessions:** Attend scheduled lab sessions for hands-on support
- **Discord:** Ask questions in the `#lab4` channel for asynchronous assistance
- **Peer Learning:** Work with your group members

## Resources

- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Container Security Guide](https://docs.docker.com/engine/security/)

## Next Steps

Start with [Part 1: Setup and Container Basics](1-setup/README.md) to begin your Docker journey!
