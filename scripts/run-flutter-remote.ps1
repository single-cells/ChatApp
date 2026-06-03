# Run Flutter on PC against the remote server in deploy/.env (same as APK).
# Prerequisites: Flutter SDK, Windows desktop enabled (flutter config).
#   .\scripts\run-flutter-remote.ps1
#   .\scripts\run-flutter-remote.ps1 -Device chrome   # may fail CORS unless server allows localhost
param(
    [ValidateSet("windows", "chrome")]
    [string]$Device = "windows",
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"

if (-not $EnvFile) {
    $EnvFile = Join-Path $Root "deploy\.env"
}

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile (copy deploy.env.example to deploy/.env)" -ForegroundColor Red
    exit 1
}

function Get-EnvValue([string]$Name) {
    $line = Get-Content $EnvFile | Where-Object { $_ -match "^\s*$Name=" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -split "=", 2)[1].Trim()
}

$apiUrl = Get-EnvValue "CORS_ORIGIN"
$clientSecret = Get-EnvValue "CLIENT_APP_SECRET"
$allowInsecureSsl = Get-EnvValue "ALLOW_INSECURE_SSL"
if ($allowInsecureSsl -match '^(1|true|yes)$') {
    $allowInsecureSsl = "true"
} else {
    $allowInsecureSsl = "false"
}

if (-not $apiUrl -or -not $clientSecret) {
    Write-Host "deploy/.env must define CORS_ORIGIN and CLIENT_APP_SECRET" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "flutter not found. See apps/mobile/SETUP_FLUTTER.md" -ForegroundColor Yellow
    exit 1
}

if ($Device -eq "chrome") {
    Write-Host "Note: Web may be blocked by server CORS (CORS_ORIGIN=$apiUrl). Prefer -Device windows." -ForegroundColor Yellow
}

Set-Location $Mobile
Write-Host "Remote test | device: $Device"
Write-Host "  API_BASE_URL=$apiUrl"
Write-Host "  ALLOW_INSECURE_SSL=$allowInsecureSsl"

flutter pub get
$runArgs = @(
    "run",
    "-d", $Device,
    "--dart-define=API_BASE_URL=$apiUrl",
    "--dart-define=WS_URL=$apiUrl",
    "--dart-define=CLIENT_APP_SECRET=$clientSecret",
    "--dart-define=ALLOW_INSECURE_SSL=$allowInsecureSsl"
)
# Flutter Web from localhost is blocked by production CORS_ORIGIN; dev-only bypass.
if ($Device -eq "chrome") {
    $chromeProfile = Join-Path $env:TEMP "chat_mobile_chrome_dev"
    $runArgs += "--web-browser-flag=--disable-web-security"
    $runArgs += "--web-browser-flag=--user-data-dir=$chromeProfile"
}
flutter @runArgs
