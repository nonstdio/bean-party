const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("http");
const WebSocket = require("ws");
const { createApp } = require("../src/app");
const { generateTurnCredentials } = require("../src/turn");
const { ErrorCategory } = require("../src/errors");

const TEST_CONFIG = {
  host: "127.0.0.1",
  port: 0,
  signalingPath: "/v1/signal",
  icePath: "/v1/ice",
  protocolVersion: "1",
  maxConnections: 8,
  maxRooms: 4,
  maxPeersPerRoom: 4,
  maxSignalingPayloadBytes: 1024,
  maxHttpBodyBytes: 4096,
  roomInactivityMs: 200,
  roomMaxLifetimeMs: 500,
  noLobbyTimeoutMs: 200,
  sealCloseTimeoutMs: 100,
  pingIntervalMs: 60000,
  turnCredentialTtlSec: 120,
  stunUrls: ["stun:stun.example.test:19302"],
  turnUrls: ["turn:turn.example.test:3478"],
  turnsUrls: [],
  turnSharedSecret: "test-secret",
  turnConfigured: true,
  connectionRateLimitMax: 100,
  roomCreateRateLimitMax: 100,
  roomJoinRateLimitMax: 100,
  iceRateLimitMax: 100,
};

async function withServer(overrides, run) {
  const app = createApp({ ...TEST_CONFIG, ...overrides });
  await app.start();
  const address = app.server.address();
  const baseUrl = `http://${address.address}:${address.port}`;
  const wsUrl = `ws://${address.address}:${address.port}${app.config.signalingPath}`;
  try {
    await run({ app, baseUrl, wsUrl });
  } finally {
    await app.stop();
  }
}

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http
      .get(url, (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          resolve({
            status: response.statusCode,
            body: Buffer.concat(chunks).toString("utf8"),
          });
        });
      })
      .on("error", reject);
  });
}

function connectClient(wsUrl, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const timer = setTimeout(() => {
      ws.terminate();
      reject(new Error(`Timed out connecting to ${wsUrl}`));
    }, timeoutMs);
    const cleanup = () => clearTimeout(timer);
    ws.once("open", () => {
      cleanup();
      ws.inbox = attachMessageQueue(ws);
      resolve(ws);
    });
    ws.once("error", (error) => {
      cleanup();
      reject(error);
    });
  });
}

function connectRejectedClient(wsUrl, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const timer = setTimeout(() => {
      ws.terminate();
      reject(new Error(`Timed out waiting for rejection from ${wsUrl}`));
    }, timeoutMs);
    const finish = (value) => {
      clearTimeout(timer);
      resolve(value);
    };
    ws.once("close", (code, reason) => {
      finish({ code, reason: reason.toString() });
    });
    ws.once("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

function attachMessageQueue(ws) {
  const queue = [];
  const waiters = [];
  ws.on("message", (data) => {
    const message = JSON.parse(data.toString());
    if (waiters.length > 0) {
      waiters.shift()(message);
    } else {
      queue.push(message);
    }
  });
  return {
    next(timeoutMs = 5000) {
      return new Promise((resolve, reject) => {
        if (queue.length > 0) {
          resolve(queue.shift());
          return;
        }
        let settled = false;
        const timer = setTimeout(() => {
          if (settled) {
            return;
          }
          settled = true;
          const waiterIndex = waiters.indexOf(onMessage);
          if (waiterIndex >= 0) {
            waiters.splice(waiterIndex, 1);
          }
          reject(new Error("Timed out waiting for message"));
        }, timeoutMs);
        const onMessage = (message) => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimeout(timer);
          resolve(message);
        };
        waiters.push(onMessage);
      });
    },
    async waitForType(type, timeoutMs = 5000) {
      while (true) {
        const message = await this.next(timeoutMs);
        if (message.type === type) {
          return message;
        }
      }
    },
  };
}

function waitForMessage(ws) {
  return ws.inbox.next();
}

async function waitForJoinMessage(ws) {
  return ws.inbox.waitForType(0);
}

function waitForClose(ws) {
  return new Promise((resolve) => {
    ws.once("close", (code, reason) => resolve({ code, reason: reason.toString() }));
  });
}

test("health and readiness endpoints respond", async () => {
  await withServer({}, async ({ baseUrl }) => {
    const health = await httpGet(`${baseUrl}/healthz`);
    assert.equal(health.status, 200);
    assert.deepEqual(JSON.parse(health.body), { status: "ok" });

    const ready = await httpGet(`${baseUrl}/readyz`);
    assert.equal(ready.status, 200);
    const readyJson = JSON.parse(ready.body);
    assert.equal(readyJson.status, "ready");
  });
});

test("readyz fails when TURN configured without secret", async () => {
  await withServer({ turnSharedSecret: "", turnConfigured: true }, async ({ baseUrl }) => {
    const ready = await httpGet(`${baseUrl}/readyz`);
    assert.equal(ready.status, 503);
    assert.equal(JSON.parse(ready.body).status, "not_ready");
  });
});

test("room creation and joining works for two peers", async () => {
  await withServer({}, async ({ wsUrl }) => {
    const host = await connectClient(wsUrl);
    const joiner = await connectClient(wsUrl);

    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    const hostJoin = await waitForJoinMessage(host);
    const roomCode = hostJoin.data;
    assert.ok(roomCode.length > 0);

    joiner.send(JSON.stringify({ type: 0, id: 1, data: roomCode }));
    await waitForMessage(joiner);
    await waitForMessage(joiner);
    await waitForMessage(host);

    host.close();
    joiner.close();
  });
});

test("room rejects fifth peer", async () => {
  await withServer({ maxPeersPerRoom: 4 }, async ({ wsUrl }) => {
    const host = await connectClient(wsUrl);
    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    const hostJoin = await waitForJoinMessage(host);
    const roomCode = hostJoin.data;

    const peers = [];
    for (let i = 0; i < 3; i += 1) {
      const peer = await connectClient(wsUrl);
      peer.send(JSON.stringify({ type: 0, id: 1, data: roomCode }));
      await waitForMessage(peer);
      await waitForMessage(peer);
      peers.push(peer);
    }

    const overflow = await connectClient(wsUrl);
    overflow.send(JSON.stringify({ type: 0, id: 1, data: roomCode }));
    const closed = await waitForClose(overflow);
    assert.match(closed.reason, /full/i);

    host.close();
    peers.forEach((peer) => peer.close());
  });
});

test("invalid room returns room not found", async () => {
  await withServer({}, async ({ wsUrl }) => {
    const client = await connectClient(wsUrl);
    client.send(JSON.stringify({ type: 0, id: 1, data: "missing-room" }));
    const closed = await waitForClose(client);
    assert.match(closed.reason, /does not exists/i);
  });
});

test("host disconnect cleans up room", async () => {
  await withServer({}, async ({ wsUrl }) => {
    const host = await connectClient(wsUrl);
    const joiner = await connectClient(wsUrl);
    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    const hostJoin = await waitForJoinMessage(host);
    joiner.send(JSON.stringify({ type: 0, id: 1, data: hostJoin.data }));
    await waitForMessage(joiner);
    await waitForMessage(joiner);

    const closePromise = waitForClose(joiner);
    host.close();
    const closed = await closePromise;
    assert.match(closed.reason, /host has disconnected/i);
  });
});

test("inactive rooms expire", async () => {
  await withServer({ roomInactivityMs: 50 }, async ({ wsUrl, app }) => {
    const host = await connectClient(wsUrl);
    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    await waitForJoinMessage(host);
    host.close();
    await new Promise((resolve) => setTimeout(resolve, 120));
    assert.equal(app.registry.lobbies.size, 0);
  });
});

test("absolute room lifetime expires", async () => {
  await withServer({ roomMaxLifetimeMs: 50, roomInactivityMs: 10000 }, async ({ wsUrl, app }) => {
    const host = await connectClient(wsUrl);
    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    await waitForJoinMessage(host);
    await new Promise((resolve) => setTimeout(resolve, 120));
    app.registry.cleanupExpiredRooms();
    assert.equal(app.registry.lobbies.size, 0);
    host.close();
  });
});

test("malformed messages are rejected", async () => {
  await withServer({}, async ({ wsUrl }) => {
    const client = await connectClient(wsUrl);
    client.send("not-json");
    const closed = await waitForClose(client);
    assert.ok(closed.code >= 4400);
  });
});

test("payload limit is enforced in bytes", async () => {
  await withServer({ maxSignalingPayloadBytes: 32 }, async ({ wsUrl }) => {
    const client = await connectClient(wsUrl);
    const oversized = JSON.stringify({ type: 0, id: 1, data: "x".repeat(40) });
    client.send(oversized);
    const closed = await waitForClose(client);
    assert.match(closed.reason, /too large/i);
  });
});

test("connection limit rejects additional peers", async () => {
  await withServer({ maxConnections: 1, connectionRateLimitMax: 100 }, async ({ wsUrl }) => {
    const first = await connectClient(wsUrl);
    const closed = await connectRejectedClient(wsUrl);
    assert.match(closed.reason, /Too many peers/i);
    first.close();
  });
});

test("room creation rate limit applies", async () => {
  await withServer(
    {
      maxRooms: 100,
      roomCreateRateLimitMax: 1,
      roomCreateRateLimitWindowMs: 60000,
      connectionRateLimitMax: 100,
    },
    async ({ wsUrl }) => {
      const first = await connectClient(wsUrl);
      first.send(JSON.stringify({ type: 0, id: 1, data: "" }));
      await waitForJoinMessage(first);

      const second = await connectClient(wsUrl);
      second.send(JSON.stringify({ type: 0, id: 1, data: "" }));
      const closed = await waitForClose(second);
      assert.match(closed.reason, /rate limited/i);
      first.close();
    },
  );
});

test("join attempt rate limit applies", async () => {
  await withServer(
    {
      roomJoinRateLimitMax: 1,
      roomJoinRateLimitWindowMs: 60000,
      connectionRateLimitMax: 100,
    },
    async ({ wsUrl }) => {
      const host = await connectClient(wsUrl);
      host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
      const hostJoin = await waitForJoinMessage(host);

      const firstJoiner = await connectClient(wsUrl);
      firstJoiner.send(JSON.stringify({ type: 0, id: 1, data: "missing-1" }));
      await waitForClose(firstJoiner);

      const secondJoiner = await connectClient(wsUrl);
      secondJoiner.send(JSON.stringify({ type: 0, id: 1, data: "missing-2" }));
      const closed = await waitForClose(secondJoiner);
      assert.match(closed.reason, /rate limited/i);
      host.close();
    },
  );
});

test("protocol version mismatch rejects websocket upgrade", async () => {
  await withServer({}, async ({ app }) => {
    const address = app.server.address();
    const badUrl = `ws://${address.address}:${address.port}${app.config.signalingPath}?protocol=99`;
    const ws = new WebSocket(badUrl);
    const status = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        ws.terminate();
        reject(new Error("Timed out waiting for protocol mismatch rejection"));
      }, 5000);
      ws.once("unexpected-response", (_request, response) => {
        clearTimeout(timer);
        resolve(response.statusCode);
      });
      ws.once("open", () => {
        clearTimeout(timer);
        reject(new Error("expected protocol mismatch rejection"));
      });
      ws.once("error", (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
    assert.equal(status, 400);
  });
});

test("graceful shutdown refuses new rooms", async () => {
  await withServer({}, async ({ wsUrl, app }) => {
    app.config.isShuttingDown = true;
    const client = await connectClient(wsUrl);
    const closed = await waitForClose(client);
    assert.match(closed.reason, /shutting down/i);
  });
});

test("ice endpoint issues coturn-compatible credentials", async () => {
  await withServer({}, async ({ baseUrl }) => {
    const response = await httpGet(`${baseUrl}/v1/ice`);
    assert.equal(response.status, 200);
    const payload = JSON.parse(response.body);
    assert.ok(Array.isArray(payload.ice_servers));
    assert.ok(payload.ice_servers.length >= 2);
    const turnEntry = payload.ice_servers.find((entry) =>
      entry.urls.some((url) => url.startsWith("turn:")),
    );
    assert.ok(turnEntry.username);
    assert.ok(turnEntry.credential);
    assert.ok(payload.expires_at > Math.floor(Date.now() / 1000));
  });
});

test("turn credential ttl is bounded", () => {
  const credentials = generateTurnCredentials("secret", 120);
  assert.ok(credentials.expires_at > Math.floor(Date.now() / 1000));
  assert.equal(credentials.ttl_sec, 120);
});

test("missing turn secret throws", () => {
  assert.throws(() => generateTurnCredentials("", 120), /TURN_SHARED_SECRET/);
});

test("ice endpoint rate limits", async () => {
  await withServer({ iceRateLimitMax: 1, iceRateLimitWindowMs: 60000 }, async ({ baseUrl }) => {
    const first = await httpGet(`${baseUrl}/v1/ice`);
    assert.equal(first.status, 200);
    const second = await httpGet(`${baseUrl}/v1/ice`);
    assert.equal(second.status, 429);
    assert.equal(JSON.parse(second.body).error, ErrorCategory.RATE_LIMITED);
  });
});

test("sealed room rejects new joins", async () => {
  await withServer({}, async ({ wsUrl }) => {
    const host = await connectClient(wsUrl);
    host.send(JSON.stringify({ type: 0, id: 1, data: "" }));
    const hostJoin = await waitForJoinMessage(host);
    const roomCode = hostJoin.data;

    host.send(JSON.stringify({ type: 7, id: 0, data: "" }));
    await waitForMessage(host);

    const joiner = await connectClient(wsUrl);
    joiner.send(JSON.stringify({ type: 0, id: 1, data: roomCode }));
    const closed = await waitForClose(joiner);
    assert.match(closed.reason, /sealed/i);
    host.close();
  });
});


test("logs do not include sdp or credential payloads", async () => {
  const { sanitizeMeta } = require("../src/logger");
  const sanitized = sanitizeMeta({
    offer: "v=0",
    candidate: "candidate:1",
    credential: "secret",
    room: "abc",
  });
  assert.equal(sanitized.offer, "[redacted]");
  assert.equal(sanitized.candidate, "[redacted]");
  assert.equal(sanitized.credential, "[redacted]");
  assert.equal(sanitized.room, "abc");
});
