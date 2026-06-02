# 上线检查清单（Phase 6）

## 安全

- [ ] 更换 `JWT_SECRET` 与 MinIO 密钥
- [ ] 启用 HTTPS / WSS
- [ ] 配置 CORS 白名单（`CORS_ORIGIN`）
- [ ] 消息频率限制（已实现：每用户每房间 10 条/秒）

## 合规

- [ ] 隐私政策（说明聊天内容、语音采集）
- [ ] iOS `NSMicrophoneUsageDescription`
- [ ] Android `RECORD_AUDIO` 权限说明

## 推送（可选）

- [ ] FCM / APNs 配置后，在 `services/api` 增加 push 模块

## 连麦

- [ ] 部署 LiveKit Server 与 coturn
- [ ] 配置 `LIVEKIT_*` 环境变量

## 商店

- [ ] 应用图标与截图
- [ ] TestFlight / Google Play 内测轨道
