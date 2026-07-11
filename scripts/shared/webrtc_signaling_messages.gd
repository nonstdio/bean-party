class_name WebRtcSignalingMessages
extends RefCounted

## JSON signaling protocol from Godot's webrtc_signaling demo.

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
}
