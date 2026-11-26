<#
.SYNOPSIS
  EduCloud container recovery and self-healing simulation.

.DESCRIPTION
  Monitors Nextcloud app containers with Docker state checks AND HTTP probes.
  If a monitored container is unhealthy or unreachable, replaces it using the
  same Compose service definition (docker compose up -d --no-deps <service>).

  This is recovery / self-healing simulation for a fixed replica set.
  It is NOT dynamic horizontal auto-scaling (no capacity policy / scale-out math).
#>

[CmdletBinding()]
param(
    [int]$IntervalSeconds = 0,
    [string]$ComposeFile = "",
    [string]$ProjectDir = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ProjectDir) {
    $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
if (-not $ComposeFile) {
    $ComposeFile = Join-Path $ProjectDir "docker-compose.yml"
}
if (-not $LogDir) {
    $LogDir = Join-Path $ProjectDir "logs"
}

# Load .env values when present
$envFile = Join-Path $ProjectDir ".env"
$envMap = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
        $parts = $_ -split '=', 2
        if ($parts.Count -eq 2) {
            $envMap[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
}

if ($IntervalSeconds -le 0) {
    if ($envMap.ContainsKey("HEALTHCHECK_INTERVAL_SECONDS")) {
        $IntervalSeconds = [int]$envMap["HEALTHCHECK_INTERVAL_SECONDS"]
    } else {
        $IntervalSeconds = 20
    }
}

$healthUrlBase = if ($envMap.ContainsKey("HEALTHCHECK_URL")) {
    ($envMap["HEALTHCHECK_URL"] -replace '/status\.php$', '')
} else {
    "http://localhost:8080"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$logFile = Join-Path $LogDir ("recovery_{0:yyyyMMdd}.log" -f (Get-Date))

# Fixed replica map: container name -> compose service
$targets = [ordered]@{
    "nextcloud-app"   = "nextcloud-app"
    "nextcloud-app-2" = "nextcloud-app-2"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Test-ContainerRunning {
    param([string]$Name)
    $status = docker inspect -f '{{.State.Running}}' $Name 2>$null
    return ($status -eq "true")
}

function Test-ContainerHealthy {
    param([string]$Name)
    $health = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $Name 2>$null
    if (-not $health -or $health -eq "none") {
        return $true  # no healthcheck defined -> rely on running + HTTP
    }
    return ($health -eq "healthy")
}

function Test-HttpEndpoint {
    param([string]$Url, [int]$TimeoutSec = 5)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        return ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Repair-Service {
    param([string]$ContainerName, [string]$ServiceName)

    Write-Log "Recovery started for $ContainerName (service $ServiceName)" "WARN"

    # Remove failed container if it still exists (stopped/unhealthy)
    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
    if ($exists) {
        Write-Log "Removing failed container $ContainerName"
        docker rm -f $ContainerName 2>$null | Out-Null
    }

    # Prevent duplicate replicas: only recreate the named compose service
    Push-Location $ProjectDir
    try {
        docker compose -f $ComposeFile up -d --no-deps --force-recreate $ServiceName
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Compose recreate failed for $ServiceName" "ERROR"
            return $false
        }
    } finally {
        Pop-Location
    }

    # Validate replacement
    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $running = Test-ContainerRunning -Name $ContainerName
        $healthy = Test-ContainerHealthy -Name $ContainerName
        $httpOk = Test-HttpEndpoint -Url "$healthUrlBase/status.php"
        Write-Log "Validation: running=$running healthy=$healthy http=$httpOk"
        if ($running -and $healthy -and $httpOk) {
            Write-Log "Recovery validated for $ContainerName" "INFO"
            return $true
        }
    }

    Write-Log "Recovery validation timed out for $ContainerName" "ERROR"
    return $false
}

Write-Log "EduCloud recovery monitor started (interval=${IntervalSeconds}s)"
Write-Log "Compose file: $ComposeFile"
Write-Log "HTTP probe via: $healthUrlBase/status.php"

while ($true) {
    foreach ($container in $targets.Keys) {
        $service = $targets[$container]
        $running = Test-ContainerRunning -Name $container
        $healthy = $false
        if ($running) { $healthy = Test-ContainerHealthy -Name $container }

        if ($running -and $healthy) {
            Write-Log "$container OK (running + healthy)"
        } else {
            Write-Log "$container NOT OK (running=$running healthy=$healthy) — recovering" "WARN"
            Repair-Service -ContainerName $container -ServiceName $service | Out-Null
        }
    }

    # Gateway-level HTTP check (through Nginx when available)
    $gatewayOk = Test-HttpEndpoint -Url "$healthUrlBase/status.php"
    if ($gatewayOk) {
        Write-Log "Gateway HTTP probe OK"
    } else {
        Write-Log "Gateway HTTP probe FAILED" "WARN"
    }

    Write-Log "Sleeping $IntervalSeconds seconds..."
    Start-Sleep -Seconds $IntervalSeconds
}
