# Clear all chat rooms from Postgres (users unchanged). API can stay running.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ApiDir = Join-Path $Root "services\api"

Set-Location $ApiDir
if (-not (Test-Path node_modules)) {
    Write-Host "npm install..."
    npm install
}

Write-Host "Deleting all rooms (messages/members cascade)..."
npm run rooms:clear
Write-Host "Done. Restart API or refresh Flutter list if needed." -ForegroundColor Green
