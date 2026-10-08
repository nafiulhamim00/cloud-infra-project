# Terraform — Azure Container Apps

Provisions the same app from [`../docker-compose-app`](../docker-compose-app) onto Azure, using
managed Azure PaaS services instead of Docker Compose or Kubernetes for the database and cache.

## Architecture

- **`app`** — the Go service, pulled directly from the public image on Docker Hub
  (`nafiulhamim/demo-app`), running on an
  [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview) environment,
  external HTTP ingress on port 8080, scales 1→3 replicas.
- **Azure Database for MySQL Flexible Server** (Burstable B1ms) — the database tier.
- **Azure Cache for Redis** (Basic C0) — the cache tier.
- **Log Analytics Workspace** — required by Container Apps for logs/metrics.

There's no nginx tier here — Container Apps provides ingress, TLS, and scaling natively.

### Why managed MySQL/Redis instead of running them as containers

The first version of this ran MySQL and Redis as Container Apps too, matching the
Compose/Kubernetes architecture exactly. That doesn't work: newly-created Container Apps
environments on this subscription come up as the lightweight "Express" type, which only supports
HTTP ingress — MySQL and Redis need raw TCP ingress to be reachable from the `app` container, and
there's currently no way to request a non-Express environment through the `azurerm` Terraform
provider. Rather than fight that, the database and cache moved to actual managed Azure services,
which don't go through Container Apps ingress at all. This is also a more realistic cloud
architecture than self-hosting a database in a container.

The app connects to both over TLS (`DB_TLS_MODE=true`, `REDIS_TLS=true`) — Azure requires this on
both services. Locally (Docker Compose / Kubernetes), these env vars are simply left unset and the
app talks to the plain, unencrypted containers.

## Cost

Checked against the Azure Retail Prices API for this subscription's region (swedencentral):

| Resource | Rate |
|---|---|
| MySQL Flexible Server (B1ms) | $0.0199/hour |
| Azure Cache for Redis (Basic C0) | $0.022/hour |

A demo session (apply, test, `terraform destroy` within an hour or two) costs a few cents. Left
running continuously it's roughly $30/month combined — still easily covered by the Azure for
Students credit, but there's no reason to leave it running. The Log Analytics workspace bills
separately by GB ingested; a short demo generates well under its 5GB/month free allowance.

## Prerequisites

- `az login` (already done if you're using this repo's dev setup)
- The `Microsoft.App` resource provider registered on your subscription:
  `az provider register -n Microsoft.App`
- Terraform >= 1.9
- A MySQL client (e.g. `mysql` CLI, or Azure Data Studio) if you want to load the schema — see
  below

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `my_ip_address` to your public IP (`curl ifconfig.me`) so the MySQL
firewall lets you connect to load the schema.

```bash
terraform init
terraform plan
terraform apply
```

Load the schema (the app's `/messages` endpoint needs the `messages` table to exist):

```bash
terraform output mysql_fqdn
terraform output -raw db_password
mysql -h <mysql_fqdn> -u webuser -p --ssl-mode=REQUIRED webapp < ../docker-compose-app/stack/init.sql
```

Get the app's public URL:

```bash
terraform output app_url
```

Give it a minute for the first revision to start, then hit `/health`, `/counter`, or `/messages`
on that URL.

Tear everything down:

```bash
terraform destroy
```
