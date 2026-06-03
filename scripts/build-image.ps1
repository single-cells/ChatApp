param(
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Image = "chat-api:$Tag"
$OutDir = Join-Path $Root "deploy"
$Archive = Join-Path $OutDir "chat-api-$Tag.tar.gz"

Set-Location $Root

Write-Host "Building $Image ..."
docker build -t $Image -f services/api/Dockerfile services/api
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Saving to $Archive ..."
if (Get-Command gzip -ErrorAction SilentlyContinue) {
    docker save $Image | gzip > $Archive
} else {
    $TarPath = Join-Path $OutDir "chat-api-$Tag.tar"
    docker save -o $TarPath $Image
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "gzip not found; saved uncompressed: $TarPath" -ForegroundColor Yellow
    Write-Host "On server: docker load -i chat-api-$Tag.tar"
    exit 0
}

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done. Upload: scp deploy/* tencent:~/myapp/ChatApp/" -ForegroundColor Green
