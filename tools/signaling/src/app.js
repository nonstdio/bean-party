const http = require("http");
const { WebSocketServer } = require("ws");
const { loadConfig } = require("./config");
const { ErrorCategory, ServiceError } = require("./errors");
const logger = require("./logger");
const { LobbyRegistry } = require("./lobby");
const { RateLimiter } = require("./rateLimiter");
const { messageToString, parseMessage } = require("./protocol");
const { generateTurnCredentials, buildIceServers } = require("./turn");

function clientKeyFromRequest(request, config) {
  if (config.trustProxy) {
    const forwarded = request.headers["x-forwarded-for"];
    if (typeof forwarded === "string" && forwarded.trim() !== "") {
      return forwarded.split(",")[0].trim();
    }
  }
  return request.socket.remoteAddress || "unknown";
}

function readRequestBody(request, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    request.on("data", (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(new ServiceError(ErrorCategory.PAYLOAD_TOO_LARGE, "HTTP body too large"));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

function createApp(configOverrides = {}) {
  const config = { ...loadConfig(), ...configOverrides };
  const rateLimiters = {
    connections: new RateLimiter(
      config.connectionRateLimitWindowMs,
      config.connectionRateLimitMax,
    ),
    roomCreate: new RateLimiter(
      config.roomCreateRateLimitWindowMs,
      config.roomCreateRateLimitMax,
    ),
    roomJoin: new RateLimiter(config.roomJoinRateLimitWindowMs, config.roomJoinRateLimitMax),
    ice: new RateLimiter(config.iceRateLimitWindowMs, config.iceRateLimitMax),
  };
  const registry = new LobbyRegistry(config, rateLimiters);
  let pingTimer = null;
  let wss = null;

  function isReady() {
    if (config.isShuttingDown) {
      return false;
    }
    if (config.turnConfigured && !config.turnSharedSecret) {
      return false;
    }
    return true;
  }

  function buildIceResponse() {
    if (config.turnConfigured && !config.turnSharedSecret) {
      throw new ServiceError(
        ErrorCategory.INTERNAL_FAILURE,
        "TURN is configured without TURN_SHARED_SECRET",
      );
    }
    const credentials = config.turnConfigured
      ? generateTurnCredentials(config.turnSharedSecret, config.turnCredentialTtlSec)
      : null;
    const iceServers = credentials
      ? buildIceServers(config, credentials)
      : config.stunUrls.length > 0
        ? [{ urls: [...config.stunUrls] }]
        : [{ urls: ["stun:stun.l.google.com:19302"] }];
    return {
      protocol_version: config.protocolVersion,
      ice_servers: iceServers,
      expires_at: credentials ? credentials.expires_at : null,
    };
  }

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
    const clientKey = clientKeyFromRequest(request, config);

    try {
      if (request.method === "GET" && url.pathname === "/healthz") {
        response.writeHead(200, { "content-type": "application/json" });
        response.end(JSON.stringify({ status: "ok" }));
        return;
      }

      if (request.method === "GET" && url.pathname === "/readyz") {
        const ready = isReady();
        response.writeHead(ready ? 200 : 503, { "content-type": "application/json" });
        response.end(
          JSON.stringify({
            status: ready ? "ready" : "not_ready",
            ...registry.getStats(),
          }),
        );
        return;
      }

      if (request.method === "GET" && url.pathname === config.icePath) {
        if (!rateLimiters.ice.allow(clientKey)) {
          response.writeHead(429, { "content-type": "application/json" });
          response.end(
            JSON.stringify({
              error: ErrorCategory.RATE_LIMITED,
              message: "ICE credential rate limited",
            }),
          );
          return;
        }
        const payload = buildIceResponse();
        const body = JSON.stringify(payload);
        if (Buffer.byteLength(body, "utf8") > config.maxHttpBodyBytes) {
          throw new ServiceError(ErrorCategory.INTERNAL_FAILURE, "ICE response too large");
        }
        response.writeHead(200, { "content-type": "application/json" });
        response.end(body);
        return;
      }

      response.writeHead(404, { "content-type": "application/json" });
      response.end(JSON.stringify({ error: ErrorCategory.INVALID_REQUEST, message: "Not found" }));
    } catch (error) {
      const category = error.category || ErrorCategory.INTERNAL_FAILURE;
      const status = category === ErrorCategory.PAYLOAD_TOO_LARGE ? 413 : 500;
      logger.error("http_request_failed", { category, path: url.pathname });
      response.writeHead(status, { "content-type": "application/json" });
      response.end(JSON.stringify({ error: category, message: error.message }));
    }
  });

  wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (request, socket, head) => {
    const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
    const clientKey = clientKeyFromRequest(request, config);
    const protocolVersion = url.searchParams.get("protocol") || url.searchParams.get("v");

    if (url.pathname !== config.signalingPath) {
      socket.write("HTTP/1.1 404 Not Found\r\n\r\n");
      socket.destroy();
      return;
    }

    if (protocolVersion && protocolVersion !== config.protocolVersion) {
      socket.write("HTTP/1.1 400 Bad Request\r\n\r\n");
      socket.destroy();
      return;
    }

    if (!rateLimiters.connections.allow(clientKey)) {
      socket.write("HTTP/1.1 429 Too Many Requests\r\n\r\n");
      socket.destroy();
      return;
    }

    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request, clientKey);
    });
  });

  wss.on("connection", (ws, request, clientKey) => {
    const peer = registry.onPeerConnected(ws);
    if (!peer) {
      return;
    }

    logger.info("signaling_peer_connected", {
      clientKey,
      ...registry.getStats(),
    });

    ws.on("message", (message) => {
      const text = messageToString(message);
      if (text === null) {
        ws.close(
          new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid transfer mode, must be text")
            .closeCode,
          "Invalid transfer mode, must be text",
        );
        return;
      }
      try {
        const parsed = parseMessage(text, config);
        registry.handleMessage(peer, parsed, clientKey);
      } catch (error) {
        const category = error.category || ErrorCategory.INVALID_REQUEST;
        const closeCode = error.closeCode || 4400;
        logger.warn("signaling_message_rejected", { category });
        ws.close(closeCode, error.message);
      }
    });

    ws.on("close", () => {
      registry.onPeerDisconnected(peer);
      logger.info("signaling_peer_disconnected", registry.getStats());
    });

    ws.on("error", (error) => {
      logger.error("signaling_socket_error", { message: error.message });
    });
  });

  function start() {
    return new Promise((resolve) => {
      server.listen(config.port, config.host, () => {
        pingTimer = setInterval(() => {
          wss.clients.forEach((ws) => {
            ws.ping();
          });
        }, config.pingIntervalMs);
        logger.info("signaling_server_started", {
          host: config.host,
          port: config.port,
          signalingPath: config.signalingPath,
          icePath: config.icePath,
          protocolVersion: config.protocolVersion,
        });
        resolve({ server, wss, config, registry, rateLimiters });
      });
    });
  }

  async function stop() {
    config.isShuttingDown = true;
    if (pingTimer) {
      clearInterval(pingTimer);
      pingTimer = null;
    }
    registry.stop();
    await new Promise((resolve) => wss.close(resolve));
    await new Promise((resolve) => server.close(resolve));
    logger.info("signaling_server_stopped");
  }

  return {
    config,
    server,
    wss,
    registry,
    rateLimiters,
    start,
    stop,
    isReady,
    buildIceResponse,
    clientKeyFromRequest,
    readRequestBody,
  };
}

module.exports = {
  createApp,
};
