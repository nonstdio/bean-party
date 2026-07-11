class_name TransportMessageLanes
extends RefCounted

## Logical message lanes from [Networking architecture](../../docs/architecture/networking.md#transport-message-lanes).
## RPC `@rpc(..., transfer_channel)` annotations use channel 0 plus lane transfer modes.
## See [WebRTC implementation notes](../../docs/guides/webrtc-implementation-notes.md).

enum Lane {
	SESSION_CONTROL,
	ENTITY_LIFECYCLE,
	PLAYER_INPUT,
	WORLD_SNAPSHOT,
	COSMETIC,
}

const LANE_NAMES := {
	Lane.SESSION_CONTROL: "session_control",
	Lane.ENTITY_LIFECYCLE: "entity_lifecycle",
	Lane.PLAYER_INPUT: "player_input",
	Lane.WORLD_SNAPSHOT: "world_snapshot",
	Lane.COSMETIC: "cosmetic",
}

## Shell/minigame `@rpc` decorators use channel 0 plus a lane-specific transfer mode.
## Godot multiplexes channel 0 into three lanes (reliable / unreliable ordered /
## unreliable). WebRTC only exposes those three data channels; non-zero RPC channels
## map to unavailable indices and fail at runtime.
const CHANNEL_RPC := 0

## ENet-only channel indices for future lane tuning. RPC annotations stay on
## CHANNEL_RPC so WebRTC and ENet share the same decorators.
const CHANNEL_SESSION_CONTROL := 0
const CHANNEL_PLAYER_INPUT := 1
const CHANNEL_WORLD_SNAPSHOT := 2
const CHANNEL_COSMETIC_ENET := 3

const ENET_CHANNEL_BY_LANE := {
	Lane.SESSION_CONTROL: CHANNEL_SESSION_CONTROL,
	Lane.ENTITY_LIFECYCLE: CHANNEL_SESSION_CONTROL,
	Lane.PLAYER_INPUT: CHANNEL_PLAYER_INPUT,
	Lane.WORLD_SNAPSHOT: CHANNEL_WORLD_SNAPSHOT,
	Lane.COSMETIC: CHANNEL_COSMETIC_ENET,
}

static func lane_name(lane: Lane) -> String:
	return String(LANE_NAMES.get(lane, "unknown"))


static func enet_channel_for_lane(lane: Lane) -> int:
	return int(ENET_CHANNEL_BY_LANE.get(lane, 0))


## WebRTC lane map: always channel 0; transfer mode selects the data channel.
const WEBRTC_CHANNEL_BY_LANE := {
	Lane.SESSION_CONTROL: CHANNEL_RPC,
	Lane.ENTITY_LIFECYCLE: CHANNEL_RPC,
	Lane.PLAYER_INPUT: CHANNEL_RPC,
	Lane.WORLD_SNAPSHOT: CHANNEL_RPC,
	Lane.COSMETIC: CHANNEL_RPC,
}


static func webrtc_channel_for_lane(lane: Lane) -> int:
	return int(WEBRTC_CHANNEL_BY_LANE.get(lane, 0))
