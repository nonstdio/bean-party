class_name MatchConstants

const _STANDARD_VISUALS = preload("res://scripts/shared/presentation/standard_visuals.gd")

const MAX_PLAYERS := 4
## Total network peers in a session, including the listen-server host.
const MAX_PEERS := 4
## ENet `create_server` client slots; the host is not counted as a remote client.
const MAX_REMOTE_NETWORK_CLIENTS := MAX_PEERS - 1
const OFFLINE_PEER_ID := 1
const DEFAULT_ENET_PORT := 7777
const DEFAULT_WEBRTC_SIGNALING_URL := "ws://127.0.0.1:9080"

const SLOT_COLORS: Array[Color] = _STANDARD_VISUALS.IDENTITY_COLORS
