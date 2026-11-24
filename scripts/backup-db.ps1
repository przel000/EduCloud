<#
.SYNOPSIS
  Create a timestamped MariaDB backup of the Nextcloud database.
#>

[CmdletBinding()]
param(
    [string]$ProjectDir = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $ProjectDir) {
    $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $ProjectDir "backups"
}

$envFile = Join-Path $ProjectDir ".env"
if (-not (Test-Path $envFile)) {
    throw ".env not found. Copy .env.example to .env first."
}

$envMap = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) { $envMap[$parts[0].Trim()] = $parts[1].Trim() }
}

$dbUser = $envMap["MYSQL_USER"]
$dbPass = $envMap["MYSQL_PASSWORD"]
$dbName = $envMap["MYSQL_DATABASE"]

if (-not $dbUser -or -not $dbPass -or -not $dbName) {
    throw "MYSQL_USER / MYSQL_PASSWORD / MYSQL_DATABASE missing from .env"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outFile = Join-Path $OutputDir "nextcloud_backup_$stamp.sql"

Write-Host "Creating backup: $outFile"
$dumpArgs = @(
    "exec", "nextcloud-db",
    "mariadb-dump",
    "-u$dbUser",
    "-p$dbPass",
    $dbName
)
$out = & docker @dumpArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "mariadb-dump failed: $out"
}
# Filter warning lines from stdout if any, keep SQL
$sql = ($out | Where-Object { $_ -is [string] -and $_ -notmatch '^mariadb-dump:' }) -join "`n"
[System.IO.File]::WriteAllText($outFile, $sql + "`n", (New-Object System.Text.UTF8Encoding $false))

$size = (Get-Item $outFile).Length
Write-Host "Backup complete ($size bytes)"
Write-Host $outFile