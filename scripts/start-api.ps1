# Start NestJS API only (watch). Assumes Docker (Postgres/Redis/MinIO) is already running.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ApiDir = Join-Path $Root "services\api"

docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Start Docker Desktop or run .\scripts\start-dev.ps1 for full setup." -ForegroundColor Yellow
    exit 1
}

Set-Location $ApiDir
if (-not (Test-Path node_modules)) {
    Write-Host "npm install..."
    npm install
}

Write-Host "API: http://localhost:3000/health"
Write-Host "Flutter: open another terminal -> .\scripts\run-flutter.ps1"
npm run start:dev
