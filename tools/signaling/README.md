# Bean Party WebRTC signaling service

Hosted signaling and short-lived ICE/TURN credential service for Bean Party internet transport. This service arranges WebRTC peer connections only; it does not run gameplay, board logic, or minigame authority.

## Responsibilities

- WebSocket signaling at `/v1/signal` using the existing Bean Party / Godot webrtc_signaling wire protocol
- `GET /healthz` liveness and `GET /readyz` readiness probes
- `GET /v1/ice` short-lived coturn-compatible TURN REST credentials plus configured STUN URLs
- In-memory room lifecycle with strict peer, payload, and rate limits

Bean Party remains peer-hosted. The signaling service is not a game server.

## Local development

```bash
cd tools/signaling
npm install
npm start
```

Default endpoints:

- Signaling: `ws://127.0.0.1:9080/v1/signal?protocol=1`
- ICE config: `http://127.0.0.1:9080/v1/ice`
- Health: `http://127.0.0.1:9080/healthz`
- Readiness: `http://127.0.0.1:9080/readyz`

Godot contributor checkouts load these defaults from `config/online_services.development.json`.

## Tests

```bash
npm test
```

Node 20+ is required (`node --test`).

## Production container

```bash
docker build -t bean-party-signaling .
docker run --rm -e PORT=8080 -p 8080:8080 bean-party-signaling
```

## Railway deployment

Service root: `tools/signaling`

- Install: `npm ci`
- Start: `npm start`
- Bind: `0.0.0.0:$PORT`
- Replicas: **1 only** for this phase
- Health check path: `/healthz`
- Generated public domain only; do not commit a fake production hostname

Copy `.env.example` into Railway variables. Required secrets come from the repository owner:

- `TURN_SHARED_SECRET` when `TURN_URLS` or `TURNS_URLS` are set

See [WebRTC operations runbook](../../docs/guides/webrtc-ops.md) for TLS/WSS, secret rotation, rate limits, and TURN deployment follow-up.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `HOST` | Listen host (`0.0.0.0` in hosted environments) |
| `PORT` | Listen port (Railway-provided) |
| `SIGNALING_PATH` | WebSocket path (`/v1/signal`) |
| `ICE_PATH` | ICE credential HTTP path (`/v1/ice`) |
| `SIGNALING_PROTOCOL_VERSION` | Required client protocol version |
| `MAX_CONNECTIONS` | Total concurrent WebSocket peers |
| `MAX_ROOMS` | Concurrent rooms |
| `MAX_PEERS_PER_ROOM` | Bean Party cap (4) |
| `MAX_SIGNALING_PAYLOAD_BYTES` | Signaling payload byte limit |
| `ROOM_INACTIVITY_MS` | Idle room expiration |
| `ROOM_MAX_LIFETIME_MS` | Absolute room expiration |
| `STUN_URLS` | Comma-separated STUN URLs |
| `TURN_URLS` | Comma-separated `turn:` URLs |
| `TURNS_URLS` | Comma-separated `turns:` URLs |
| `TURN_SHARED_SECRET` | coturn REST shared secret |
| `TURN_CREDENTIAL_TTL_SEC` | Credential lifetime |
| `TRUST_PROXY` | Enable trusted `X-Forwarded-For` parsing |
| `LOG_LEVEL` | Structured log level |

## Security notes

- Room state is in-memory; multiple replicas require a shared registry such as Redis
- Do not log SDP, ICE candidates, TURN credentials, or room invitation secrets
- Anonymous ICE credential issuance can incur TURN egress cost; rate limits are enabled by default
- Railway hosts signaling over HTTPS/WSS; coturn itself must run on infrastructure that supports relay ports

## Client configuration

Godot resolves hosted endpoints through `OnlineServiceConfig`:

1. explicit runtime/test options
2. environment variables
3. `user://online_services.json`
4. `res://config/online_services.release.json` or development config in debug builds
5. explicit localhost fallback for contributor development only

Release exports do not silently use `ws://127.0.0.1:9080`.
