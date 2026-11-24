# EduCloud Test Results

Recorded on 2026-11-24 against the rebuilt Docker Compose stack.

| ID | What was tested | How | Expected | Actual | Pass? |
|----|-----------------|-----|----------|--------|-------|
| T1 | Compose stack starts | `docker compose up -d` | Core services up/healthy | db, redis, app×2, nginx, minio, cadvisor healthy; prometheus fixed after UTF-8 config | PASS |
| T2 | Nextcloud via Nginx | HTTP ` /status.php` and `/login` | App reachable through LB | status.php 200 installed=true v29.0.16; /login 200 | PASS |
| T3 | DB connectivity | status.php + successful install state | DB-backed app responds | installed=true, needsDbUpgrade=false | PASS |
| T4 | Persistence | Restart both app containers | Still installed/serving | status.php still 200 after restart | PASS |
| T5 | Load balancing failover | Stop `nextcloud-app-2`, hit gateway | Gateway still serves | status.php 200 while app-2 stopped | PASS |
| T6 | MinIO access + upload | Health endpoints + AWS CLI S3 cp | Live API/console; object listed | health/live 200; uploaded object; recovered Oct 2025 object still present | PASS |
| T7 | Prometheus targets | `/api/v1/targets` | prometheus + cadvisor UP | both `up` | PASS |
| T8 | cAdvisor | `/healthz` on :8081 | healthy | 200 ok | PASS |
| T9 | Recovery recreate | Stop app-2, `compose up -d --no-deps` | Recreated + healthy | healthy + gateway 200 | PASS |
| T10 | DB backup | `scripts/backup-db.ps1` | Timestamped SQL created | 175891-byte dump created | PASS |
| T11 | DB restore (isolated) | `scripts/restore-db.ps1 -RemoveAfter` | Tables loaded in test DB | 103 tables restored; container removed | PASS |

## Notes

- Official `minio/minio` image pulls were denied in this environment; stack uses `cleanstart/minio` and still mounts recovered `./minio-data`.
- Original Oct 2025 SQL dumps with PII remain local/gitignored and were not used as the published demo dataset.
- Recovery script uses Compose recreate of a fixed replica set (not elastic autoscaling).