# Install Android SDK command-line tools + packages for Flutter (after Android Studio is installed).
# Run once in PowerShell; may take several minutes.
$ErrorActionPreference = "Stop"
$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
$Cmdline = Join-Path $SdkRoot "cmdline-tools\latest"
$Sdkmanager = Join-Path $Cmdline "bin\sdkmanager.bat"

$JbrCandidates = @(
    "${env:ProgramFiles}\Android\Android Studio\jbr",
    "${env:ProgramFiles(x86)}\Android\Android Studio\jbr"
)
foreach ($jbr in $JbrCandidates) {
    if (Test-Path $jbr) {
        $env:JAVA_HOME = $jbr
        $env:Path = "$jbr\bin;$env:Path"
        break
    }
}
if (-not $env:JAVA_HOME) {
    Write-Host "WARN: JAVA_HOME not set. Install JDK or open Android Studio once." -ForegroundColor Yellow
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

Write-Host "SDK 目录: $SdkRoot"
Ensure-Dir $SdkRoot

if (-not (Test-Path $Sdkmanager)) {
    Write-Host "下载 Android command-line tools..."
    $zip = Join-Path $env:TEMP "commandlinetools-win.zip"
    $url = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $extract = Join-Path $env:TEMP "android-cmdline"
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $src = Join-Path $extract "cmdline-tools"
    if (-not (Test-Path $src)) { throw "cmdline-tools folder not found in zip" }
    $destParent = Join-Path $SdkRoot "cmdline-tools"
    Ensure-Dir $destParent
    $dest = Join-Path $destParent "latest"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $src $dest -Recurse -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $Sdkmanager)) {
    throw "sdkmanager 未找到: $Sdkmanager"
}

Write-Host "安装 SDK 组件 (platform-tools, platform, build-tools)..."
$yes = "y`n" * 20
$packages = @(
    "platform-tools",
    "platforms;android-35",
    "build-tools;35.0.0"
)
foreach ($pkg in $packages) {
    Write-Host "  -> $pkg"
    $yes | & $Sdkmanager $pkg --sdk_root=$SdkRoot 2>&1 | ForEach-Object { Write-Host $_ }
}

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter config --android-sdk $SdkRoot
    Write-Host ""
    Write-Host "接受 Android 许可..."
    ("y`n" * 50) | flutter doctor --android-licenses 2>&1 | ForEach-Object { Write-Host $_ }
    Write-Host ""
    flutter doctor -v
} else {
    Write-Host "请执行: flutter config --android-sdk `"$SdkRoot`""
}

$adb = Join-Path $SdkRoot "platform-tools\adb.exe"
if (Test-Path $adb) {
    Write-Host ""
    Write-Host "adb: $adb"
    & $adb version
} else {
    Write-Host "Restart terminal after platform-tools install." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. USB device: run start-api.ps1 then run-flutter-usb.ps1"
