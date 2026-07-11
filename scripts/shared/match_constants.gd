class_name MatchConstants

const MAX_PLAYERS := 4
## Total network peers in a session, including the listen-server host.
const MAX_PEERS := 4
## ENet `create_server` client slots; the host is not counted as a remote client.
const MAX_REMOTE_NETWORK_CLIENTS := MAX_PEERS - 1
const OFFLINE_PEER_ID := 1
const DEFAULT_ENET_PORT := 7777

const SLOT_COLORS: Array[Color] = [
	Color(0.917647, 0.423529, 0.176471),
	Color(0.278431, 0.784314, 0.486275),
	Color(0.423529, 0.65098, 0.917647),
	Color(0.847059, 0.34902, 0.454902),
]
