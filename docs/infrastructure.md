# Chatter — Infrastructure & Cost Estimate

Deploy tool: **Kamal 2** (already in the repo — `Gemfile`, `config/deploy.yml`, `.kamal/`). Hosting: **Hetzner Cloud** VMs (DigitalOcean is a drop-in equivalent — see the alternative at the end). The app is the Rails 8 monolith from [`PRD.md`](PRD.md): one Docker image (the stock `rails new` `Dockerfile`), one Postgres database, **no Redis** — Solid Queue/Cache/Cable are Postgres-backed. Kamal builds the image, pushes it to a registry, and does a health-checked rolling restart of the container on each server over SSH. No Kubernetes, no Terraform, no managed container platform.

This is a written plan — nothing here is deployed (per the brief).

**Why it's sized this small.** The [PRD](PRD.md)'s scope (§3) — no login or user accounts, one shared map, no pagination, no moderation or search, trusted input, demo-scale traffic — means the app does one indexed query per page load and one INSERT plus one broadcast per message, with no Redis and no per-user state. There's no workload here that a single small VM per environment can't absorb, so the estimates start there. The first bottleneck would be the single web host; scaling past it means adding servers under `servers.web` and moving TLS termination to a load balancer (Solid Cable already works across multiple web hosts, so real-time needs no change).

## Assumptions

- **Two environments**, both driven by Kamal *destinations*: `kamal deploy -d staging` / `-d production` read `config/deploy.staging.yml` / `config/deploy.production.yml` merged over the shared `config/deploy.yml`. Each destination has its own server(s), its own `RAILS_MASTER_KEY` (per-environment Rails credentials), and its own database.
  - **staging** — one small VM running web + Postgres side by side; internal traffic only.
  - **production** — a web VM and a separate Postgres VM; light-to-moderate public traffic.
- Region: Hetzner `nbg1` (Nuremberg).
- A domain is already owned; DNS is hosted on Cloudflare (free tier) with `A` records pointing at each environment's IP.
- Container image is stored in **GitHub Container Registry** (`ghcr.io`) — free for this image size, scoped to the repo.
- TLS is terminated by `kamal-proxy` on the web server using Let's Encrypt (free, auto-renewed).

## Architecture at a glance

| App component | How it runs |
|---|---|
| Rails container (Puma + Thruster, Solid Queue in-process via `SOLID_QUEUE_IN_PUMA`) | Docker container managed by Kamal on the web VM |
| HTTPS termination + zero-downtime cutover | `kamal-proxy` on the web VM (Let's Encrypt) |
| PostgreSQL (app data + Solid Cable/Queue/Cache tables) | Kamal **accessory** container (`accessories.db` in `config/deploy.yml`), data on a mounted volume |
| Real-time (Action Cable) | Solid Cable over the same Postgres — no separate service, no sticky sessions needed at one web host |
| Container image | `ghcr.io/<org>/chatter:<git-sha>` |
| Secrets (`RAILS_MASTER_KEY`, registry token, Postgres password) | `.kamal/secrets`, pulled from ENV / a password manager at deploy time — never in git |
| Logs | `kamal app logs` (Docker `json-file` driver); ship to a hosted log service later if needed |
| Backups | nightly `pg_dump` to Hetzner Storage Box + Hetzner automated server snapshots |
| Health check | `GET /up` (Rails default route), used by `kamal-proxy` for readiness |

## Cost estimate — Staging

| Component | Choice | Why | Est. monthly cost |
|---|---|---|---|
| Compute | 1× Hetzner **CX22** (2 vCPU, 4 GB, 40 GB disk) — web container + Postgres accessory co-located | One box is plenty for internal traffic; co-locating the DB avoids a second VM | ~$6 |
| DB storage | On the CX22's included disk | Staging data is small and disposable | $0 |
| Backups | Hetzner automated snapshots (20% of server price) | Enough for a non-customer-facing environment | ~$1 |
| Registry | GitHub Container Registry | Same image staging and production deploy | $0 |
| DNS | Cloudflare free tier, `staging.` record | — | $0 |
| TLS | Let's Encrypt via `kamal-proxy` | — | $0 |
| **Total** | | | **~$7/month** |

## Cost estimate — Production

| Component | Choice | Why | Est. monthly cost |
|---|---|---|---|
| Web/app | 1× Hetzner **CX32** (4 vCPU, 8 GB) running the Rails container + `kamal-proxy` | Headroom for Puma threads + Solid Queue in-process; single host keeps Cable simple | ~$9 |
| Database | 1× Hetzner **CX22** (2 vCPU, 4 GB) running the Postgres accessory, on the private network only | Isolates the stateful piece from app restarts and lets it be sized/backed up independently | ~$6 |
| DB volume | 25 GB Hetzner Volume attached to the DB VM | Postgres data on a volume that outlives the VM and can be snapshotted | ~$2 |
| Backups | Hetzner snapshots for both VMs (~20% of price) + Storage Box **BX11** (1 TB) for off-site nightly `pg_dump` | Two independent recovery paths (snapshot restore, logical dump) | ~$3 + ~$4 |
| Floating IP | 1× Hetzner Floating IP pointed at the web VM | Stable address for DNS; survives replacing the web VM | ~$2 |
| Registry | GitHub Container Registry | — | $0 |
| DNS | Cloudflare free tier (apex + `www`) | — | $0 |
| TLS | Let's Encrypt via `kamal-proxy` | — | $0 |
| **Total** | | | **~$26/month** |

## Deployment flow

**Provisioning (one-time per environment):**

1. Create the VM(s) and, for production, the volume, private network, and Floating IP.
2. Point the DNS `A` record at the web VM's (floating) IP.
3. Fill in the destination config: `config/deploy.<env>.yml` (server IPs, `proxy.host`), `.kamal/secrets` (`KAMAL_REGISTRY_PASSWORD`, `RAILS_MASTER_KEY`, `POSTGRES_PASSWORD`).
4. `kamal setup -d <env>` — installs Docker on the hosts, boots `kamal-proxy`, starts the Postgres accessory, and runs the first deploy.

**Release (every change):**

1. CI ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) runs rubocop + RSpec + security scans on every PR.
2. After merge, a **separate, manually-triggered** GitHub Actions job (or a maintainer's laptop) runs `kamal deploy -d staging`, then `-d production` once staging looks good. Kamal builds the image, pushes `ghcr.io/<org>/chatter:<sha>`, and does a rolling restart gated on `GET /up`.
3. `bin/rails db:prepare` runs automatically on container boot (the Dockerfile's `docker-entrypoint`), so migrations ship with the image. `kamal rollback` reverts to the previous image if a deploy goes bad.

Infra changes (VM sizes, adding a host) are done by hand on the provider console and never block an app release.

## Backups & disaster recovery

- **Postgres:** nightly `pg_dump` (cron on the DB host or a Kamal cron accessory) to the Storage Box, 14-day retention; plus Hetzner VM snapshots. RPO ≈ 24 h with dumps — tighten with WAL archiving or a managed DB if the data ever justifies it.
- **Recovery:** re-provision the VM from IaC/snapshot, `kamal setup -d production`, restore the latest dump. RTO ≈ 30–60 min, mostly manual.
- **Image:** every release is an immutable `ghcr.io` tag, so any past version can be re-deployed directly.

## Alternative: DigitalOcean with managed Postgres

Swap Hetzner VMs for DigitalOcean Droplets and the Postgres accessory for **DO Managed Databases** (automated backups, PITR, failover standby). Kamal config barely changes — point `DB_HOST` at the managed cluster and drop `accessories.db`.

| | Staging | Production |
|---|---|---|
| Droplet | $6 (1 GB) | $24 (2 vCPU / 4 GB) |
| Managed Postgres | $15 (single node, 1 GB) | ~$30 (1 vCPU / 2 GB) + standby optional |
| Spaces (backups/off-site) | — | $5 |
| **Total** | **~$21/month** | **~$60/month** |

Roughly 2–3× the Hetzner cost, bought back as zero database operations. Reasonable if the app grows past demo scale; over-provisioned for the brief.
