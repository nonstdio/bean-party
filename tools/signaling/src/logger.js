const SENSITIVE_PATTERNS = [
  /candidate[:=]/i,
  /"type"\s*:\s*[456]/,
  /\boffer\b/i,
  /\banswer\b/i,
  /credential/i,
  /username/i,
  /secret/i,
  /sdp/i,
];

function shouldRedact(value) {
  const text = String(value);
  return SENSITIVE_PATTERNS.some((pattern) => pattern.test(text));
}

function sanitizeMeta(meta) {
  if (!meta || typeof meta !== "object") {
    return meta;
  }
  const sanitized = {};
  for (const [key, value] of Object.entries(meta)) {
    if (shouldRedact(key) || shouldRedact(value)) {
      sanitized[key] = "[redacted]";
      continue;
    }
    if (value && typeof value === "object") {
      sanitized[key] = sanitizeMeta(value);
      continue;
    }
    sanitized[key] = value;
  }
  return sanitized;
}

function log(level, message, meta) {
  const entry = {
    ts: new Date().toISOString(),
    level,
    message,
    ...(meta ? { meta: sanitizeMeta(meta) } : {}),
  };
  const line = JSON.stringify(entry);
  if (level === "error") {
    console.error(line);
    return;
  }
  if (level === "warn") {
    console.warn(line);
    return;
  }
  console.log(line);
}

module.exports = {
  debug: (message, meta) => log("debug", message, meta),
  info: (message, meta) => log("info", message, meta),
  warn: (message, meta) => log("warn", message, meta),
  error: (message, meta) => log("error", message, meta),
  sanitizeMeta,
};
