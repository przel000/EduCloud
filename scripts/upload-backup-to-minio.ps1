<#
.SYNOPSIS
  Upload a local SQL backup object into the MinIO nextcloud-bucket.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DumpFile,
    [string]$ProjectDir = "",
    [string]$Bucket = "nextcloud-bucket"
)

$ErrorActionPreference = "Stop"

if (-not $ProjectDir) {
    $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
if (-not (Test-Path $DumpFile)) {
    throw "Dump file not found: $DumpFile"
}

$envFile = Join-Path $ProjectDir ".env"
$envMap = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) { $envMap[$parts[0].Trim()] = $parts[1].Trim() }
}

$user = $envMap["MINIO_ROOT_USER"]
$pass = $envMap["MINIO_ROOT_PASSWORD"]
$objectName = Split-Path $DumpFile -Leaf

# Official minio/mc is unavailable in some environments; use AWS CLI against MinIO's S3 API.
$env:AWS_ACCESS_KEY_ID = $user
$env:AWS_SECRET_ACCESS_KEY = $pass
$env:AWS_DEFAULT_REGION = "us-east-1"

Write-Host "Ensuring bucket '$Bucket' exists..."
docker run --rm --network educloud_default `
    -e AWS_ACCESS_KEY_ID `
    -e AWS_SECRET_ACCESS_KEY `
    -e AWS_DEFAULT_REGION `
    -v "${DumpFile}:/tmp/upload.sql:ro" `
    amazon/aws-cli:latest `
    --endpoint-url http://nextcloud-minio:9000 s3 mb "s3://$Bucket" 2>$null

docker run --rm --network educloud_default `
    -e AWS_ACCESS_KEY_ID `
    -e AWS_SECRET_ACCESS_KEY `
    -e AWS_DEFAULT_REGION `
    -v "${DumpFile}:/tmp/upload.sql:ro" `
    amazon/aws-cli:latest `
    --endpoint-url http://nextcloud-minio:9000 s3 cp /tmp/upload.sql "s3://$Bucket/$objectName"

docker run --rm --network educloud_default `
    -e AWS_ACCESS_KEY_ID `
    -e AWS_SECRET_ACCESS_KEY `
    -e AWS_DEFAULT_REGION `
    amazon/aws-cli:latest `
    --endpoint-url http://nextcloud-minio:9000 s3 ls "s3://$Bucket/"

Write-Host "Upload complete: s3://$Bucket/$objectName"
