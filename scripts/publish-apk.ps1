param(
    [string]$EnvFile = "",
    [string]$SshHost = "tencent",
    [string]$RemoteDir = "~/myapp/ChatApp",
    [string]$Changelog = "版本更新",
    [switch]$SkipBuild,
    [switch]$ForceUpdate
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"
$Pubspec = Join-Path $Mobile "pubspec.yaml"
$LocalReleases = Join-Path $Root "deploy\releases"
$ApkLocal = Join-Path $Root "deploy_apk\FreeChat.apk"
$NginxReleases = "/var/www/chat-releases"

if (-not $EnvFile) {
    $EnvFile = Join-Path $Root "deploy\.env"
}

function Get-EnvValue([string]$Name) {
    $line = Get-Content $EnvFile | Where-Object { $_ -match "^\s*$Name=" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -split "=", 2)[1].Trim()
}

if (-not (Test-Path $EnvFile)) {
    Write-Host "Missing $EnvFile" -ForegroundColor Red
    exit 1
}

$baseUrl = (Get-EnvValue "CORS_ORIGIN").TrimEnd("/")
if (-not $baseUrl) {
    Write-Host "deploy/.env must define CORS_ORIGIN" -ForegroundColor Red
    exit 1
}

if (-not $SkipBuild) {
    & (Join-Path $Root "scripts\build-apk.ps1") -EnvFile $EnvFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-Path $ApkLocal)) {
    $legacy = Join-Path $Root "deploy_apk\app-release.apk"
    if (Test-Path $legacy) {
        $ApkLocal = $legacy
    } else {
        Write-Host "APK not found: $ApkLocal (run build-apk.ps1 first)" -ForegroundColor Red
        exit 1
    }
}

$versionLine = Get-Content $Pubspec | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
if (-not $versionLine) {
    Write-Host "Could not parse version from pubspec.yaml" -ForegroundColor Red
    exit 1
}
$versionRaw = ($versionLine -split ":", 2)[1].Trim()
if ($versionRaw -notmatch '^(.+)\+(\d+)$') {
    Write-Host "pubspec version must be name+code, e.g. 0.1.1+2" -ForegroundColor Red
    exit 1
}
$versionName = $Matches[1]
$versionCode = [int]$Matches[2]

New-Item -ItemType Directory -Force -Path $LocalReleases | Out-Null
$manifest = @{
    versionName   = $versionName
    versionCode   = $versionCode
    apkUrl        = "$baseUrl/releases/app-release.apk"
    changelog     = $Changelog
    forceUpdate   = [bool]$ForceUpdate
}
$manifestPath = Join-Path $LocalReleases "latest.json"
$json = $manifest | ConvertTo-Json -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)

Copy-Item $ApkLocal (Join-Path $LocalReleases "app-release.apk") -Force

Write-Host "Publishing $versionName+$versionCode"
Write-Host "  apkUrl: $($manifest.apkUrl)"
Write-Host "  -> ${SshHost}:${RemoteDir}/releases/"

ssh $SshHost "mkdir -p ${RemoteDir}/releases"
scp (Join-Path $LocalReleases "app-release.apk") "${SshHost}:${RemoteDir}/releases/app-release.apk"
scp $manifestPath "${SshHost}:${RemoteDir}/releases/latest.json"

$patchNginx = @'
if ! grep -q 'location /releases/' /etc/nginx/conf.d/chatapp.conf 2>/dev/null; then
  echo "WARN: Nginx missing /releases/ — run setup-ssl.sh bootstrap again or merge deploy/nginx/chatapp.conf"
fi
'@

ssh $SshHost @"
set -e
mkdir -p $NginxReleases
cp ${RemoteDir}/releases/app-release.apk $NginxReleases/
cp ${RemoteDir}/releases/latest.json $NginxReleases/
chmod 644 $NginxReleases/*
$patchNginx
nginx -t
nginx -s reload
echo "OK: $baseUrl/releases/app-release.apk"
curl -sfk ${baseUrl}/releases/latest.json || curl -sf ${baseUrl}/releases/latest.json
"@

Write-Host "Done." -ForegroundColor Green
