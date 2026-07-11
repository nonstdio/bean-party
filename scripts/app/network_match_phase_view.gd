extends VBoxContainer

@onready var _match_session: MatchSession = %MatchSession
@onready var _lobby_session: NetworkLobbySession = %NetworkLobbySession
@onready var _board_session: NetworkBoardSession = %NetworkBoardSession
@onready var _phase_session: NetworkMatchPhaseSession = %NetworkMatchPhaseSession
@onready var _phase_label: Label = %NetworkPhaseLabel
@onready var _phase_detail_label: Label = %NetworkPhaseDetailLabel
@onready var _briefing_ready_list: VBoxContainer = %NetworkBriefingReadyList
@onready var _start_flow_button: Button = %NetworkStartMinigameFlowButton
@onready var _end_round_button: Button = %NetworkEndMinigameRoundButton
@onready var _return_board_button: Button = %NetworkReturnToBoardButton

var _briefing_ready_buttons: Dictionary = {}


func _ready() -> void:
	_phase_session.phase_state_changed.connect(_refresh)
	_match_session.session_state_changed.connect(_refresh)
	_board_session.board_active_changed.connect(_on_board_active_changed)
	_lobby_session.slots_structure_changed.connect(_refresh)
	_start_flow_button.pressed.connect(_on_start_flow_pressed)
	_end_round_button.pressed.connect(_on_end_round_pressed)
	_return_board_button.pressed.connect(_on_return_board_pressed)
	_refresh()


func _on_board_active_changed(_is_active: bool) -> void:
	_refresh()


func _on_start_flow_pressed() -> void:
	_phase_session.request_start_minigame_flow()


func _on_end_round_pressed() -> void:
	_phase_session.request_end_minigame_round()


func _on_return_board_pressed() -> void:
	_phase_session.request_return_to_board()


func _on_briefing_ready_pressed(player_id: String) -> void:
	var next_ready := not _phase_session.get_briefing_ready(player_id)
	_phase_session.request_set_briefing_ready(player_id, next_ready)


func _refresh() -> void:
	var in_session := _match_session.is_session_established()
	self.visible = in_session and _board_session.is_board_active()

	if not in_session:
		return

	_phase_label.text = "Phase: %s" % MatchPhase.to_key(_phase_session.current_phase)
	_phase_detail_label.text = _build_phase_detail()

	_start_flow_button.visible = _match_session.is_server()
	_start_flow_button.disabled = (
		_phase_session.current_phase != MatchPhase.Phase.BOARD
		or _phase_session.is_flow_active()
	)

	_end_round_button.visible = _match_session.is_server()
	_end_round_button.disabled = (
		_phase_session.current_phase != MatchPhase.Phase.ACTIVE_MINIGAME
	)

	_return_board_button.visible = _match_session.is_server()
	_return_board_button.disabled = (
		_phase_session.current_phase != MatchPhase.Phase.RESULTS
		and _phase_session.current_phase != MatchPhase.Phase.RETURN_TO_BOARD
	)

	_sync_briefing_ready_buttons()


func _sync_briefing_ready_buttons() -> void:
	var show_briefing := _phase_session.current_phase == MatchPhase.Phase.BRIEFING
	_briefing_ready_list.visible = show_briefing

	if not show_briefing:
		_clear_briefing_ready_buttons()
		return

	var current_ids: Dictionary = {}
	for slot in _board_session.get_board_slots():
		if not _phase_session.owns_briefing_slot(slot.player_id):
			continue

		current_ids[slot.player_id] = true
		if not _briefing_ready_buttons.has(slot.player_id):
			var button := _build_briefing_ready_button(slot)
			_briefing_ready_buttons[slot.player_id] = button
			_briefing_ready_list.add_child(button)
		else:
			_refresh_briefing_ready_button(_briefing_ready_buttons[slot.player_id], slot)

	for player_id in _briefing_ready_buttons.keys():
		if not current_ids.has(player_id):
			var button: Node = _briefing_ready_buttons[player_id]
			button.queue_free()
			_briefing_ready_buttons.erase(player_id)


func _build_briefing_ready_button(slot: PlayerSlot) -> Button:
	var button := Button.new()
	button.set_meta(&"player_id", slot.player_id)
	button.pressed.connect(_on_briefing_ready_pressed.bind(slot.player_id))
	_refresh_briefing_ready_button(button, slot)
	return button


func _refresh_briefing_ready_button(button: Button, slot: PlayerSlot) -> void:
	var is_ready := _phase_session.get_briefing_ready(slot.player_id)
	button.text = "%s briefing ready: %s" % [
		slot.display_name,
		"yes" if is_ready else "no",
	]


func _clear_briefing_ready_buttons() -> void:
	for player_id in _briefing_ready_buttons.keys():
		var button: Node = _briefing_ready_buttons[player_id]
		button.queue_free()
	_briefing_ready_buttons.clear()


func _build_phase_detail() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _phase_session.selected_minigame_id != "":
		parts.append("minigame %s" % _phase_session.selected_minigame_id)
	if _phase_session.minigame_instance_id != "":
		parts.append("instance %s" % _phase_session.minigame_instance_id)
	if _phase_session.current_phase == MatchPhase.Phase.COUNTDOWN:
		parts.append("countdown %d" % _phase_session.countdown_seconds_remaining)
	if _phase_session.is_late_joiner():
		parts.append(
			"match already in progress; wait for the host to finish this round (reconnect not supported yet)"
		)
	if parts.is_empty():
		return "Host can start the networked minigame flow from the board phase."
	return " · ".join(parts)
