extends MinigameController

const ROUND_DURATION_SECONDS := 10.0

@onready var _status: Label = %Status

var _elapsed_seconds: float = 0.0


func _process(delta: float) -> void:
	if state != State.RUNNING:
		return

	var context := get_minigame_context()
	var input_source := context.get_input_source()
	for player_id in context.get_player_ids():
		if input_source.is_action_just_pressed(player_id, MinigameInputSource.ACTION_PRIMARY):
			_finish_with_winner(player_id)
			return

	_elapsed_seconds += delta
	if _elapsed_seconds >= ROUND_DURATION_SECONDS:
		_finish_tied()


func _on_minigame_setup() -> void:
	_elapsed_seconds = 0.0
	if is_node_ready():
		_status.text = "Press primary first."


func _on_minigame_start() -> void:
	_elapsed_seconds = 0.0


func _on_minigame_abort(reason: String) -> void:
	if is_node_ready():
		_status.text = "Round aborted: %s" % reason


func _finish_with_winner(winner_id: String) -> void:
	var context := get_minigame_context()
	var remaining := PackedStringArray()
	var scores: Dictionary = {}
	for player_id in context.get_player_ids():
		scores[player_id] = 1 if player_id == winner_id else 0
		if player_id != winner_id:
			remaining.append(player_id)

	var placements: Array = [PackedStringArray([winner_id])]
	if not remaining.is_empty():
		placements.append(remaining)
	if is_node_ready():
		_status.text = "%s tapped first." % context.get_player(winner_id).display_name
	submit_minigame_result(MinigameResult.completed(placements, scores))


func _finish_tied() -> void:
	var player_ids := get_minigame_context().get_player_ids()
	var scores: Dictionary = {}
	for player_id in player_ids:
		scores[player_id] = 0
	if is_node_ready():
		_status.text = "Everyone tied."
	submit_minigame_result(MinigameResult.completed([player_ids], scores))
