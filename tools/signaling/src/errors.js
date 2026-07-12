const ErrorCategory = {
  INCOMPATIBLE_PROTOCOL: "incompatible_protocol",
  INVALID_REQUEST: "invalid_request",
  ROOM_NOT_FOUND: "room_not_found",
  ROOM_FULL: "room_full",
  ROOM_SEALED: "room_sealed",
  RATE_LIMITED: "rate_limited",
  SERVICE_SHUTTING_DOWN: "service_shutting_down",
  HOST_DISCONNECTED: "host_disconnected",
  PAYLOAD_TOO_LARGE: "payload_too_large",
  INTERNAL_FAILURE: "internal_failure",
};

const CLOSE_CODES = {
  [ErrorCategory.INCOMPATIBLE_PROTOCOL]: 4401,
  [ErrorCategory.INVALID_REQUEST]: 4400,
  [ErrorCategory.ROOM_NOT_FOUND]: 4404,
  [ErrorCategory.ROOM_FULL]: 4409,
  [ErrorCategory.ROOM_SEALED]: 4410,
  [ErrorCategory.RATE_LIMITED]: 4429,
  [ErrorCategory.SERVICE_SHUTTING_DOWN]: 4413,
  [ErrorCategory.HOST_DISCONNECTED]: 4400,
  [ErrorCategory.PAYLOAD_TOO_LARGE]: 4413,
  [ErrorCategory.INTERNAL_FAILURE]: 4500,
};

class ServiceError extends Error {
  constructor(category, message) {
    super(message);
    this.category = category;
    this.closeCode = CLOSE_CODES[category] || 4500;
  }
}

module.exports = {
  ErrorCategory,
  CLOSE_CODES,
  ServiceError,
};
