extends VBoxContainer

@onready var _match_session: MatchSession = %MatchSession
@onready var _lobby_session: NetworkLobbySession = %NetworkLobbySession
@onready var _board_session: NetworkBoardSession = %NetworkBoardSession
@onready var _phase_session: NetworkMatchPhaseSession = %NetworkMatchPhaseSession
@onready var _phase_label: Label = %NetworkPhaseLabel
@onready var _phase_detail_label: Label = %NetworkPhaseDetailLabel
@onready var _start_flow_button: Button = %NetworkStartMinigameFlowButton
@onready var _end_round_button: Button = %NetworkEndMinigameRoundButton
@onready var _return_board_button: Button = %NetworkReturnToBoardButton
@onready var _briefing_ready_button: Button = %NetworkBriefingReadyButton

var _local_briefing_player_id := ""


func _ready() -> void:
	_phase_session.phase_state_changed.connect(_refresh)
	_match_session.session_state_changed.connect(_refresh)
	_board_session.board_active_changed.connect(_on_board_active_changed)
	_lobby_session.slots_structure_changed.connect(_refresh)
	_start_flow_button.pressed.connect(_on_start_flow_pressed)
	_end_round_button.pressed.connect(_on_end_round_pressed)
	_return_board_button.pressed.connect(_on_return_board_pressed)
	_briefing_ready_button.pressed.connect(_on_briefing_ready_pressed)
	_refresh()


func _on_board_active_changed(_is_active: bool) -> void:
	_refresh()


func _on_start_flow_pressed() -> void:
	_phase_session.request_start_minigame_flow()


func _on_end_round_pressed() -> void:
	_phase_session.request_end_minigame_round()


func _on_return_board_pressed() -> void:
	_phase_session.request_return_to_board()


func _on_briefing_ready_pressed() -> void:
	if _local_briefing_player_id == "":
		return
	var next_ready := not _phase_session.get_briefing_ready(_local_briefing_player_id)
	_phase_session.request_set_briefing_ready(_local_briefing_player_id, next_ready)


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

	_local_briefing_player_id = ""
	if _phase_session.current_phase == MatchPhase.Phase.BRIEFING:
		for slot in _board_session.get_board_slots():
			if _phase_session.owns_briefing_slot(slot.player_id):
				_local_briefing_player_id = slot.player_id
				break

	_briefing_ready_button.visible = _local_briefing_player_id != ""
	if _local_briefing_player_id != "":
		var is_ready := _phase_session.get_briefing_ready(_local_briefing_player_id)
		_briefing_ready_button.text = "Briefing ready: %s" % ("yes" if is_ready else "no")
	_briefing_ready_button.disabled = _local_briefing_player_id == ""


func _build_phase_detail() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _phase_session.selected_minigame_id != "":
		parts.append("minigame %s" % _phase_session.selected_minigame_id)
	if _phase_session.minigame_instance_id != "":
		parts.append("instance %s" % _phase_session.minigame_instance_id)
	if _phase_session.current_phase == MatchPhase.Phase.COUNTDOWN:
		parts.append("countdown %d" % _phase_session.countdown_seconds_remaining)
	if parts.is_empty():
		return "Host can start the networked minigame flow from the board phase."
	return " · ".join(parts)
