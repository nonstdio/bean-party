class_name WebRtcSignalingClient
extends RefCounted

signal connected_to_signaling(assigned_id: int, use_mesh: bool)
signal disconnected_from_signaling(code: int, reason: String)
signal lobby_joined(lobby_code: String)
signal lobby_sealed
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal offer_received(peer_id: int, offer: String)
signal answer_received(peer_id: int, answer: String)
signal candidate_received(peer_id: int, mid: String, index: int, sdp: String)

var lobby_code: String = ""
var use_mesh: bool = false

var _ws := WebSocketPeer.new()
var _old_state := WebSocketPeer.STATE_CLOSED
var _auto_join_pending: bool = false


func connect_to_url(url: String) -> void:
	close()
	_auto_join_pending = true
	_ws.connect_to_url(url)


func close() -> void:
	_ws.close()
	_old_state = WebSocketPeer.STATE_CLOSED
	_auto_join_pending = false


func parse_message(raw_message: String) -> bool:
	return _parse_message(raw_message)


func poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state != _old_state and state == WebSocketPeer.STATE_OPEN and _auto_join_pending:
		join_lobby(lobby_code)
		_auto_join_pending = false

	while state == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		if not _parse_message(_ws.get_packet().get_string_from_utf8()):
			push_warning("WebRtcSignalingClient received an invalid message.")

	if state != _old_state and state == WebSocketPeer.STATE_CLOSED:
		disconnected_from_signaling.emit(_ws.get_close_code(), _ws.get_close_reason())

	_old_state = state


func join_lobby(requested_lobby: String) -> Error:
	return _send_message(
		WebRtcSignalingMessages.Message.JOIN,
		0 if use_mesh else 1,
		requested_lobby,
	)


func seal_lobby() -> Error:
	return _send_message(WebRtcSignalingMessages.Message.SEAL, 0)


func send_candidate(peer_id: int, mid: String, index: int, sdp: String) -> Error:
	return _send_message(
		WebRtcSignalingMessages.Message.CANDIDATE,
		peer_id,
		"\n%s\n%d\n%s" % [mid, index, sdp],
	)


func send_offer(peer_id: int, offer: String) -> Error:
	return _send_message(WebRtcSignalingMessages.Message.OFFER, peer_id, offer)


func send_answer(peer_id: int, answer: String) -> Error:
	return _send_message(WebRtcSignalingMessages.Message.ANSWER, peer_id, answer)


func _send_message(type: int, id: int, data: String = "") -> Error:
	return _ws.send_text(JSON.stringify({
		"type": type,
		"id": id,
		"data": data,
	}))


func _parse_message(raw_message: String) -> bool:
	var json := JSON.new()
	if json.parse(raw_message) != OK:
		return false
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var message := parsed as Dictionary
	if not message.has("type") or not message.has("id") or typeof(message.get("data")) != TYPE_STRING:
		return false

	var type := int(message.type)
	var source_id := int(message.id)
	var data := String(message.data)

	match type:
		WebRtcSignalingMessages.Message.ID:
			connected_to_signaling.emit(source_id, data == "true")
		WebRtcSignalingMessages.Message.JOIN:
			lobby_joined.emit(data)
		WebRtcSignalingMessages.Message.SEAL:
			lobby_sealed.emit()
		WebRtcSignalingMessages.Message.PEER_CONNECT:
			peer_connected.emit(source_id)
		WebRtcSignalingMessages.Message.PEER_DISCONNECT:
			peer_disconnected.emit(source_id)
		WebRtcSignalingMessages.Message.OFFER:
			offer_received.emit(source_id, data)
		WebRtcSignalingMessages.Message.ANSWER:
			answer_received.emit(source_id, data)
		WebRtcSignalingMessages.Message.CANDIDATE:
			var candidate_data := data
			if candidate_data.begins_with("\n"):
				candidate_data = candidate_data.substr(1)
			var candidate: PackedStringArray = candidate_data.split("\n", false)
			if candidate.size() != 3 or not candidate[1].is_valid_int():
				return false
			candidate_received.emit(source_id, candidate[0], candidate[1].to_int(), candidate[2])
		_:
			return false

	return true
