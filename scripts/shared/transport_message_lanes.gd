class_name TransportMessageLanes
extends RefCounted

## Logical message lanes from [Networking architecture](../../docs/architecture/networking.md#transport-message-lanes).
## RPC `@rpc(..., transfer_channel)` annotations use the channel constants below.

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

## Transfer channels referenced by shell/minigame `@rpc` decorators.
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


## WebRTC data-channel map (3 channels per peer).
const WEBRTC_CHANNEL_BY_LANE := {
	Lane.SESSION_CONTROL: CHANNEL_SESSION_CONTROL,
	Lane.ENTITY_LIFECYCLE: CHANNEL_SESSION_CONTROL,
	Lane.PLAYER_INPUT: CHANNEL_PLAYER_INPUT,
	Lane.WORLD_SNAPSHOT: CHANNEL_WORLD_SNAPSHOT,
	Lane.COSMETIC: CHANNEL_WORLD_SNAPSHOT,
}


static func webrtc_channel_for_lane(lane: Lane) -> int:
	return int(WEBRTC_CHANNEL_BY_LANE.get(lane, 0))
