const DEFAULTS = {
  HOST: "127.0.0.1",
  PORT: 9080,
  SIGNALING_PATH: "/v1/signal",
  ICE_PATH: "/v1/ice",
  PROTOCOL_VERSION: "1",
  MAX_CONNECTIONS: 4096,
  MAX_ROOMS: 1024,
  MAX_PEERS_PER_ROOM: 4,
  MAX_SIGNALING_PAYLOAD_BYTES: 65536,
  MAX_HTTP_BODY_BYTES: 16384,
  ROOM_INACTIVITY_MS: 30 * 60 * 1000,
  ROOM_MAX_LIFETIME_MS: 4 * 60 * 60 * 1000,
  NO_LOBBY_TIMEOUT_MS: 1000,
  SEAL_CLOSE_TIMEOUT_MS: 10000,
  PING_INTERVAL_MS: 10000,
  TURN_CREDENTIAL_TTL_SEC: 3600,
  TURN_CREDENTIAL_MAX_TTL_SEC: 86400,
  ICE_RATE_LIMIT_WINDOW_MS: 60 * 1000,
  ICE_RATE_LIMIT_MAX: 30,
  CONNECTION_RATE_LIMIT_WINDOW_MS: 60 * 1000,
  CONNECTION_RATE_LIMIT_MAX: 120,
  ROOM_CREATE_RATE_LIMIT_WINDOW_MS: 60 * 1000,
  ROOM_CREATE_RATE_LIMIT_MAX: 30,
  ROOM_JOIN_RATE_LIMIT_WINDOW_MS: 60 * 1000,
  ROOM_JOIN_RATE_LIMIT_MAX: 60,
  TRUST_PROXY: false,
  LOG_LEVEL: "info",
};

function parseBoolean(value, fallback) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes";
}

function parseInteger(value, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, parsed));
}

function parseUrlList(value) {
  if (!value || String(value).trim() === "") {
    return [];
  }
  return String(value)
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry !== "");
}

function loadConfig(env = process.env) {
  const hosted = env.RAILWAY_ENVIRONMENT !== undefined || env.PORT !== undefined;
  const host = env.HOST || (hosted ? "0.0.0.0" : DEFAULTS.HOST);
  const port = parseInteger(env.PORT, DEFAULTS.PORT, { min: 1, max: 65535 });
  const turnSharedSecret = String(env.TURN_SHARED_SECRET || "").trim();
  const stunUrls = parseUrlList(env.STUN_URLS);
  const turnUrls = parseUrlList(env.TURN_URLS);
  const turnsUrls = parseUrlList(env.TURNS_URLS);

  return {
    host,
    port,
    signalingPath: env.SIGNALING_PATH || DEFAULTS.SIGNALING_PATH,
    icePath: env.ICE_PATH || DEFAULTS.ICE_PATH,
    protocolVersion: String(env.SIGNALING_PROTOCOL_VERSION || DEFAULTS.PROTOCOL_VERSION),
    maxConnections: parseInteger(env.MAX_CONNECTIONS, DEFAULTS.MAX_CONNECTIONS, { min: 1 }),
    maxRooms: parseInteger(env.MAX_ROOMS, DEFAULTS.MAX_ROOMS, { min: 1 }),
    maxPeersPerRoom: parseInteger(env.MAX_PEERS_PER_ROOM, DEFAULTS.MAX_PEERS_PER_ROOM, {
      min: 1,
      max: 4,
    }),
    maxSignalingPayloadBytes: parseInteger(
      env.MAX_SIGNALING_PAYLOAD_BYTES,
      DEFAULTS.MAX_SIGNALING_PAYLOAD_BYTES,
      { min: 1024 },
    ),
    maxHttpBodyBytes: parseInteger(env.MAX_HTTP_BODY_BYTES, DEFAULTS.MAX_HTTP_BODY_BYTES, {
      min: 1024,
    }),
    roomInactivityMs: parseInteger(env.ROOM_INACTIVITY_MS, DEFAULTS.ROOM_INACTIVITY_MS, {
      min: 1000,
    }),
    roomMaxLifetimeMs: parseInteger(env.ROOM_MAX_LIFETIME_MS, DEFAULTS.ROOM_MAX_LIFETIME_MS, {
      min: 1000,
    }),
    noLobbyTimeoutMs: parseInteger(env.NO_LOBBY_TIMEOUT_MS, DEFAULTS.NO_LOBBY_TIMEOUT_MS, {
      min: 100,
    }),
    sealCloseTimeoutMs: parseInteger(env.SEAL_CLOSE_TIMEOUT_MS, DEFAULTS.SEAL_CLOSE_TIMEOUT_MS, {
      min: 100,
    }),
    pingIntervalMs: parseInteger(env.PING_INTERVAL_MS, DEFAULTS.PING_INTERVAL_MS, { min: 1000 }),
    turnCredentialTtlSec: parseInteger(env.TURN_CREDENTIAL_TTL_SEC, DEFAULTS.TURN_CREDENTIAL_TTL_SEC, {
      min: 60,
      max: parseInteger(
        env.TURN_CREDENTIAL_MAX_TTL_SEC,
        DEFAULTS.TURN_CREDENTIAL_MAX_TTL_SEC,
        { min: 60 },
      ),
    }),
    turnCredentialMaxTtlSec: parseInteger(
      env.TURN_CREDENTIAL_MAX_TTL_SEC,
      DEFAULTS.TURN_CREDENTIAL_MAX_TTL_SEC,
      { min: 60 },
    ),
    stunUrls,
    turnUrls,
    turnsUrls,
    turnSharedSecret,
    turnConfigured: turnUrls.length > 0 || turnsUrls.length > 0,
    iceRateLimitWindowMs: parseInteger(
      env.ICE_RATE_LIMIT_WINDOW_MS,
      DEFAULTS.ICE_RATE_LIMIT_WINDOW_MS,
      { min: 1000 },
    ),
    iceRateLimitMax: parseInteger(env.ICE_RATE_LIMIT_MAX, DEFAULTS.ICE_RATE_LIMIT_MAX, { min: 1 }),
    connectionRateLimitWindowMs: parseInteger(
      env.CONNECTION_RATE_LIMIT_WINDOW_MS,
      DEFAULTS.CONNECTION_RATE_LIMIT_WINDOW_MS,
      { min: 1000 },
    ),
    connectionRateLimitMax: parseInteger(
      env.CONNECTION_RATE_LIMIT_MAX,
      DEFAULTS.CONNECTION_RATE_LIMIT_MAX,
      { min: 1 },
    ),
    roomCreateRateLimitWindowMs: parseInteger(
      env.ROOM_CREATE_RATE_LIMIT_WINDOW_MS,
      DEFAULTS.ROOM_CREATE_RATE_LIMIT_WINDOW_MS,
      { min: 1000 },
    ),
    roomCreateRateLimitMax: parseInteger(
      env.ROOM_CREATE_RATE_LIMIT_MAX,
      DEFAULTS.ROOM_CREATE_RATE_LIMIT_MAX,
      { min: 1 },
    ),
    roomJoinRateLimitWindowMs: parseInteger(
      env.ROOM_JOIN_RATE_LIMIT_WINDOW_MS,
      DEFAULTS.ROOM_JOIN_RATE_LIMIT_WINDOW_MS,
      { min: 1000 },
    ),
    roomJoinRateLimitMax: parseInteger(
      env.ROOM_JOIN_RATE_LIMIT_MAX,
      DEFAULTS.ROOM_JOIN_RATE_LIMIT_MAX,
      { min: 1 },
    ),
    trustProxy: parseBoolean(env.TRUST_PROXY, DEFAULTS.TRUST_PROXY),
    logLevel: String(env.LOG_LEVEL || DEFAULTS.LOG_LEVEL).toLowerCase(),
    isShuttingDown: false,
  };
}

module.exports = {
  DEFAULTS,
  loadConfig,
};
