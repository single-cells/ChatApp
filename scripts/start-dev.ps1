# Windows 单机开发环境一键启动（需 Docker Desktop）
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Test-DockerRunning {
    docker info 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

if (-not (Test-DockerRunning)) {
    Write-Host "Docker 未运行，正在尝试启动 Docker Desktop..."
    $dockerDesktop = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktop) {
        Start-Process $dockerDesktop
        Write-Host "等待 Docker 就绪（最多 90 秒）..."
        $deadline = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 3
            if (Test-DockerRunning) { break }
        }
    }
    if (-not (Test-DockerRunning)) {
        Write-Host "请先手动打开 Docker Desktop，再重新运行本脚本。" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "启动 Postgres / Redis / MinIO..."
docker compose up -d
Start-Sleep -Seconds 5

Write-Host "初始化数据库..."
Set-Location "$Root\services\api"
if (-not (Test-Path node_modules)) {
    npm install
}
npx prisma db push

Write-Host "启动 API (http://localhost:3000，局域网 http://<本机IP>:3000)..."
Write-Host "手机浏览器测试: 另开终端运行 .\scripts\run-web-client.ps1"
Write-Host "另开终端运行 Flutter 见 docs/WINDOWS_LOCAL_TEST.md"
npm run start:dev
