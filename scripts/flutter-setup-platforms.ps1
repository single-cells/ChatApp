# Generate Flutter platform folders (windows/web/ios). Requires Flutter SDK on PATH.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Mobile = Join-Path $Root "apps\mobile"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "flutter not found. Install Flutter SDK and add to PATH, then retry." -ForegroundColor Yellow
    Write-Host "https://docs.flutter.dev/get-started/install/windows"
    exit 1
}

Set-Location $Mobile
Write-Host "Creating platform projects in $Mobile ..."
flutter create . --project-name chat_mobile
flutter pub get
Write-Host "Done. Try: flutter run -d windows  or  flutter run -d chrome" -ForegroundColor Green
Write-Host "See docs/DEV_WORKFLOW.md"
