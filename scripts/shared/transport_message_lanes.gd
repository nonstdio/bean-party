class_name TransportMessageLanes
extends RefCounted

## Logical message lanes from [Networking architecture](../../docs/architecture/networking.md#transport-message-lanes).
## ENet channel assignments are spike assumptions until RPCs are explicitly mapped.

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

## Proposed ENet channel map. Current RPCs still default to channel 0.
const ENET_CHANNEL_BY_LANE := {
	Lane.SESSION_CONTROL: 0,
	Lane.ENTITY_LIFECYCLE: 0,
	Lane.PLAYER_INPUT: 1,
	Lane.WORLD_SNAPSHOT: 2,
	Lane.COSMETIC: 3,
}

static func lane_name(lane: Lane) -> String:
	return String(LANE_NAMES.get(lane, "unknown"))


static func enet_channel_for_lane(lane: Lane) -> int:
	return int(ENET_CHANNEL_BY_LANE.get(lane, 0))


## Proposed WebRTC data-channel map (3 channels per peer).
const WEBRTC_CHANNEL_BY_LANE := {
	Lane.SESSION_CONTROL: 0,
	Lane.ENTITY_LIFECYCLE: 0,
	Lane.PLAYER_INPUT: 1,
	Lane.WORLD_SNAPSHOT: 2,
	Lane.COSMETIC: 2,
}


static func webrtc_channel_for_lane(lane: Lane) -> int:
	return int(WEBRTC_CHANNEL_BY_LANE.get(lane, 0))
