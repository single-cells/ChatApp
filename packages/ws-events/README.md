# WebSocket events (Socket.io)

## Client → Server

| Event | Payload |
|-------|---------|
| `room.join` | `{ roomId: string }` |
| `room.leave` | `{ roomId: string }` |
| `message.send` | `{ roomId, type, content?, attachmentUrl?, attachmentMeta? }` |
| `call.join` | `{ roomId: string }` |
| `call.leave` | `{ roomId: string }` |

## Server → Client

| Event | Payload |
|-------|---------|
| `room.ready` | `{ roomId: string }` |
| `message.new` | Message object with seq |
| `call.state` | `{ roomId, participants: [{ userId, nickname, muted }] }` |
| `presence.update` | `{ roomId, count: number }` |
| `error` | `{ code, message }` |
