const crypto = require("crypto");
const { ErrorCategory, ServiceError } = require("./errors");
const { CMD, protoMessage } = require("./protocol");

const ALFNUM = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

function randomInt(low, high) {
  return crypto.randomInt(low, high + 1);
}

function randomId() {
  return crypto.randomInt(1, 0x7fffffff);
}

function randomRoomCode() {
  let out = "";
  for (let i = 0; i < 16; i += 1) {
    out += ALFNUM[randomInt(0, ALFNUM.length - 1)];
  }
  return out;
}

function normalizeRoomCode(code) {
  return String(code || "").trim();
}

class Peer {
  constructor(id, ws, config, registry) {
    this.id = id;
    this.ws = ws;
    this.lobby = "";
    this.registry = registry;
    this.timeout = setTimeout(() => {
      if (!this.lobby) {
        ws.close(
          new ServiceError(ErrorCategory.INVALID_REQUEST, "Have not joined lobby yet").closeCode,
          "Have not joined lobby yet",
        );
      }
    }, config.noLobbyTimeoutMs);
  }

  clearTimeout() {
    if (this.timeout >= 0) {
      clearTimeout(this.timeout);
      this.timeout = -1;
    }
  }
}

class Lobby {
  constructor(name, host, mesh, config) {
    this.name = name;
    this.host = host;
    this.mesh = mesh;
    this.peers = [];
    this.sealed = false;
    this.closeTimer = -1;
    this.createdAt = Date.now();
    this.lastActivityAt = Date.now();
    this.config = config;
  }

  touch() {
    this.lastActivityAt = Date.now();
  }

  getPeerId(peer) {
    if (this.host === peer.id) {
      return 1;
    }
    return peer.id;
  }

  join(peer) {
    this.touch();
    const assigned = this.getPeerId(peer);
    peer.ws.send(protoMessage(CMD.ID, assigned, this.mesh ? "true" : ""));
    this.peers.forEach((existing) => {
      existing.ws.send(protoMessage(CMD.PEER_CONNECT, assigned));
      peer.ws.send(protoMessage(CMD.PEER_CONNECT, this.getPeerId(existing)));
    });
    this.peers.push(peer);
  }

  leave(peer) {
    const idx = this.peers.findIndex((entry) => peer === entry);
    if (idx === -1) {
      return false;
    }
    const assigned = this.getPeerId(peer);
    const hostLeft = assigned === 1;
    this.peers.forEach((existing) => {
      if (hostLeft) {
        existing.ws.close(
          new ServiceError(ErrorCategory.HOST_DISCONNECTED, "Room host has disconnected").closeCode,
          "Room host has disconnected",
        );
      } else {
        existing.ws.send(protoMessage(CMD.PEER_DISCONNECT, assigned));
      }
    });
    this.peers.splice(idx, 1);
    if (hostLeft && this.closeTimer >= 0) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
    return hostLeft;
  }

  seal(peer) {
    if (peer.id !== this.host) {
      throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Only host can seal the lobby");
    }
    this.sealed = true;
    this.touch();
    this.peers.forEach((existing) => {
      existing.ws.send(protoMessage(CMD.SEAL, 0));
    });
    this.closeTimer = setTimeout(() => {
      this.peers.forEach((existing) => {
        existing.ws.close(1000, "Seal complete");
      });
    }, this.config.sealCloseTimeoutMs);
  }
}

class LobbyRegistry {
  constructor(config, rateLimiters) {
    this.config = config;
    this.rateLimiters = rateLimiters;
    this.lobbies = new Map();
    this.peersCount = 0;
    this.cleanupTimer = setInterval(() => this.cleanupExpiredRooms(), 1000);
  }

  getStats() {
    return {
      activeConnections: this.peersCount,
      activeRooms: this.lobbies.size,
    };
  }

  stop() {
    if (this.cleanupTimer >= 0) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = -1;
    }
    for (const lobby of this.lobbies.values()) {
      if (lobby.closeTimer >= 0) {
        clearTimeout(lobby.closeTimer);
      }
      lobby.peers.forEach((peer) => {
        peer.clearTimeout();
        peer.ws.close(
          new ServiceError(ErrorCategory.SERVICE_SHUTTING_DOWN, "Service shutting down").closeCode,
          "Service shutting down",
        );
      });
    }
    this.lobbies.clear();
  }

  cleanupExpiredRooms() {
    const now = Date.now();
    for (const [name, lobby] of this.lobbies.entries()) {
      const inactiveFor = now - lobby.lastActivityAt;
      const age = now - lobby.createdAt;
      if (inactiveFor >= this.config.roomInactivityMs || age >= this.config.roomMaxLifetimeMs) {
        lobby.peers.forEach((peer) => {
          peer.clearTimeout();
          peer.ws.close(1000, "Room expired");
        });
        if (lobby.closeTimer >= 0) {
          clearTimeout(lobby.closeTimer);
        }
        this.lobbies.delete(name);
      }
    }
  }

  onPeerConnected(ws) {
    if (this.config.isShuttingDown) {
      ws.close(
        new ServiceError(ErrorCategory.SERVICE_SHUTTING_DOWN, "Service shutting down").closeCode,
        "Service shutting down",
      );
      return null;
    }
    if (this.peersCount >= this.config.maxConnections) {
      ws.close(
        new ServiceError(ErrorCategory.ROOM_FULL, "Too many peers connected").closeCode,
        "Too many peers connected",
      );
      return null;
    }
    this.peersCount += 1;
    return new Peer(randomId(), ws, this.config, this);
  }

  onPeerDisconnected(peer) {
    this.peersCount = Math.max(0, this.peersCount - 1);
    peer.clearTimeout();
    if (peer.lobby && this.lobbies.has(peer.lobby)) {
      const lobby = this.lobbies.get(peer.lobby);
      if (lobby.leave(peer)) {
        this.lobbies.delete(peer.lobby);
      }
      peer.lobby = "";
    }
  }

  joinLobby(peer, requestedLobby, mesh, clientKey) {
    if (this.config.isShuttingDown) {
      throw new ServiceError(ErrorCategory.SERVICE_SHUTTING_DOWN, "Service shutting down");
    }
    if (peer.lobby !== "") {
      throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Already in a lobby");
    }

    let lobbyName = normalizeRoomCode(requestedLobby);
    if (lobbyName === "") {
      if (!this.rateLimiters.roomCreate.allow(clientKey)) {
        throw new ServiceError(ErrorCategory.RATE_LIMITED, "Room creation rate limited");
      }
      if (this.lobbies.size >= this.config.maxRooms) {
        throw new ServiceError(ErrorCategory.ROOM_FULL, "Too many lobbies open");
      }
      for (let attempt = 0; attempt < 8; attempt += 1) {
        lobbyName = randomRoomCode();
        if (!this.lobbies.has(lobbyName)) {
          break;
        }
        if (attempt === 7) {
          throw new ServiceError(ErrorCategory.INTERNAL_FAILURE, "Failed to allocate room code");
        }
      }
      this.lobbies.set(lobbyName, new Lobby(lobbyName, peer.id, mesh, this.config));
    } else if (!this.rateLimiters.roomJoin.allow(clientKey)) {
      throw new ServiceError(ErrorCategory.RATE_LIMITED, "Room join rate limited");
    }

    const lobby = this.lobbies.get(lobbyName);
    if (!lobby) {
      throw new ServiceError(ErrorCategory.ROOM_NOT_FOUND, "Lobby does not exists");
    }
    if (lobby.sealed) {
      throw new ServiceError(ErrorCategory.ROOM_SEALED, "Lobby is sealed");
    }
    if (lobby.peers.length >= this.config.maxPeersPerRoom) {
      throw new ServiceError(ErrorCategory.ROOM_FULL, "Lobby is full");
    }

    peer.lobby = lobbyName;
    lobby.join(peer);
    peer.ws.send(protoMessage(CMD.JOIN, 0, lobbyName));
  }

  handleMessage(peer, message, clientKey) {
    const { type, id, data } = message;
    if (type === CMD.JOIN) {
      this.joinLobby(peer, data, id === 0, clientKey);
      return;
    }
    if (!peer.lobby) {
      throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid message when not in a lobby");
    }
    const lobby = this.lobbies.get(peer.lobby);
    if (!lobby) {
      throw new ServiceError(ErrorCategory.INTERNAL_FAILURE, "Server error, lobby not found");
    }
    lobby.touch();

    if (type === CMD.SEAL) {
      lobby.seal(peer);
      return;
    }

    if (type === CMD.OFFER || type === CMD.ANSWER || type === CMD.CANDIDATE) {
      let destId = id;
      if (id === 1) {
        destId = lobby.host;
      }
      const dest = lobby.peers.find((entry) => entry.id === destId);
      if (!dest) {
        throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid destination");
      }
      dest.ws.send(protoMessage(type, lobby.getPeerId(peer), data));
      return;
    }

    throw new ServiceError(ErrorCategory.INVALID_REQUEST, "Invalid command");
  }
}

module.exports = {
  Peer,
  Lobby,
  LobbyRegistry,
  normalizeRoomCode,
};
