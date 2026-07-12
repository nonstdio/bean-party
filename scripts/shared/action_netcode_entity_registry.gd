class_name ActionNetcodeEntityRegistry
extends RefCounted

signal entity_spawned(network_entity_id: String)
signal entity_despawned(network_entity_id: String)


func reset(minigame_instance_id: String = "") -> void:
	_entities.clear()
	_spawn_message_ids.clear()
	_despawn_message_ids.clear()
	_next_entity_serial = 1
	_minigame_instance_id = minigame_instance_id


func register_player_avatar(
	player_id: String,
	spawn_tick: int,
	position: Vector3,
) -> String:
	return spawn_entity(
		"player_avatar",
		player_id,
		spawn_tick,
		{
			"position": position,
			"orientation": Vector3.ZERO,
		},
		"spawn_player_%s" % player_id,
	)


func spawn_entity(
	entity_type: String,
	owning_player_id: String,
	spawn_tick: int,
	gameplay_state: Dictionary = {},
	spawn_message_id: String = "",
) -> String:
	if spawn_message_id != "" and _spawn_message_ids.has(spawn_message_id):
		return String(_spawn_message_ids[spawn_message_id])

	var network_entity_id := "entity_%d" % _next_entity_serial
	_next_entity_serial += 1
	_entities[network_entity_id] = {
		"network_entity_id": network_entity_id,
		"minigame_instance_id": _minigame_instance_id,
		"entity_type": entity_type,
		"owning_player_id": owning_player_id,
		"spawn_tick": spawn_tick,
		"position": gameplay_state.get("position", Vector3.ZERO),
		"orientation": gameplay_state.get("orientation", Vector3.ZERO),
		"linear_velocity": gameplay_state.get("linear_velocity", Vector3.ZERO),
		"gameplay_state": gameplay_state.duplicate(true),
		"despawn_tick": -1,
		"despawn_reason": "",
	}
	if spawn_message_id != "":
		_spawn_message_ids[spawn_message_id] = network_entity_id
	entity_spawned.emit(network_entity_id)
	return network_entity_id


func despawn_entity(
	network_entity_id: String,
	despawn_tick: int,
	reason: String = "",
	despawn_message_id: String = "",
) -> bool:
	if despawn_message_id != "":
		if _despawn_message_ids.has(despawn_message_id):
			return false
		_despawn_message_ids[despawn_message_id] = true

	if not _entities.has(network_entity_id):
		return false

	var entity: Dictionary = _entities[network_entity_id]
	entity["despawn_tick"] = despawn_tick
	entity["despawn_reason"] = reason
	_entities.erase(network_entity_id)
	entity_despawned.emit(network_entity_id)
	return true


func get_entity(network_entity_id: String) -> Dictionary:
	return _entities.get(network_entity_id, {}).duplicate(true)


func get_player_avatar_id(player_id: String) -> String:
	for network_entity_id in _entities:
		var entity: Dictionary = _entities[network_entity_id]
		if (
			String(entity.get("entity_type", "")) == "player_avatar"
			and String(entity.get("owning_player_id", "")) == player_id
		):
			return network_entity_id
	return ""


func update_entity_transform(
	network_entity_id: String,
	position: Vector3,
	orientation: Vector3 = Vector3.ZERO,
	linear_velocity: Vector3 = Vector3.ZERO,
) -> void:
	if not _entities.has(network_entity_id):
		return
	var entity: Dictionary = _entities[network_entity_id]
	entity["position"] = position
	entity["orientation"] = orientation
	entity["linear_velocity"] = linear_velocity


func list_active_entities() -> Array:
	var entities: Array = []
	for network_entity_id in _entities:
		entities.append(_entities[network_entity_id].duplicate(true))
	return entities


var _entities: Dictionary = {}
var _spawn_message_ids: Dictionary = {}
var _despawn_message_ids: Dictionary = {}
var _next_entity_serial: int = 1
var _minigame_instance_id: String = ""
