# Run Flutter on Windows desktop (hot reload). API must be running (.\scripts\start-api.ps1).
param(
    [ValidateSet("windows", "chrome", "android")]
    [string]$Device = "windows"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"

$apiUrl = "http://localhost:3000"
if ($Device -eq "android") {
    $apiUrl = "http://10.0.2.2:3000"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "flutter not found. See apps/mobile/SETUP_FLUTTER.md" -ForegroundColor Yellow
    exit 1
}

Set-Location $Mobile
Write-Host "Device: $Device | API: $apiUrl"
flutter run -d $Device `
    --dart-define=API_BASE_URL=$apiUrl `
    --dart-define=WS_URL=$apiUrl
