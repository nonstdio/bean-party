class_name MinigameContext
extends RefCounted

var _contract_version: int = MinigameManifest.CONTRACT_VERSION
var _minigame_instance_id: String = ""
var _players: Array[PlayerSlot] = []
var _teams_by_player_id: Dictionary = {}
var _rng_seed: int = 0
var _input_source: MinigameInputSource


static func create(
		minigame_instance_id: String,
		players: Array[PlayerSlot],
		teams_by_player_id: Dictionary,
		rng_seed: int,
		input_source: MinigameInputSource,
) -> MinigameContext:
	var context := MinigameContext.new()
	context._minigame_instance_id = minigame_instance_id
	for player in players:
		if player != null:
			context._players.append(player.duplicate_slot())
	context._teams_by_player_id = teams_by_player_id.duplicate(true)
	context._rng_seed = rng_seed
	context._input_source = input_source
	return context


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if _contract_version != MinigameManifest.CONTRACT_VERSION:
		errors.append("Context contract version is not supported.")
	if _minigame_instance_id.strip_edges().is_empty():
		errors.append("Minigame instance id is required.")
	if _players.size() < 2 or _players.size() > MatchConstants.MAX_PLAYERS:
		errors.append("Context must contain between 2 and %d players." % MatchConstants.MAX_PLAYERS)

	var seen_player_ids: Dictionary = {}
	for player in _players:
		if player.player_id.is_empty():
			errors.append("Every context player requires a stable player id.")
		elif seen_player_ids.has(player.player_id):
			errors.append("Duplicate context player id: %s" % player.player_id)
		else:
			seen_player_ids[player.player_id] = true

	if _input_source == null:
		errors.append("A shell-owned minigame input source is required.")
	else:
		for player_id in seen_player_ids:
			if not _input_source.has_player(String(player_id)):
				errors.append("Input source is missing player id: %s" % player_id)

	for player_id in _teams_by_player_id:
		if not seen_player_ids.has(String(player_id)):
			errors.append("Team assignment references an unknown player id: %s" % player_id)

	return errors


func get_contract_version() -> int:
	return _contract_version


func get_minigame_instance_id() -> String:
	return _minigame_instance_id


func get_players() -> Array[PlayerSlot]:
	var players: Array[PlayerSlot] = []
	for player in _players:
		players.append(player.duplicate_slot())
	return players


func get_player_ids() -> PackedStringArray:
	var player_ids := PackedStringArray()
	for player in _players:
		player_ids.append(player.player_id)
	return player_ids


func get_player(player_id: String) -> PlayerSlot:
	for player in _players:
		if player.player_id == player_id:
			return player.duplicate_slot()
	return null


func get_team_id(player_id: String) -> Variant:
	return _teams_by_player_id.get(player_id)


func get_teams_by_player_id() -> Dictionary:
	return _teams_by_player_id.duplicate(true)


func get_rng_seed() -> int:
	return _rng_seed


func create_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	return rng


func get_input_source() -> MinigameInputSource:
	return _input_source
