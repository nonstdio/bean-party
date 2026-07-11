class_name LocalMatchPhaseController
extends RefCounted

signal phase_changed(old_phase: MatchPhase.Phase, new_phase: MatchPhase.Phase)
signal snapshot_captured(snapshot: MatchSnapshot)

const _VALID_TRANSITIONS: Dictionary = {
	MatchPhase.Phase.LOBBY: [MatchPhase.Phase.BOARD],
	MatchPhase.Phase.BOARD: [MatchPhase.Phase.MINIGAME_SELECTION],
	MatchPhase.Phase.MINIGAME_SELECTION: [MatchPhase.Phase.BRIEFING],
	MatchPhase.Phase.BRIEFING: [MatchPhase.Phase.COUNTDOWN],
	MatchPhase.Phase.COUNTDOWN: [MatchPhase.Phase.ACTIVE_MINIGAME],
	MatchPhase.Phase.ACTIVE_MINIGAME: [MatchPhase.Phase.RESULTS],
	MatchPhase.Phase.RESULTS: [MatchPhase.Phase.RETURN_TO_BOARD],
	MatchPhase.Phase.RETURN_TO_BOARD: [
		MatchPhase.Phase.BOARD,
		MatchPhase.Phase.MATCH_RESULTS,
	],
	MatchPhase.Phase.MATCH_RESULTS: [],
}

const _SNAPSHOT_BOUNDARIES: Array[MatchPhase.Phase] = [
	MatchPhase.Phase.LOBBY,
	MatchPhase.Phase.BOARD,
	MatchPhase.Phase.BRIEFING,
	MatchPhase.Phase.RESULTS,
	MatchPhase.Phase.RETURN_TO_BOARD,
	MatchPhase.Phase.MATCH_RESULTS,
]

const _STUB_MINIGAMES: Array[String] = [
	"keepaway-yard",
	"timing-tap",
	"bump-arena",
]

var session: OfflineMatchSession
var current_phase: MatchPhase.Phase = MatchPhase.Phase.LOBBY
var match_epoch: int = 0
var match_settings: Dictionary = {}
var board_stub: BoardStub = BoardStub.new()
var selected_minigame_id: String = ""
var teams_by_player_id: Dictionary = {}
var minigame_outcome_applied: bool = false
var pending_board_rewards: Array = []
var final_scores_by_player_id: Dictionary = {}
var last_snapshot: MatchSnapshot = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(offline_session: OfflineMatchSession) -> void:
	session = offline_session
	_rng.randomize()
	_on_enter_phase(MatchPhase.Phase.LOBBY)
	capture_snapshot()


func can_transition_to(target_phase: MatchPhase.Phase) -> bool:
	return target_phase in _VALID_TRANSITIONS.get(current_phase, [])


func get_valid_transitions() -> Array[MatchPhase.Phase]:
	var transitions: Array[MatchPhase.Phase] = []
	for phase in _VALID_TRANSITIONS.get(current_phase, []):
		transitions.append(phase)
	return transitions


func transition_to(target_phase: MatchPhase.Phase) -> bool:
	if not can_transition_to(target_phase):
		return false

	var old_phase := current_phase
	_on_exit_phase(old_phase)
	current_phase = target_phase
	_on_enter_phase(target_phase)

	if _is_snapshot_boundary(target_phase):
		capture_snapshot()

	phase_changed.emit(old_phase, current_phase)
	return true


func advance_happy_path() -> bool:
	var transitions := get_valid_transitions()
	if transitions.is_empty():
		return false
	return transition_to(transitions[0])


func capture_snapshot() -> MatchSnapshot:
	match_epoch += 1

	var snapshot := MatchSnapshot.new()
	snapshot.match_epoch = match_epoch
	snapshot.phase = current_phase
	snapshot.rng_seed = _rng.seed
	snapshot.rng_state = _rng.state
	snapshot.match_settings = match_settings.duplicate(true)
	snapshot.selected_minigame_id = selected_minigame_id
	snapshot.teams_by_player_id = teams_by_player_id.duplicate(true)
	snapshot.minigame_outcome_applied = minigame_outcome_applied
	snapshot.pending_board_rewards = pending_board_rewards.duplicate(true)
	snapshot.final_scores_by_player_id = final_scores_by_player_id.duplicate(true)

	for slot in session.slots:
		snapshot.slots.append(slot.duplicate_slot())

	if board_stub != null:
		snapshot.board_stub = board_stub.duplicate_stub()

	last_snapshot = snapshot
	snapshot_captured.emit(snapshot)
	return snapshot


func restore_from_snapshot(snapshot: MatchSnapshot) -> bool:
	if snapshot == null:
		return false

	var preserved_device_slots := session.export_local_device_slots()
	var previous_epochs := [match_epoch, snapshot.match_epoch]

	current_phase = snapshot.phase
	match_settings = snapshot.match_settings.duplicate(true)
	selected_minigame_id = snapshot.selected_minigame_id
	teams_by_player_id = snapshot.teams_by_player_id.duplicate(true)
	minigame_outcome_applied = snapshot.minigame_outcome_applied
	pending_board_rewards = snapshot.pending_board_rewards.duplicate(true)
	final_scores_by_player_id = snapshot.final_scores_by_player_id.duplicate(true)

	session.load_slots(snapshot.slots)
	_restore_local_device_slots(preserved_device_slots, snapshot.slots)
	board_stub = (
		snapshot.board_stub.duplicate_stub()
		if snapshot.board_stub != null
		else BoardStub.new()
	)

	_rng.seed = snapshot.rng_seed
	_rng.state = snapshot.rng_state

	match_epoch = max(previous_epochs[0], previous_epochs[1]) + 1

	last_snapshot = _duplicate_snapshot(snapshot)
	phase_changed.emit(current_phase, current_phase)
	return true


func restore_last_snapshot() -> bool:
	if last_snapshot == null:
		return false
	return restore_from_snapshot(_duplicate_snapshot(last_snapshot))


func advance_board_turn() -> void:
	if current_phase != MatchPhase.Phase.BOARD:
		return
	board_stub.advance_turn(session.slots)


func _on_enter_phase(phase: MatchPhase.Phase) -> void:
	match phase:
		MatchPhase.Phase.LOBBY:
			match_settings = {"max_players": MatchConstants.MAX_PLAYERS}
		MatchPhase.Phase.BOARD:
			if board_stub.beans_by_player_id.is_empty():
				board_stub.reset_for_slots(session.slots)
		MatchPhase.Phase.MINIGAME_SELECTION:
			selected_minigame_id = _pick_stub_minigame()
		MatchPhase.Phase.BRIEFING:
			for slot in session.slots:
				slot.ready = false
		MatchPhase.Phase.ACTIVE_MINIGAME:
			minigame_outcome_applied = false
		MatchPhase.Phase.RESULTS:
			_apply_stub_minigame_results()
		MatchPhase.Phase.RETURN_TO_BOARD:
			_apply_pending_board_rewards()
		MatchPhase.Phase.MATCH_RESULTS:
			_finalize_match_scores()


func _on_exit_phase(_phase: MatchPhase.Phase) -> void:
	pass


func _is_snapshot_boundary(phase: MatchPhase.Phase) -> bool:
	return phase in _SNAPSHOT_BOUNDARIES


func _pick_stub_minigame() -> String:
	var index := _rng.randi_range(0, _STUB_MINIGAMES.size() - 1)
	return _STUB_MINIGAMES[index]


func _apply_stub_minigame_results() -> void:
	pending_board_rewards.clear()
	minigame_outcome_applied = false

	if session.slots.is_empty():
		return

	var winner := session.slots[_rng.randi_range(0, session.slots.size() - 1)]
	pending_board_rewards.append(
		{
			"beans": 3,
			"player_id": winner.player_id,
			"reason": "minigame_win",
		}
	)
	minigame_outcome_applied = true


func _apply_pending_board_rewards() -> void:
	for reward in pending_board_rewards:
		if reward is Dictionary:
			board_stub.award_beans(
				String(reward.get("player_id", "")),
				int(reward.get("beans", 0)),
			)
	pending_board_rewards.clear()


func _finalize_match_scores() -> void:
	final_scores_by_player_id.clear()
	for slot in session.slots:
		final_scores_by_player_id[slot.player_id] = int(
			board_stub.beans_by_player_id.get(slot.player_id, 0)
		)


func _duplicate_snapshot(snapshot: MatchSnapshot) -> MatchSnapshot:
	return MatchSnapshotSerializer.deserialize(MatchSnapshotSerializer.serialize(snapshot))


func _restore_local_device_slots(
		preserved_device_slots: Dictionary,
		restored_slots: Array[PlayerSlot],
) -> void:
	for slot in restored_slots:
		if preserved_device_slots.has(slot.player_id):
			session.set_local_device_slot(
				slot.player_id,
				int(preserved_device_slots[slot.player_id]),
			)
