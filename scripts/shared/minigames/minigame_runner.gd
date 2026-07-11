class_name MinigameRunner
extends Node

signal minigame_loaded(minigame_id: StringName)
signal minigame_started(minigame_id: StringName)
signal minigame_finished(result: MinigameResult)
signal minigame_unloaded(minigame_id: StringName)
signal contract_failed(errors: PackedStringArray)

enum State {
	EMPTY,
	LOADED,
	RUNNING,
	FINISHED,
}

var state: State = State.EMPTY
var _manifest: MinigameManifest
var _controller: MinigameController


func load_minigame(manifest: MinigameManifest, context: MinigameContext) -> bool:
	if state != State.EMPTY:
		return _fail(PackedStringArray(["Unload the active minigame before loading another one."]))
	if manifest == null:
		return _fail(PackedStringArray(["A minigame manifest is required."]))

	var errors := manifest.validate()
	if context == null:
		errors.append("A minigame context is required.")
	else:
		errors.append_array(context.validate())
		if not manifest.supports_player_count(context.get_player_ids().size()):
			errors.append(
				"Manifest does not support %d supplied players." % context.get_player_ids().size()
			)
	if not errors.is_empty():
		return _fail(errors)

	var instance := manifest.root_scene.instantiate()
	if not instance is MinigameController:
		instance.free()
		return _fail(PackedStringArray(["The minigame root scene must extend MinigameController."]))

	_manifest = manifest
	_controller = instance as MinigameController
	add_child(_controller)
	_controller.minigame_result_submitted.connect(_on_minigame_result_submitted)
	state = State.LOADED
	if not _controller.setup_minigame(context):
		_discard_active()
		return _fail(PackedStringArray(["The minigame controller rejected setup."]))

	minigame_loaded.emit(_manifest.minigame_id)
	return true


func start_active_minigame() -> bool:
	if state != State.LOADED or _controller == null:
		return false
	state = State.RUNNING
	if not _controller.start_minigame():
		state = State.LOADED
		return false
	minigame_started.emit(_manifest.minigame_id)
	return true


func abort_active_minigame(reason: String) -> bool:
	if state != State.LOADED and state != State.RUNNING:
		return false
	return _controller.abort_minigame(reason)


func retry_minigame(context: MinigameContext) -> bool:
	if state != State.FINISHED or _manifest == null:
		return false
	var manifest := _manifest
	unload_minigame()
	return load_minigame(manifest, context) and start_active_minigame()


func unload_minigame() -> bool:
	if state == State.EMPTY or _controller == null or _manifest == null:
		return false
	var minigame_id := _manifest.minigame_id
	_discard_active()
	minigame_unloaded.emit(minigame_id)
	return true


func get_active_controller() -> MinigameController:
	return _controller


func get_active_manifest() -> MinigameManifest:
	return _manifest


func _on_minigame_result_submitted(result: MinigameResult) -> void:
	if state != State.LOADED and state != State.RUNNING:
		return
	state = State.FINISHED
	minigame_finished.emit(result)


func _discard_active() -> void:
	if _controller != null:
		var callback := Callable(self, "_on_minigame_result_submitted")
		if _controller.minigame_result_submitted.is_connected(callback):
			_controller.minigame_result_submitted.disconnect(callback)
		if _controller.get_parent() == self:
			remove_child(_controller)
		_controller.free()
	_controller = null
	_manifest = null
	state = State.EMPTY


func _fail(errors: PackedStringArray) -> bool:
	contract_failed.emit(errors)
	return false
