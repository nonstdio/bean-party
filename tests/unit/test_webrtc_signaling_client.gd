extends GutTest


func test_parse_message_accepts_join_and_peer_connect() -> void:
	var client := WebRtcSignalingClient.new()
	var seen := {"id": -1, "mesh": false, "lobby": "", "peer_id": -1}
	client.connected_to_signaling.connect(
		func(assigned_id: int, use_mesh: bool) -> void:
			seen.id = assigned_id
			seen.mesh = use_mesh
	)
	client.lobby_joined.connect(func(code: String) -> void: seen.lobby = code)
	client.peer_connected.connect(func(remote_peer_id: int) -> void: seen.peer_id = remote_peer_id)

	assert_true(client.parse_message('{"type":1,"id":2,"data":"false"}'))
	assert_eq(seen.id, 2)
	assert_false(seen.mesh)

	assert_true(client.parse_message('{"type":0,"id":0,"data":"room-abc"}'))
	assert_eq(seen.lobby, "room-abc")

	assert_true(client.parse_message('{"type":2,"id":3,"data":""}'))
	assert_eq(seen.peer_id, 3)


func test_parse_message_parses_candidate_payload() -> void:
	var client := WebRtcSignalingClient.new()
	var seen := {"peer_id": -1, "mid": "", "index": -1, "sdp": ""}
	client.candidate_received.connect(
		func(remote_peer_id: int, mid: String, index: int, sdp: String) -> void:
			seen.peer_id = remote_peer_id
			seen.mid = mid
			seen.index = index
			seen.sdp = sdp
	)
	var payload := (
		JSON
		. stringify(
			{
				"type": WebRtcSignalingMessages.Message.CANDIDATE,
				"id": 2,
				"data": "\naudio\n0\ncandidate:1",
			}
		)
	)
	assert_true(client.parse_message(payload))
	assert_eq(seen.peer_id, 2)
	assert_eq(seen.mid, "audio")
	assert_eq(seen.index, 0)
	assert_eq(seen.sdp, "candidate:1")


func test_parse_message_rejects_invalid_payload() -> void:
	var client := WebRtcSignalingClient.new()
	assert_false(client.parse_message("not-json"))
	assert_false(client.parse_message('{"type":6,"id":2,"data":"bad"}'))
	assert_false(client.parse_message('{"type":99,"id":1,"data":""}'))
