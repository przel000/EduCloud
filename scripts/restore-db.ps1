<#
.SYNOPSIS
  Restore a Nextcloud SQL dump into a disposable test database container.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DumpFile,
    [string]$TestContainer = "educloud-db-restore-test",
    [string]$TestPort = "3307",
    [switch]$RemoveAfter
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DumpFile)) {
    throw "Dump file not found: $DumpFile"
}

Write-Host "Starting isolated restore test container: $TestContainer"
cmd /c "docker rm -f $TestContainer >nul 2>&1"

docker run -d --name $TestContainer `
    -e MYSQL_ROOT_PASSWORD=restore_test_root `
    -e MYSQL_DATABASE=nextcloud `
    -e MYSQL_USER=nextcloud `
    -e MYSQL_PASSWORD=restore_test_pw `
    -p "${TestPort}:3306" `
    mariadb:11.4 | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to start test container"
}

Write-Host "Waiting for MariaDB to become ready..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    cmd /c "docker exec $TestContainer healthcheck.sh --connect --innodb_initialized >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
}
if (-not $ready) {
    throw "Test database did not become ready in time."
}

Write-Host "Importing dump..."
Get-Content -Raw $DumpFile | docker exec -i $TestContainer mariadb -unextcloud -prestore_test_pw nextcloud
if ($LASTEXITCODE -ne 0) {
    throw "Import failed."
}

Write-Host "Verifying tables..."
$tables = docker exec $TestContainer mariadb -unextcloud -prestore_test_pw -N -e "SHOW TABLES;" nextcloud
$tableCount = @($tables | Where-Object { $_ -and $_.Trim() -ne "" }).Count
Write-Host "Restored table count: $tableCount"

if ($tableCount -lt 1) {
    throw "Restore verification failed: no tables found."
}

Write-Host "Restore test PASSED."
if ($RemoveAfter) {
    cmd /c "docker rm -f $TestContainer >nul 2>&1"
    Write-Host "Removed test container $TestContainer"
} else {
    Write-Host "Test container left running on localhost:${TestPort}"
}