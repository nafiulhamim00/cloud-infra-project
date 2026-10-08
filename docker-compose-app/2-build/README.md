# Lab 9: Getting Started with Docker: Deploying a Basic Web App

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Learning Objectives](#learning-objectives)
- [Task 1 - Build It the Simple Way](#task-1--build-it-the-simple-way)
- [Task 2 - Production Image _graded_](#task-2--production-image-_graded_)
- [Task 3 - Scan, Tag, and Go Multi-Arch](#task-3--scan-tag-and-go-multi-arch)
- [Task 4 - Publish with GitHub Actions](#task-4--publish-with-github-actions)
- [Next Steps](#next-steps)

## Learning Objectives

- **Duration:** ~90 minutes
- **Prerequisites:** Completed Part 1. Working directory for this part: `../app/`.

By the end of this part, you will be able to:

- Build a container image from a Dockerfile and explain Docker's layer cache
- Write a production-grade multi-stage Dockerfile (non-root user, healthcheck, small final image)
- Scan an image for vulnerabilities and build/publish a multi-architecture image
- Automate publishing an image with GitHub Actions

All tasks in this part operate on the single Go service in [`../app/`](../app/). Read [`app/main.go`](../app/main.go) before you start: it is the same binary you will deploy as a multi-service stack in Part 3.

## Task 1 - Build It the Simple Way

1. **Build and run the simplest possible image**

   ```console
   cd ../app
   docker build -f Dockerfile.single -t dat515-app:single .
   docker run -d -p 8080:8080 --name app dat515-app:single
   curl localhost:8080/
   curl localhost:8080/counter
   curl localhost:8080/counter # increments even without Redis configured
   ```

2. **Note the image size**

   ```console
   docker images dat515-app
   ```

   Keep this number in mind — you will compare it against a multi-stage build in Task 2.

3. **Observe the layer cache**

   Edit the `Message` string built in `indexHandler` in `main.go`, then rebuild:

   ```console
   docker build -f Dockerfile.single -t dat515-app:single .
   ```

   Notice that `COPY go.mod go.sum ./` and `RUN go mod download` stay `CACHED` — only the layers from `COPY . .` onward rebuild, because only your source file (not your dependencies) changed.

   ```console
   docker rm -f app
   ```

## Task 2 - Production Image _graded_

Complete the `TODO`s in [`app/Dockerfile`](../app/Dockerfile):

- Start a second (`final`) stage `FROM alpine:3.20`
- `COPY --from=builder --chown=appuser:appgroup` the compiled binary from the `builder` stage
- Switch to the non-root `appuser` with `USER`
- Add OCI image labels (`org.opencontainers.image.version`, `org.opencontainers.image.source`) using the `APP_VERSION` build arg
- `EXPOSE` the port the app listens on
- Add a `HEALTHCHECK` that spiders `/health` with `wget`
- Run the binary

The cross-compilation lines (`GOOS=$TARGETOS GOARCH=$TARGETARCH`) are already provided — do not edit them; Part 2 Task 3 depends on them.

Verify:

```console
docker build -t dat515-app:1.0 --build-arg APP_VERSION=1.0 .
docker images # compare :1.0 against :single from Task 1
docker inspect --format '{{.Config.Labels}}' dat515-app:1.0
docker run -d -p 8080:8080 --name app dat515-app:1.0
docker exec app whoami # appuser, not root
docker inspect --format '{{.State.Health.Status}}' app # eventually "healthy"
docker rm -f app
```

## Task 3 - Scan, Tag, and Go Multi-Arch

1. **Install Docker Scout and scan for vulnerabilities**

   Docker Scout ships with Docker Desktop, but not with the `docker.io` package on Ubuntu — install the CLI plugin and log in first:

   ```console
   curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh -o install-scout.sh
   sh install-scout.sh
   docker login # scout needs an authenticated session

   docker scout quickview dat515-app:single
   docker scout quickview dat515-app:1.0
   ```

   The multi-stage `alpine` final image should report far fewer CVEs than the single-stage `golang:alpine` image, because it does not ship the Go toolchain.

2. **Tag with semver and push to a local registry**

   ```console
   docker run -d -p 5000:5000 --name registry registry:2
   docker tag dat515-app:1.0 localhost:5000/dat515-app:1.0
   docker push localhost:5000/dat515-app:1.0
   ```

3. **Try running the "wrong" architecture**

   ```console
   docker run --rm --platform linux/arm64 localhost:5000/dat515-app:1.0
   # exec format error, unless your host is already arm64
   ```

4. **Enable multi-arch builds and build for both platforms**

   Install the `buildx` plugin if `docker buildx version` fails, then register QEMU and create a builder. Use `--driver-opt network=host` so the builder container can reach your `localhost:5000` registry — without it, the push in the next step fails because the builder runs in its own network namespace:

   ```console
   sudo apt update && sudo apt install docker-buildx # skip if `docker buildx version` already works

   docker run --privileged --rm tonistiigi/binfmt --install all
   docker buildx create --use --name dat515-builder --driver docker-container --driver-opt network=host
   docker buildx inspect --bootstrap # starts the buildkit container

   docker buildx build --platform linux/amd64,linux/arm64 \
     --build-arg APP_VERSION=1.0 \
     -t localhost:5000/dat515-app:1.0 --push .
   docker buildx imagetools inspect localhost:5000/dat515-app:1.0
   ```

   The inspect output should list one manifest per platform.

5. **Run the foreign-architecture image and see it self-report correctly**

   ```console
   docker run --rm --platform linux/arm64 localhost:5000/dat515-app:1.0
   # {"message":"Hello from arm64", ...}
   ```

## Task 4 - Publish with GitHub Actions

1. **Create a Docker Hub access token**

   - Log in to [Docker Hub](https://hub.docker.com/), go to **Account Settings -> Security**
   - Click **New Access Token**, name it (e.g. `github-actions-token`), grant **Read, Write, Delete**
   - Click **Generate** and copy the token immediately — you cannot view it again

2. **Add it as two repository secrets**

   - On your assignment repository on GitHub: **Settings -> Secrets and variables -> Actions -> New repository secret**
   - Add `DOCKERHUB_USERNAME` (your Docker Hub username) and `DOCKERHUB_TOKEN` (the token from step 1)

3. **You are doing the `9docker` variant**, update `.github/workflows/docker-publish.yml` first — change both occurrences of `4docker` to `9docker`:
   - `paths: - '4docker/app/**'` → `paths: - '9docker/app/**'`
   - `context: ./4docker/app` → `context: ./9docker/app`
4. Push a change under `9docker/app/` to your assignment repository's `main` branch.
5. Check the Actions tab: the `docker-publish` workflow builds and pushes a multi-arch image to Docker Hub.
6. On your VM: `docker pull <your-dockerhub-username>/dat515-app:latest`.

## Next Steps

Proceed to [Part 3: Composing a Multi-Service Stack](../3-compose/README.md).
