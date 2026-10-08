# Terraform — Azure Container Apps

Provisions the same three-tier app (Go app + MySQL + Redis) from
[`../docker-compose-app`](../docker-compose-app) onto
[Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview), instead of
Docker Compose or Kubernetes.

## Architecture

- **Container Apps Environment** — shared runtime hosting all three apps on one internal network.
- **`database`** — MySQL 8.0, internal ingress only (TCP, port 3306).
- **`cache`** — Redis 7, internal ingress only (TCP, port 6379).
- **`app`** — the Go service, pulled directly from the public image on Docker Hub
  (`nafiulhamim/dat515-app`), external HTTP ingress on port 8080, scales 1→3 replicas.
- **Log Analytics Workspace** — required by Container Apps for logs/metrics.

There's no nginx tier here — Container Apps provides ingress, TLS, and scaling natively, so the
reverse proxy used in the Compose/Kubernetes versions isn't needed.

MySQL and Redis run as plain containers on Container Apps rather than managed Azure services
(Azure Database for MySQL / Azure Cache for Redis). That keeps this close to the original
Compose/Kubernetes architecture and avoids the extra cost of managed database SKUs — reasonable
for a demo, not how you'd run a real production database (no managed backups/HA).

## Cost

Everything here fits comfortably inside the Azure for Students free credit, but it isn't free
to leave running indefinitely — the Log Analytics workspace and the running containers bill by
the day/GB even when the app sits idle. Run `terraform destroy` when you're done with a demo
session.

## Prerequisites

- `az login` (already done if you're using this repo's dev setup)
- The `Microsoft.App` resource provider registered on your subscription:
  `az provider register -n Microsoft.App`
- Terraform >= 1.9

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit if you want non-default values
terraform init
terraform plan
terraform apply
```

The app pulls straight from the public Docker Hub image (`nafiulhamim/dat515-app:latest`), so
there's no registry or push step — `terraform apply` is enough to get the app running.

Get the app's public URL:

```bash
terraform output app_url
```

Tear everything down:

```bash
terraform destroy
```
