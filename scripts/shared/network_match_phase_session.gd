class_name NetworkMatchPhaseSession
extends Node

signal phase_state_changed

var current_phase: MatchPhase.Phase = MatchPhase.Phase.BOARD
var selected_minigame_id: String = ""
var minigame_instance_id: String = ""
var countdown_seconds_remaining: int = 0

var _authority: NetworkMatchPhaseAuthority = null
var _minigame_session: NetworkMinigameSession = null


func _ready() -> void:
	var match_session := _match_session()
	if match_session == null:
		return

	match_session.session_state_changed.connect(_on_match_session_state_changed)
	match_session.peer_connected.connect(_on_peer_connected)

	var board_session := _board_session()
	if board_session != null:
		board_session.board_active_changed.connect(_on_board_active_changed)

	_minigame_session = _find_minigame_session()
	if _minigame_session != null:
		_minigame_session.minigame_result_ready.connect(_on_minigame_result_ready)

	_on_match_session_state_changed()


func _process(delta: float) -> void:
	if not is_authority() or _authority == null:
		return
	if _authority.current_phase != MatchPhase.Phase.COUNTDOWN:
		return
	if not _authority.tick_countdown(delta):
		return
	_sync_from_authority()
	_broadcast_phase_sync()


func is_networked() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_session_established()


func is_authority() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_server()


func is_flow_active() -> bool:
	return _authority != null and _authority.is_flow_active()


func is_late_joiner() -> bool:
	return (
		is_networked()
		and not is_authority()
		and _authority != null
		and current_phase != MatchPhase.Phase.BOARD
		and not _local_peer_in_match_roster()
	)


func can_participate_in_active_minigame() -> bool:
	if _authority == null or current_phase != MatchPhase.Phase.ACTIVE_MINIGAME:
		return false
	if is_authority():
		return true
	return _local_peer_in_match_roster()


func get_briefing_ready(player_id: String) -> bool:
	if _authority == null:
		return false
	return bool(_authority.briefing_ready_by_player_id.get(player_id, false))


func owns_briefing_slot(player_id: String) -> bool:
	if _authority == null:
		return false
	for slot in _authority.match_slots:
		if slot.player_id == player_id:
			return slot.owning_peer_id == _local_peer_id()
	return false


func request_start_minigame_flow() -> void:
	if not is_networked() or not is_authority():
		return
	_host_start_minigame_flow()


func request_set_briefing_ready(player_id: String, is_ready: bool) -> void:
	if not is_networked() or _authority == null:
		return

	if is_authority():
		_host_apply_briefing_ready(_local_peer_id(), player_id, is_ready)
	else:
		_rpc_request_briefing_ready.rpc_id(1, player_id, is_ready)


func request_end_minigame_round() -> void:
	if not is_networked() or not is_authority():
		return
	_host_end_minigame_round()


func request_return_to_board() -> void:
	if not is_networked() or not is_authority():
		return
	_host_return_to_board()


func _match_session() -> MatchSession:
	var parent := get_parent()
	if parent is MatchSession:
		return parent
	return null


func _board_session() -> NetworkBoardSession:
	var match_session := _match_session()
	if match_session == null:
		return null
	for child in match_session.get_children():
		if child is NetworkBoardSession:
			return child
	return null


func _find_minigame_session() -> NetworkMinigameSession:
	var match_session := _match_session()
	if match_session == null:
		return null
	for child in match_session.get_children():
		if child is NetworkMinigameSession:
			return child
	return null


func _local_peer_id() -> int:
	var match_session := _match_session()
	if match_session == null:
		return MatchConstants.OFFLINE_PEER_ID
	return match_session.multiplayer.get_unique_id()


func _on_match_session_state_changed() -> void:
	if is_networked():
		return
	_reset_phase()


func _on_board_active_changed(is_active: bool) -> void:
	if not is_authority():
		return
	if is_active:
		_host_begin_from_board()
	else:
		_reset_phase()


func _on_peer_connected(peer_id: int) -> void:
	if not is_authority() or _authority == null:
		return
	_push_phase_sync_to_peer(peer_id)


func _on_minigame_result_ready(result: MinigameResult) -> void:
	if not is_authority() or _authority == null:
		return
	if _authority.current_phase != MatchPhase.Phase.ACTIVE_MINIGAME:
		return
	if not _authority.apply_host_minigame_result(result):
		return
	if not _authority.try_end_minigame_round():
		return
	call_deferred("_complete_minigame_phase_transition")


func _complete_minigame_phase_transition() -> void:
	if _authority == null:
		return
	_sync_from_authority()
	_broadcast_phase_sync()


func _reset_phase() -> void:
	_stop_active_minigame()
	_authority = null
	current_phase = MatchPhase.Phase.BOARD
	selected_minigame_id = ""
	minigame_instance_id = ""
	countdown_seconds_remaining = 0
	phase_state_changed.emit()


func _host_begin_from_board() -> void:
	var board_session := _board_session()
	if board_session == null or not board_session.is_board_active():
		return

	_authority = NetworkMatchPhaseAuthority.new()
	if not _authority.begin_from_board(
		board_session.get_board_slots(),
		board_session.board_stub,
	):
		_authority = null
		return

	_sync_from_authority()
	_broadcast_phase_sync()


func _host_start_minigame_flow() -> void:
	if _authority == null or not _authority.try_start_minigame_flow():
		return
	_sync_from_authority()
	_broadcast_phase_sync()


func _host_apply_briefing_ready(peer_id: int, player_id: String, is_ready: bool) -> void:
	if _authority == null:
		return
	if not _authority.try_set_briefing_ready(peer_id, player_id, is_ready):
		return
	_sync_from_authority()
	_broadcast_phase_sync()


func _host_end_minigame_round() -> void:
	if _minigame_session != null and _minigame_session.is_active:
		_minigame_session.force_complete_round()
		return
	if _authority == null or not _authority.try_end_minigame_round():
		return
	_sync_from_authority()
	_broadcast_phase_sync()


func _host_return_to_board() -> void:
	if _authority == null or not _authority.try_return_to_board():
		return

	var board_session := _board_session()
	if board_session != null:
		board_session.host_replace_board_state(
			_authority.board_stub,
			_authority.match_slots,
		)

	_sync_from_authority()
	_broadcast_phase_sync()


func _sync_from_authority() -> void:
	if _authority == null:
		return

	var previous_phase := current_phase
	current_phase = _authority.current_phase
	selected_minigame_id = _authority.selected_minigame_id
	minigame_instance_id = _authority.minigame_instance_id
	countdown_seconds_remaining = _authority.countdown_seconds_remaining
	_update_minigame_for_phase(previous_phase)
	phase_state_changed.emit()


func _apply_remote_phase_state(payload: Dictionary) -> void:
	if is_authority():
		return

	if _authority == null:
		_authority = NetworkMatchPhaseAuthority.new()

	var previous_phase := current_phase
	_authority.load_state(payload)
	_sync_from_authority()
	if previous_phase != current_phase:
		_update_minigame_for_phase(previous_phase)


func _broadcast_phase_sync() -> void:
	if _authority == null:
		return
	_rpc_apply_phase_sync.rpc(_authority.export_state())


func _push_phase_sync_to_peer(peer_id: int) -> void:
	if _authority == null:
		return
	_rpc_apply_phase_sync.rpc_id(peer_id, _authority.export_state())


func _local_peer_in_match_roster() -> bool:
	if _authority == null:
		return false

	var peer_id := _local_peer_id()
	for slot in _authority.match_slots:
		if slot.owning_peer_id == peer_id:
			return true
	return false


func _can_run_local_minigame() -> bool:
	if _authority == null:
		return false
	if is_authority():
		return true
	return _local_peer_in_match_roster()


func _update_minigame_for_phase(previous_phase: MatchPhase.Phase) -> void:
	if current_phase == MatchPhase.Phase.ACTIVE_MINIGAME:
		if _can_run_local_minigame():
			_start_active_minigame()
		else:
			_stop_active_minigame()
	elif previous_phase == MatchPhase.Phase.ACTIVE_MINIGAME:
		_stop_active_minigame()


func _start_active_minigame() -> void:
	if _minigame_session == null or _authority == null:
		return
	if _minigame_session.is_active:
		return
	_minigame_session.start_minigame(_authority.match_slots, _authority.minigame_instance_id)


func _stop_active_minigame() -> void:
	if _minigame_session == null:
		return
	_minigame_session.stop_minigame()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_briefing_ready(player_id: String, is_ready: bool) -> void:
	if not is_authority():
		return
	_host_apply_briefing_ready(multiplayer.get_remote_sender_id(), player_id, is_ready)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_phase_sync(payload: Dictionary) -> void:
	_apply_remote_phase_state(payload)
