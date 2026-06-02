# 在浏览器打开 Web 测试客户端（无需 Flutter）
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ClientDir = Join-Path $Root "tools\web-client"

Write-Host "Web 客户端目录: $ClientDir"
Write-Host "请确保 API 已运行: http://localhost:3000/health"
Write-Host ""
$lanIp = (
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notmatch '^127\.' -and
        $_.IPAddress -notmatch '^169\.254\.' -and
        $_.PrefixOrigin -ne 'WellKnown'
    } |
    Select-Object -First 1 -ExpandProperty IPAddress
)
if (-not $lanIp) { $lanIp = '<本机局域网IP>' }

Write-Host "启动静态服务器（监听 0.0.0.0:8080）..."
Write-Host "本机: http://localhost:8080"
Write-Host "手机（同 WiFi）: http://${lanIp}:8080"
Write-Host "API 地址会自动填为 http://${lanIp}:3000（需先运行 start-dev.ps1）"
Write-Host ""

Set-Location $ClientDir
Start-Process "http://localhost:8080"
npx --yes serve -l tcp://0.0.0.0:8080 .
