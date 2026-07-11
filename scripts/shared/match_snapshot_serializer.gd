class_name MatchSnapshotSerializer
extends RefCounted

static func serialize(snapshot: MatchSnapshot) -> String:
	var payload: Dictionary = _sort_value(_snapshot_to_dict(snapshot))
	return JSON.stringify(payload)


static func deserialize(serialized: String) -> MatchSnapshot:
	var parsed: Variant = JSON.parse_string(serialized)
	if parsed == null or not parsed is Dictionary:
		push_error("Match snapshot JSON is invalid.")
		return null
	return _snapshot_from_dict(parsed)


static func snapshot_hash(snapshot: MatchSnapshot) -> int:
	return hash_dictionary(_snapshot_to_dict(snapshot))


static func hash_dictionary(data: Dictionary) -> int:
	return hash(JSON.stringify(_sort_value(data.duplicate(true))))


static func _snapshot_to_dict(snapshot: MatchSnapshot) -> Dictionary:
	var slot_payload: Array = []
	for slot in snapshot.slots:
		slot_payload.append(slot.to_dict())

	var board_payload: Variant = null
	if snapshot.board_stub != null:
		board_payload = snapshot.board_stub.to_dict()

	return {
		"board_stub": board_payload,
		"final_scores_by_player_id": _intify_dictionary(
			snapshot.final_scores_by_player_id
		),
		"match_epoch": snapshot.match_epoch,
		"match_settings": _intify_dictionary(snapshot.match_settings),
		"minigame_outcome_applied": snapshot.minigame_outcome_applied,
		"pending_board_rewards": snapshot.pending_board_rewards.duplicate(true),
		"phase": MatchPhase.to_key(snapshot.phase),
		"rng_seed": str(snapshot.rng_seed),
		"rng_state": str(snapshot.rng_state),
		"schema_version": MatchSnapshot.SCHEMA_VERSION,
		"selected_minigame_id": snapshot.selected_minigame_id,
		"slots": slot_payload,
		"teams_by_player_id": snapshot.teams_by_player_id.duplicate(true),
	}


static func _snapshot_from_dict(data: Dictionary) -> MatchSnapshot:
	var snapshot := MatchSnapshot.new()
	snapshot.match_epoch = int(data.get("match_epoch", 1))
	snapshot.phase = MatchPhase.from_key(String(data.get("phase", "Lobby")))
	snapshot.rng_seed = int(str(data.get("rng_seed", "0")))
	snapshot.rng_state = int(str(data.get("rng_state", "0")))
	snapshot.match_settings = _intify_dictionary(
		data.get("match_settings", {}).duplicate(true)
	)
	snapshot.selected_minigame_id = String(data.get("selected_minigame_id", ""))
	snapshot.teams_by_player_id = data.get("teams_by_player_id", {}).duplicate(true)
	snapshot.minigame_outcome_applied = bool(data.get("minigame_outcome_applied", false))
	snapshot.pending_board_rewards = data.get("pending_board_rewards", []).duplicate(true)
	snapshot.final_scores_by_player_id = _intify_dictionary(
		data.get("final_scores_by_player_id", {}).duplicate(true)
	)

	for slot_data in data.get("slots", []):
		if slot_data is Dictionary:
			snapshot.slots.append(PlayerSlot.from_dict(slot_data))

	var board_data: Variant = data.get("board_stub")
	if board_data is Dictionary:
		snapshot.board_stub = BoardStub.from_dict(board_data)

	return snapshot


static func _sort_value(value: Variant) -> Variant:
	if value is Dictionary:
		return _sort_dict(value)
	if value is Array:
		return _sort_array(value)
	return value


static func _sort_dict(data: Dictionary) -> Dictionary:
	var sorted: Dictionary = {}
	var keys: Array = data.keys()
	keys.sort()
	for key in keys:
		sorted[key] = _sort_value(data[key])
	return sorted


static func _sort_array(data: Array) -> Array:
	var sorted: Array = []
	for item in data:
		sorted.append(_sort_value(item))
	return sorted


static func _intify_dictionary(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in data:
		var value: Variant = data[key]
		if value is float and is_equal_approx(float(value), round(float(value))):
			normalized[key] = int(value)
		else:
			normalized[key] = value
	return normalized
