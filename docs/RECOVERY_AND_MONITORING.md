# Monitoring and Recovery

## Container Metrics

- **cAdvisor** exposes per-container CPU/memory/network metrics on port `8081`.
- **Prometheus** scrapes cAdvisor and itself on port `9090`.

## Application Health

- Each Nextcloud service has a Docker healthcheck against `/status.php`.
- Nginx exposes `/nginx-health` for proxy liveness.
- `scripts/auto_scale.ps1` combines:
  - `docker inspect` running/health state
  - HTTP probe through the gateway
  - Compose-based recreation of the failed service
  - Validation wait loop + file logging under `logs/`

## Naming Clarity

The historical script was titled “auto-scaling.” EduCloud documents it accurately as **fixed-replica recovery simulation**. Horizontal autoscaling would require a scaling policy, metrics thresholds, and dynamic replica counts.

## Database Backup / Restore

```powershell
# Backup live DB
.\scripts\backup-db.ps1

# Optional: upload to MinIO
.\scripts\upload-backup-to-minio.ps1 -DumpFile .\backups\nextcloud_backup_YYYY-MM-DD_HH-mm-ss.sql

# Restore into an isolated test container (does not overwrite live volume)
.\scripts\restore-db.ps1 -DumpFile .\backups\nextcloud_backup_YYYY-MM-DD_HH-mm-ss.sql -RemoveAfter
```
