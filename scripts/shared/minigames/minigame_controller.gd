class_name MinigameController
extends Node

signal minigame_setup_completed
signal minigame_result_submitted(result: MinigameResult)

enum State {
	CREATED,
	SET_UP,
	RUNNING,
	FINISHED,
}

var state: State = State.CREATED
var _minigame_context: MinigameContext


func setup_minigame(context: MinigameContext) -> bool:
	if state != State.CREATED or context == null:
		return false
	var errors := context.validate()
	if not errors.is_empty():
		push_error("Invalid minigame context: %s" % "; ".join(errors))
		return false

	_minigame_context = context
	state = State.SET_UP
	_on_minigame_setup()
	minigame_setup_completed.emit()
	return true


func start_minigame() -> bool:
	if state != State.SET_UP:
		return false
	state = State.RUNNING
	_on_minigame_start()
	return true


func abort_minigame(reason: String) -> bool:
	if state != State.SET_UP and state != State.RUNNING:
		return false
	_on_minigame_abort(reason)
	return _accept_minigame_result(MinigameResult.aborted(reason))


func submit_minigame_result(result: MinigameResult) -> bool:
	if state != State.RUNNING:
		return false
	return _accept_minigame_result(result)


func _accept_minigame_result(result: MinigameResult) -> bool:
	if result == null:
		return false

	var errors := result.validate(_minigame_context.get_player_ids())
	if not errors.is_empty():
		push_error("Invalid minigame result: %s" % "; ".join(errors))
		return false

	var accepted_result := result.duplicate_result()
	state = State.FINISHED
	minigame_result_submitted.emit(accepted_result)
	return true


func get_minigame_context() -> MinigameContext:
	return _minigame_context


func _on_minigame_setup() -> void:
	pass


func _on_minigame_start() -> void:
	pass


func _on_minigame_abort(_reason: String) -> void:
	pass
