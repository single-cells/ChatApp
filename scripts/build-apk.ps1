param(
    [string]$EnvFile = "",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"
$OutDir = Join-Path $Root "deploy_apk"

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

$jdk17 = "C:\Program Files (x86)\Android\openjdk\jdk-17.0.8.101-hotspot"
$jbr = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path $jdk17) {
    $env:JAVA_HOME = $jdk17
} elseif (Test-Path $jbr) {
    $env:JAVA_HOME = $jbr
    Write-Warning "JDK 17 not found; falling back to Android Studio JBR (may crash on release builds)."
}
if ($env:JAVA_HOME) {
    $env:ORG_GRADLE_JAVA_HOME = $env:JAVA_HOME
    $env:Path = "$env:JAVA_HOME\bin;" + ($env:Path -replace [regex]::Escape("$jbr\bin;"), "")
}

# Keep Pub cache on F: to match project drive (avoids Kotlin incremental path issues)
$pubCache = "F:\pub-cache"
New-Item -ItemType Directory -Force -Path $pubCache | Out-Null
$env:PUB_CACHE = $pubCache

$androidDir = Join-Path $Mobile "android"
$pubspec = Join-Path $Mobile "pubspec.yaml"
$versionLine = Get-Content $pubspec | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch 'version:\s*(.+)$') {
    Write-Host "Could not parse version from pubspec.yaml" -ForegroundColor Red
    exit 1
}
$versionTag = $Matches[1].Trim() -replace '\+', '-build'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Set-Location $Mobile
Write-Host "Building APK -> deploy_apk/"
Write-Host "  API_BASE_URL=$apiUrl"
Write-Host "  ALLOW_INSECURE_SSL=$allowInsecureSsl"
Write-Host "  JAVA_HOME=$env:JAVA_HOME"

if ($Clean) {
    flutter clean
}
flutter pub get
flutter build apk --release `
    --dart-define=API_BASE_URL=$apiUrl `
    --dart-define=WS_URL=$apiUrl `
    --dart-define=CLIENT_APP_SECRET=$clientSecret `
    --dart-define=ALLOW_INSECURE_SSL=$allowInsecureSsl `
    --dart-define=ENABLE_APP_UPDATE=false

$built = Join-Path $Mobile "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $built)) {
    Write-Host "Build failed: $built not found" -ForegroundColor Red
    exit 1
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$destStamped = Join-Path $OutDir "FreeChat-$versionTag-$stamp.apk"
$destVersioned = Join-Path $OutDir "FreeChat-$versionTag.apk"
$destLatest = Join-Path $OutDir "FreeChat.apk"
Copy-Item $built $destStamped -Force
Copy-Item $built $destVersioned -Force
Copy-Item $built $destLatest -Force

Write-Host "Done:" -ForegroundColor Green
Write-Host "  $destStamped"
Write-Host "  $destVersioned"
Write-Host "  $destLatest (latest shortcut)"
