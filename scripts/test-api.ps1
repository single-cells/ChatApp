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

Write-Host "注册测试用户..."
$body = @{
    email    = "win-test@local.dev"
    password = "123456"
    nickname = "Windows测试"
} | ConvertTo-Json
try {
    $reg = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/auth/register" `
        -ContentType "application/json" -Body $body
} catch {
    Write-Host "注册失败（可能已存在），尝试登录..."
    $reg = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/auth/login" `
        -ContentType "application/json" -Body (@{ email = "win-test@local.dev"; password = "123456" } | ConvertTo-Json)
}

$token = $reg.accessToken
$headers = @{ Authorization = "Bearer $token" }

$room = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/rooms" `
    -Headers $headers -ContentType "application/json" -Body '{"title":"Windows Test Room"}'

Write-Host "OK" -ForegroundColor Green
Write-Host "accessToken prefix: $($token.Substring(0, [Math]::Min(20, $token.Length)))..."
Write-Host "roomId: $($room.roomId)"
Write-Host "Use roomId in Flutter or Socket.io client."
