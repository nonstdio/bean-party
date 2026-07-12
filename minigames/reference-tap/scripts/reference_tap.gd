extends MinigameController

const ROUND_DURATION_SECONDS := 10.0
const _BADGE_SCENE := preload("res://scenes/shared/player_identity_badge.tscn")

@onready var _status: Label = %Status
@onready var _player_legend: HBoxContainer = %PlayerLegend

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
		_rebuild_player_legend()


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


func _rebuild_player_legend() -> void:
	for child in _player_legend.get_children():
		_player_legend.remove_child(child)
		child.queue_free()

	var context := get_minigame_context()
	if context == null:
		return
	for player in context.get_players():
		var group := VBoxContainer.new()
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		var badge := _BADGE_SCENE.instantiate() as PlayerIdentityBadge
		badge.set_slot_color(player.slot_color)
		group.add_child(badge)
		var label := Label.new()
		label.text = player.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"ShellSecondary"
		group.add_child(label)
		_player_legend.add_child(group)
