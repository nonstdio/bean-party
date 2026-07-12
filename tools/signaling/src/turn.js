const crypto = require("crypto");

function generateTurnCredentials(sharedSecret, ttlSeconds, usernameSuffix = "bean-party") {
  if (!sharedSecret) {
    throw new Error("TURN_SHARED_SECRET is required when TURN URLs are configured.");
  }
  if (!Number.isFinite(ttlSeconds) || ttlSeconds <= 0) {
    throw new Error("TURN credential TTL must be positive.");
  }

  const expiresAt = Math.floor(Date.now() / 1000) + ttlSeconds;
  const username = `${expiresAt}:${usernameSuffix}`;
  const credential = crypto.createHmac("sha1", sharedSecret).update(username).digest("base64");
  return {
    username,
    credential,
    expires_at: expiresAt,
    ttl_sec: ttlSeconds,
  };
}

function buildIceServers(config, credentials) {
  const servers = [];
  if (config.stunUrls.length > 0) {
    servers.push({ urls: [...config.stunUrls] });
  }
  const relayUrls = [...config.turnUrls, ...config.turnsUrls];
  if (relayUrls.length > 0) {
    servers.push({
      urls: relayUrls,
      username: credentials.username,
      credential: credentials.credential,
    });
  }
  return servers;
}

module.exports = {
  generateTurnCredentials,
  buildIceServers,
};
