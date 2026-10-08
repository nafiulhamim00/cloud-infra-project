# syntax=docker/dockerfile:1
FROM golang:1.26-alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ARG APP_VERSION=dev

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Cross-compile natively for the requested target platform (provided; do not edit).
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 \
    go build -ldflags "-X main.version=$APP_VERSION" -o /out/dat515-app .

#push for github action
FROM alpine:3.20 AS final

RUN apk add --no-cache ca-certificates wget && \
    addgroup -g 1001 appgroup && adduser -D -u 1001 -G appgroup appuser

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /out/dat515-app /app/dat515-app

USER appuser


ARG APP_VERSION=dev

LABEL org.opencontainers.image.version="$APP_VERSION" \
      org.opencontainers.image.source="https://github.com/nafiulhamim00/cloud-infra-project"


ENV PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["/app/dat515-app"]
