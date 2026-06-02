# One-click: API in new window -> wait for health -> Flutter (this terminal).
# Does not start Docker / Postgres / Redis / MinIO (use start-dev.ps1 for that).
param(
    [ValidateSet("windows", "chrome", "android", "usb")]
    [string]$Device = "windows",
    [int]$HealthTimeoutSec = 90
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Test-ApiHealthy {
    try {
        $h = Invoke-RestMethod -Uri "http://localhost:3000/health" -TimeoutSec 3
        return $null -ne $h.status
    } catch {
        return $false
    }
}

function Wait-ApiHealthy {
    param([int]$TimeoutSec)
    Write-Host "Waiting for API at http://localhost:3000/health ..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-ApiHealthy) {
            Write-Host "API is ready." -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

Set-Location $Root

$apiAlreadyUp = Test-ApiHealthy
if ($apiAlreadyUp) {
    Write-Host "API already running; skipping new API window." -ForegroundColor Green
} else {
    $apiScript = Join-Path $Root "scripts\start-api.ps1"
    Write-Host "Starting API in new window: $apiScript"
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $apiScript
    ) | Out-Null

    if (-not (Wait-ApiHealthy -TimeoutSec $HealthTimeoutSec)) {
        $msg = "API not ready within $HealthTimeoutSec seconds. Check the API terminal window."
        Write-Host $msg -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Starting Flutter ($Device). Hot reload: r | Quit: q" -ForegroundColor Cyan
Write-Host ""

if ($Device -eq "usb") {
    $flutterScript = Join-Path $Root "scripts\run-flutter-usb.ps1"
    & $flutterScript
} else {
    $flutterScript = Join-Path $Root "scripts\run-flutter.ps1"
    & $flutterScript -Device $Device
}
