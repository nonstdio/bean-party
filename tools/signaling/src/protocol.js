const { ErrorCategory, ServiceError } = require("./errors");

const CMD = {
  JOIN: 0,
  ID: 1,
  PEER_CONNECT: 2,
  PEER_DISCONNECT: 3,
  OFFER: 4,
  ANSWER: 5,
  CANDIDATE: 6,
  SEAL: 7,
};

function protoMessage(type, id, data) {
  return JSON.stringify({
    type,
    id,
    data: data || "",
  });
}

function messageToString(message) {
  if (typeof message === "string") {
    return message;
  }
  if (Buffer.isBuffer(message)) {
    return message.toString("utf8");
  }
  if (ArrayBuffer.isView(message)) {
    return Buffer.from(message.buffer, message.byteOffset, message.byteLength).toString("utf8");
  }
  return null;
}

function parseMessage(text, config) {
  if (Buffer.byteLength(text, "utf8") > config.maxSignalingPayloadBytes) {
    throw new ServiceError(ErrorCategory.PAYLOAD_TOO_LARGE, "Signaling payload too large");
  }

  let json = null;
  try {
    json = JSON.parse(text);
  } catch (error) {
    throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid message format");
  }

  const type = typeof json.type === "number" ? Math.floor(json.type) : -1;
  const id = typeof json.id === "number" ? Math.floor(json.id) : -1;
  const data = typeof json.data === "string" ? json.data : "";
  if (Buffer.byteLength(data, "utf8") > config.maxSignalingPayloadBytes) {
    throw new ServiceError(ErrorCategory.PAYLOAD_TOO_LARGE, "Signaling payload too large");
  }
  if (type < 0 || id < 0) {
    throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid message format");
  }

  return { type, id, data };
}

module.exports = {
  CMD,
  protoMessage,
  messageToString,
  parseMessage,
};
