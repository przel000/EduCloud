# EduCloud

Private-cloud lab built with Docker Compose. Demonstrates containerized file storage (Nextcloud), reverse-proxy load balancing (Nginx), MariaDB persistence, MinIO object storage, Prometheus/cAdvisor monitoring, SQL backup/restore, and scripted container recovery.

Designed as a **credible portfolio project** for cloud/infrastructure interviews — not a production cloud platform.

## Architecture

```text
User → Nginx (:8080) → Nextcloud ×2 → MariaDB
                      ↘ Redis (locks/cache)
MinIO (S3 API) · Prometheus · cAdvisor · PowerShell recovery
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Prerequisites

- Docker Desktop (Windows) or Docker Engine + Compose v2
- PowerShell 5+ (for backup/recovery scripts)
- Copy `.env.example` → `.env` and set passwords

## Quick Start

```powershell
cd EduCloud
Copy-Item .env.example .env
# Edit .env with your own credentials

docker compose up -d
docker compose ps
```

Open:

| Service | URL |
|---------|-----|
| Nextcloud (via Nginx) | http://localhost:8080 |
| MinIO Console | http://localhost:9001 |
| Prometheus | http://localhost:9090 |
| cAdvisor | http://localhost:8081 |

Default admin credentials come from `.env` (`NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`).

First boot can take 1–2 minutes while Nextcloud installs into the shared volume.

## Cloud Concepts Demonstrated

| Concept | Implementation |
|---------|----------------|
| Container deployment | Docker Compose multi-service stack |
| Reverse proxy / LB | Nginx `ip_hash` across two Nextcloud instances |
| Shared application state | Shared `nextcloud_html` volume + Redis |
| Relational persistence | MariaDB with named volume |
| Object storage | MinIO (S3-compatible), recovered `minio-data/` preserved |
| Observability | Prometheus + cAdvisor |
| Health & recovery | Docker healthchecks + `scripts/auto_scale.ps1` |
| Backup / restore | `scripts/backup-db.ps1`, isolated `restore-db.ps1` |

## Operations

### Backup database

```powershell
.\scripts\backup-db.ps1
```

### Restore into an isolated test DB (safe)

```powershell
.\scripts\restore-db.ps1 -DumpFile .\backups\<file>.sql -RemoveAfter
```

### Upload a backup object to MinIO

```powershell
.\scripts\upload-backup-to-minio.ps1 -DumpFile .\backups\<file>.sql
```

### Run recovery monitor

```powershell
.\scripts\auto_scale.ps1
```

This script **recovers a fixed two-replica set**. It is not elastic autoscaling.

### Wire MinIO as Nextcloud external storage

1. Log into Nextcloud as admin  
2. Apps → enable **External storage support**  
3. Settings → External storage → Add **Amazon S3**  
4. Bucket: `nextcloud-bucket` (create via MinIO console if needed)  
5. Host: `nextcloud-minio`, Port: `9000`, enable path-style  
6. Access/secret keys: values from `.env`

## Project Layout

```text
EduCloud/
├── docker-compose.yml
├── .env.example
├── nginx-lb/nginx.conf
├── prometheus/prometheus.yml
├── scripts/          # backup, restore, recovery, minio upload
├── docs/             # architecture, testing, monitoring
├── archive/original/ # recovered Oct 2025 configs (secrets gitignored)
└── minio-data/       # local object store data (gitignored)
```

## Security Notes

- Secrets live in `.env` (gitignored). Use `.env.example` as the template.
- Original recovered dumps and configs contained real credentials/PII and are **not** published.
- Rotate any passwords that were ever used outside this lab before reuse elsewhere.

## Known Limitations

- Docker Hub pulls for official `minio/minio` were unavailable during recovery; Compose uses `cleanstart/minio` while preserving `./minio-data`.

- Original Nextcloud **file data volume was not recovered** — this repo ships a fresh reproducible install path.
- Dual Nextcloud on one volume is an educational pattern; production would usually use primary object storage, stricter session strategy, and orchestration.
- Prometheus scrapes infrastructure metrics (self + cAdvisor). Nextcloud’s Server Info API returns JSON and is not treated as native Prometheus metrics.
- cAdvisor on Docker Desktop may show host/container metrics differently than on Linux servers.

## Testing

See [docs/TESTING.md](docs/TESTING.md) for the checklist and recorded results.

## Resume Blurb

Built **EduCloud**, a Docker Compose private-cloud lab demonstrating Nginx load balancing across dual Nextcloud instances, MariaDB persistence, MinIO object storage, Prometheus/cAdvisor monitoring, SQL backup/restore workflows, and scripted container health recovery.
