# EduCloud Architecture

## Overview

EduCloud is a small private-cloud lab that demonstrates containerized file storage, reverse-proxy load balancing, relational persistence, object storage, monitoring, backup/restore, and scripted recovery.

```text
                         Browser / Client
                                |
                                v
                     +----------------------+
                     |  nginx-lb (:8080)    |
                     |  reverse proxy + LB  |
                     +----------+-----------+
                                |
              +-----------------+-----------------+
              |                                   |
              v                                   v
     nextcloud-app                         nextcloud-app-2
     (Nextcloud 29)                        (Nextcloud 29)
              |                                   |
              +-----------------+-----------------+
                                |
              +-----------------+-----------------+
              |                 |                 |
              v                 v                 v
        nextcloud-db         redis          nextcloud-html
        (MariaDB 11.4)   (session/locks)   (shared volume)

Parallel infrastructure
-----------------------
nextcloud-minio   Object storage (S3 API) + console
prometheus        Metrics collection
cadvisor          Container resource metrics
scripts/*         Backup, restore, recovery simulation
```

## Design Decisions

| Decision | Why |
|----------|-----|
| Two Nextcloud containers share one HTML/data volume | Matches the original dual-instance intent without claiming Kubernetes-scale orchestration |
| Redis added | Distributed locking/cache is required for safe multi-instance Nextcloud |
| Nginx `ip_hash` | Sticky sessions reduce session weirdness across instances |
| MinIO bind-mounted to `./minio-data` | Preserves recovered object-store data; no re-init wipe |
| MariaDB 11.4 | Compatible with the Oct 2025 dump host (11.8.x family) better than old 10.6 Compose pin |
| Recovery script uses Compose recreate | Avoids orphan replica containers with random names |
| Prometheus scrapes itself + cAdvisor | Credible native metrics; Nextcloud Server Info JSON is not Prometheus format |

## What This Is / Is Not

**Is:** A reproducible Docker Compose private-cloud demo for portfolio/interview discussion.

**Is not:** Production multi-tenant cloud, Kubernetes platform, or genuine elastic autoscaling. The PowerShell monitor recovers a fixed two-replica set; it does not decide capacity from load.
