extends VBoxContainer

@onready var _phase_label: Label = %PhaseLabel
@onready var _board_label: Label = %BoardLabel
@onready var _snapshot_label: Label = %SnapshotLabel
@onready var _advance_button: Button = %AdvanceButton
@onready var _board_turn_button: Button = %BoardTurnButton
@onready var _restore_button: Button = %RestoreButton
@onready var _couch_session: VBoxContainer = %CouchSession

var controller: LocalMatchPhaseController
var _stored_snapshot: MatchSnapshot = null


func _ready() -> void:
	controller = LocalMatchPhaseController.new(_couch_session.session)
	controller.phase_changed.connect(_on_phase_changed)
	controller.snapshot_captured.connect(_on_snapshot_captured)
	_advance_button.pressed.connect(_on_advance_pressed)
	_board_turn_button.pressed.connect(_on_board_turn_pressed)
	_restore_button.pressed.connect(_on_restore_pressed)
	_refresh()


func _on_advance_pressed() -> void:
	controller.advance_happy_path()


func _on_board_turn_pressed() -> void:
	controller.advance_board_turn()
	_refresh()


func _on_restore_pressed() -> void:
	if _stored_snapshot == null:
		return
	controller.restore_from_snapshot(
		MatchSnapshotSerializer.deserialize(MatchSnapshotSerializer.serialize(_stored_snapshot))
	)


func _on_phase_changed(_old_phase: MatchPhase.Phase, _new_phase: MatchPhase.Phase) -> void:
	_refresh()


func _on_snapshot_captured(snapshot: MatchSnapshot) -> void:
	if snapshot.phase == MatchPhase.Phase.BOARD:
		_stored_snapshot = MatchSnapshotSerializer.deserialize(
			MatchSnapshotSerializer.serialize(snapshot)
		)
	_refresh()


func _refresh() -> void:
	_phase_label.text = "Phase: %s" % MatchPhase.to_key(controller.current_phase)
	_board_label.text = _build_board_summary()
	_snapshot_label.text = (
		"match_epoch %d · last snapshot at %s"
		% [
			controller.match_epoch,
			(
				MatchPhase.to_key(_stored_snapshot.phase)
				if _stored_snapshot != null
				else "none"
			),
		]
	)
	_advance_button.disabled = controller.get_valid_transitions().is_empty()
	_board_turn_button.disabled = controller.current_phase != MatchPhase.Phase.BOARD
	_restore_button.disabled = _stored_snapshot == null


func _build_board_summary() -> String:
	if controller.current_phase == MatchPhase.Phase.LOBBY:
		return "Board stub idle until the match enters the board phase."

	var stub := controller.board_stub
	if stub.beans_by_player_id.is_empty():
		return "Board stub not initialized."

	var parts: PackedStringArray = PackedStringArray()
	parts.append("Turn %d" % stub.turn_index)
	parts.append("active %s" % stub.active_player_id)
	for slot in controller.session.slots:
		var beans := int(stub.beans_by_player_id.get(slot.player_id, 0))
		parts.append("%s: %d beans" % [slot.display_name, beans])
	return " · ".join(parts)
