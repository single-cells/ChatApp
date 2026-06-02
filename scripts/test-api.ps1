# 仅测试 API（需 Postgres/Redis/MinIO 已由 docker compose 启动）
$ErrorActionPreference = "Stop"
$ApiDir = "F:\_app\services\api"
Set-Location $ApiDir

Write-Host "检查 http://localhost:3000/health ..."
try {
    $h = Invoke-RestMethod -Uri "http://localhost:3000/health" -TimeoutSec 3
    Write-Host "API 已运行: $($h | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "API 未启动。请先运行 .\scripts\start-dev.ps1 或 npm run start:dev" -ForegroundColor Yellow
    exit 1
}

$deviceIdPath = Join-Path $env:TEMP "chat-test-device-id.txt"
if (Test-Path $deviceIdPath) {
    $deviceId = (Get-Content $deviceIdPath -Raw).Trim()
} else {
    $deviceId = [guid]::NewGuid().ToString()
    Set-Content -Path $deviceIdPath -Value $deviceId -NoNewline
    Write-Host "新测试 deviceId 已写入 $deviceIdPath"
}

Write-Host "设备登录..."
$body = @{
    deviceId = $deviceId
    nickname = "Windows测试"
} | ConvertTo-Json
$reg = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/auth/device" `
    -ContentType "application/json" -Body $body

if ($reg.needsNickname) {
    Write-Host "需要昵称，请检查脚本" -ForegroundColor Red
    exit 1
}

$token = $reg.accessToken
$headers = @{ Authorization = "Bearer $token" }

$room = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/rooms" `
    -Headers $headers -ContentType "application/json" -Body '{"title":"Windows Test Room"}'

Write-Host "OK" -ForegroundColor Green
Write-Host "accessToken prefix: $($token.Substring(0, [Math]::Min(20, $token.Length)))..."
Write-Host "roomId: $($room.roomId)"
Write-Host "Use roomId in Flutter or Socket.io client."
