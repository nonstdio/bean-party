class_name ActionNetcodeInputBuffer
extends RefCounted


func record_input(player_id: String, input_tick: int, payload: Dictionary) -> void:
	if player_id == "" or input_tick < 0:
		return

	var history: Array = _history_by_player.get(player_id, [])
	for entry in history:
		if entry is Dictionary and int(entry.get("tick", -1)) == input_tick:
			return

	var insert_index := history.size()
	for index in history.size():
		var existing_tick: int = int(history[index].get("tick", -1))
		if existing_tick > input_tick:
			insert_index = index
			break

	(
		history
		. insert(
			insert_index,
			{
				"tick": input_tick,
				"payload": payload.duplicate(true),
			}
		)
	)
	_history_by_player[player_id] = history
	var latest: int = int(_latest_tick_by_player.get(player_id, 0))
	_latest_tick_by_player[player_id] = maxi(latest, input_tick)


func get_latest_tick(player_id: String) -> int:
	return int(_latest_tick_by_player.get(player_id, 0))


func get_input_at_tick(player_id: String, input_tick: int) -> Dictionary:
	var history: Array = _history_by_player.get(player_id, [])
	for entry in history:
		if entry is Dictionary and int(entry.get("tick", -1)) == input_tick:
			var payload: Variant = entry.get("payload")
			if payload is Dictionary:
				return payload
	return {}


func replay_after_tick(player_id: String, after_tick: int) -> Array:
	var replay: Array = []
	var history: Array = _history_by_player.get(player_id, [])
	for entry in history:
		if entry is not Dictionary:
			continue
		if int(entry.get("tick", 0)) <= after_tick:
			continue
		replay.append(entry.duplicate(true))
	return replay


func clear() -> void:
	_history_by_player.clear()
	_latest_tick_by_player.clear()


func clear_player(player_id: String) -> void:
	_history_by_player.erase(player_id)
	_latest_tick_by_player.erase(player_id)


var _history_by_player: Dictionary = {}
var _latest_tick_by_player: Dictionary = {}
