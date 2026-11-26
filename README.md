# EduCloud

EduCloud is a small private-cloud environment built using Docker Compose. I developed it to explore how different cloud infrastructure components work together, including file storage, load balancing, databases, object storage, monitoring, and automated recovery.

The project uses Nextcloud for file storage, Nginx to distribute traffic between two application instances, MariaDB for database storage, and MinIO for S3-compatible object storage. Prometheus and cAdvisor are used to monitor the containers, while PowerShell scripts handle database backups and container recovery.

## Architecture

```text
User → Nginx (:8080) → Nextcloud ×2 → MariaDB
                         ↘ Redis (locks/cache)

MinIO (S3 API) · Prometheus · cAdvisor · PowerShell recovery
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the architecture details.

## Requirements

- Docker Desktop (Windows) or Docker Engine with Compose v2
- PowerShell 5 or later
- A `.env` file containing the required passwords and configuration

## Getting Started

Clone or download the repository and open the project directory.

```powershell
cd EduCloud
Copy-Item .env.example .env
```

Update the credentials in `.env`, then start the services:

```powershell
docker compose up -d
docker compose ps
```

Once the containers are running, access the services here:

| Service | URL |
|---|---|
| Nextcloud | http://localhost:8080 |
| MinIO Console | http://localhost:9001 |
| Prometheus | http://localhost:9090 |
| cAdvisor | http://localhost:8081 |

Nextcloud's initial setup can take a minute or two. The administrator credentials are configured through `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` in `.env`.

## Components

| Component | Purpose |
|---|---|
| Docker Compose | Runs and manages the application containers |
| Nextcloud | Provides private cloud file storage |
| Nginx | Distributes requests between two Nextcloud instances using `ip_hash` |
| MariaDB | Stores application data |
| Redis | Handles file locking and caching |
| MinIO | Provides S3-compatible object storage |
| Prometheus | Collects monitoring metrics |
| cAdvisor | Provides container-level metrics |
| PowerShell | Handles container health checks and recovery |

## Backup and Recovery

The project includes PowerShell scripts for database backup, restoration, and uploading backup files to MinIO.

**Create a database backup**

```powershell
.\scripts\backup-db.ps1
```

**Restore a backup into a separate test database**

```powershell
.\scripts\restore-db.ps1 -DumpFile .\backups\<file>.sql -RemoveAfter
```

**Upload a backup to MinIO**

```powershell
.\scripts\upload-backup-to-minio.ps1 -DumpFile .\backups\<file>.sql
```

**Start the container recovery script**

```powershell
.\scripts\recover_containers.ps1
```

The recovery script monitors a fixed set of two application containers and attempts to replace containers that go down. It is a basic recovery mechanism, not dynamic autoscaling.

## MinIO and Nextcloud

MinIO is configured as S3-compatible object storage. It can also be connected to Nextcloud through the External Storage Support app.

To connect it:

1. Enable External Storage Support in Nextcloud.
2. Open Settings → External Storage.
3. Select Amazon S3 as the storage type.
4. Enter the bucket name: `nextcloud-bucket`.
5. Use `nextcloud-minio` as the host and port `9000`.
6. Enable path-style access and enter the MinIO credentials from `.env`.

Create the bucket in MinIO first if it does not already exist.

## Project Structure

```text
EduCloud/
├── docker-compose.yml
├── .env.example
├── nginx-lb/
│   └── nginx.conf
├── prometheus/
│   └── prometheus.yml
├── scripts/
│   ├── backup-db.ps1
│   ├── restore-db.ps1
│   ├── recover_containers.ps1
│   └── upload-backup-to-minio.ps1
├── docs/
│   ├── ARCHITECTURE.md
│   └── TESTING.md
├── archive/
│   └── original/
└── minio-data/
```

Original configuration files and recovered data are kept separately from the working setup.

## Security

- Credentials are stored in `.env`, which is excluded from Git.
- `.env.example` contains placeholder values for setup.
- Original database dumps and configuration files containing credentials or personal information are not included in the public repository.
- Any previously exposed credentials should be changed before reuse.

## Known Limitations

- The original MinIO image could not be pulled during recovery, so the current Compose setup uses `cleanstart/minio` while retaining the recovered `minio-data` directory.
- The original Nextcloud file-data volume was not recovered. The repository therefore uses a fresh installation rather than a complete restoration of the original instance.
- Both Nextcloud instances use a shared application volume. This is suitable for demonstrating the setup, but a production deployment would require a more carefully designed shared-storage and session-management configuration.
- Prometheus currently collects infrastructure metrics from itself and cAdvisor. Nextcloud's Server Info API returns JSON and is not configured as a native Prometheus metrics exporter.
- Container metrics may differ between Docker Desktop on Windows and a Linux host.

## Testing

See [docs/TESTING.md](docs/TESTING.md) for the test cases and recorded results.

## Project Summary

Built EduCloud as a Docker-based private cloud environment using Nextcloud, Nginx, MariaDB, and MinIO. Set up load balancing across two application instances, container monitoring with Prometheus and cAdvisor, database backup and restore scripts, and PowerShell-based container recovery.
