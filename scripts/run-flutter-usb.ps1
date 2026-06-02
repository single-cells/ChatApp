# Run Flutter on a USB-connected Android phone.
# Maps phone localhost:3000 -> PC API via adb reverse (no WiFi IP needed).
# Prerequisites: API running (.\scripts\start-api.ps1), USB debugging on, Android SDK/adb.
param(
    [string]$DeviceId = "",
    [string]$ApiPort = "3000"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"

function Find-AdbExe {
    $candidates = @("$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe")
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"
    }
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) {
            return (Resolve-Path -LiteralPath $p).Path
        }
    }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.CommandType -eq "Application" -and $cmd.Path -and (Test-Path -LiteralPath $cmd.Path)) {
        return (Resolve-Path -LiteralPath $cmd.Path).Path
    }
    return $null
}

$UsbAdbExe = Find-AdbExe
if ([string]::IsNullOrWhiteSpace($UsbAdbExe)) {
    $sdk = "$env:LOCALAPPDATA\Android\Sdk"
    $hint = @(
        "adb not found (Android SDK platform-tools).",
        "",
        "Install SDK, then retry:",
        "  1. .\scripts\setup-android-sdk.ps1",
        "  2. Or install Android Studio and finish first-run SDK setup",
        "  3. flutter config --android-sdk $sdk",
        "  4. Add $sdk\platform-tools to PATH",
        "",
        "On phone: enable USB debugging and accept the PC authorization prompt."
    ) -join "`n"
    Write-Host $hint -ForegroundColor Yellow
    exit 1
}

Write-Host "adb: $UsbAdbExe"
& "$UsbAdbExe" devices -l
$hasDevice = $false
foreach ($line in (& "$UsbAdbExe" devices 2>&1 | ForEach-Object { "$_" })) {
    if ($line -match '\sdevice\s*$') {
        $hasDevice = $true
        break
    }
}
if (-not $hasDevice) {
    Write-Host "adb: no authorized device. Enable USB debugging and accept the PC prompt." -ForegroundColor Yellow
    exit 1
}

Write-Host "adb reverse: phone 127.0.0.1:${ApiPort} -> PC localhost:${ApiPort}"
& "$UsbAdbExe" reverse "tcp:${ApiPort}" "tcp:${ApiPort}"
if ($LASTEXITCODE -ne 0) {
    Write-Host "adb reverse failed (exit $LASTEXITCODE)." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter not found. Install Flutter SDK first." -ForegroundColor Yellow
    exit 1
}

$apiUrl = "http://127.0.0.1:${ApiPort}"

if (-not $DeviceId) {
    Write-Host ""
    Write-Host "Flutter devices:"
    flutter devices
    $json = flutter devices --machine 2>$null | ConvertFrom-Json
    $android = $json | Where-Object { $_.targetPlatform -eq "android" -and $_.emulator -eq $false }
    if ($android.Count -ge 1) {
        $DeviceId = $android[0].id
        Write-Host "Using Android device: $DeviceId"
    } else {
        $hint = @(
            "Flutter did not list an Android phone. If adb devices shows one, pass -DeviceId:",
            "",
            "  .\scripts\run-flutter-usb.ps1 -DeviceId DEVICE_ID",
            "",
            "Also run: flutter config --android-sdk YOUR_SDK_PATH"
        ) -join "`n"
        Write-Host $hint -ForegroundColor Yellow
        exit 1
    }
}

Set-Location $Mobile
Write-Host "Launching Flutter | device: $DeviceId | API: $apiUrl"
flutter run -d $DeviceId `
    --dart-define=API_BASE_URL=$apiUrl `
    --dart-define=WS_URL=$apiUrl
