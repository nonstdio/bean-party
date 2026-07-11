class_name NetworkMatchPhaseAuthority
extends RefCounted

const SNAPSHOT_ARENA_MINIGAME_ID := "snapshot-arena"
const COUNTDOWN_SECONDS := 3

const _VALID_TRANSITIONS: Dictionary = {
	MatchPhase.Phase.BOARD: [MatchPhase.Phase.MINIGAME_SELECTION],
	MatchPhase.Phase.MINIGAME_SELECTION: [MatchPhase.Phase.BRIEFING],
	MatchPhase.Phase.BRIEFING: [MatchPhase.Phase.COUNTDOWN],
	MatchPhase.Phase.COUNTDOWN: [MatchPhase.Phase.ACTIVE_MINIGAME],
	MatchPhase.Phase.ACTIVE_MINIGAME: [MatchPhase.Phase.RESULTS],
	MatchPhase.Phase.RESULTS: [MatchPhase.Phase.RETURN_TO_BOARD],
	MatchPhase.Phase.RETURN_TO_BOARD: [MatchPhase.Phase.BOARD],
}

var current_phase: MatchPhase.Phase = MatchPhase.Phase.BOARD
var match_epoch: int = 0
var match_slots: Array[PlayerSlot] = []
var board_stub: BoardStub = BoardStub.new()
var selected_minigame_id: String = ""
var minigame_instance_id: String = ""
var result_id: String = ""
var reward_application_id: String = ""
var briefing_ready_by_player_id: Dictionary = {}
var pending_board_rewards: Array = []
var minigame_outcome_applied: bool = false
var countdown_seconds_remaining: int = 0
var minigame_winner_player_id: String = ""

var _applied_result_ids: Dictionary = {}
var _applied_reward_ids: Dictionary = {}
var _next_minigame_serial: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func is_flow_active() -> bool:
	return current_phase != MatchPhase.Phase.BOARD or minigame_instance_id != ""


func can_transition_to(target_phase: MatchPhase.Phase) -> bool:
	return target_phase in _VALID_TRANSITIONS.get(current_phase, [])


func begin_from_board(slots: Array[PlayerSlot], source_board: BoardStub) -> bool:
	if slots.is_empty() or source_board == null:
		return false

	match_slots.clear()
	for slot in slots:
		match_slots.append(slot.duplicate_slot())
	board_stub = source_board.duplicate_stub()
	current_phase = MatchPhase.Phase.BOARD
	_reset_minigame_run_state()
	return true


func try_start_minigame_flow() -> bool:
	if current_phase != MatchPhase.Phase.BOARD:
		return false
	if not _transition_to(MatchPhase.Phase.MINIGAME_SELECTION):
		return false
	return _transition_to(MatchPhase.Phase.BRIEFING)


func try_set_briefing_ready(requesting_peer_id: int, player_id: String, is_ready: bool) -> bool:
	if current_phase != MatchPhase.Phase.BRIEFING:
		return false

	var slot := _slot_for_player_id(player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false

	briefing_ready_by_player_id[player_id] = is_ready
	if _all_briefing_ready():
		return _transition_to(MatchPhase.Phase.COUNTDOWN)
	return true


func tick_countdown(delta: float) -> bool:
	if current_phase != MatchPhase.Phase.COUNTDOWN:
		return false

	var previous := countdown_seconds_remaining
	_countdown_elapsed += delta
	while _countdown_elapsed >= 1.0 and countdown_seconds_remaining > 0:
		_countdown_elapsed -= 1.0
		countdown_seconds_remaining -= 1

	if countdown_seconds_remaining == previous:
		return false

	if countdown_seconds_remaining <= 0:
		return _transition_to(MatchPhase.Phase.ACTIVE_MINIGAME)

	return true


var _countdown_elapsed: float = 0.0


func apply_host_minigame_result(result: MinigameResult) -> bool:
	if result == null or result.status != MinigameResult.Status.COMPLETED:
		return false
	if result.placements.is_empty():
		return false

	var first_group: Variant = result.placements[0]
	if not (first_group is PackedStringArray) or first_group.is_empty():
		return false

	minigame_winner_player_id = String(first_group[0])
	return true


func try_end_minigame_round() -> bool:
	if current_phase != MatchPhase.Phase.ACTIVE_MINIGAME:
		return false
	return _transition_to(MatchPhase.Phase.RESULTS)


func try_return_to_board() -> bool:
	if current_phase == MatchPhase.Phase.RESULTS:
		if not _transition_to(MatchPhase.Phase.RETURN_TO_BOARD):
			return false
	if current_phase != MatchPhase.Phase.RETURN_TO_BOARD:
		return false
	return _transition_to(MatchPhase.Phase.BOARD)


func export_state() -> Dictionary:
	var ready_payload: Dictionary = {}
	for player_id in briefing_ready_by_player_id:
		ready_payload[player_id] = bool(briefing_ready_by_player_id[player_id])

	return {
		"board_stub": board_stub.to_dict(),
		"briefing_ready_by_player_id": ready_payload,
		"countdown_seconds_remaining": countdown_seconds_remaining,
		"match_epoch": match_epoch,
		"match_slots": _export_slots(),
		"minigame_instance_id": minigame_instance_id,
		"minigame_outcome_applied": minigame_outcome_applied,
		"minigame_winner_player_id": minigame_winner_player_id,
		"pending_board_rewards": pending_board_rewards.duplicate(true),
		"phase": MatchPhase.to_key(current_phase),
		"result_id": result_id,
		"reward_application_id": reward_application_id,
		"selected_minigame_id": selected_minigame_id,
	}


func load_state(payload: Dictionary) -> void:
	current_phase = MatchPhase.from_key(String(payload.get("phase", "Board")))
	match_epoch = int(payload.get("match_epoch", 0))
	selected_minigame_id = String(payload.get("selected_minigame_id", ""))
	minigame_instance_id = String(payload.get("minigame_instance_id", ""))
	result_id = String(payload.get("result_id", ""))
	reward_application_id = String(payload.get("reward_application_id", ""))
	minigame_outcome_applied = bool(payload.get("minigame_outcome_applied", false))
	minigame_winner_player_id = String(payload.get("minigame_winner_player_id", ""))
	pending_board_rewards = payload.get("pending_board_rewards", []).duplicate(true)
	countdown_seconds_remaining = int(payload.get("countdown_seconds_remaining", 0))
	briefing_ready_by_player_id = payload.get("briefing_ready_by_player_id", {}).duplicate(true)

	var board_data: Variant = payload.get("board_stub")
	if board_data is Dictionary:
		board_stub = BoardStub.from_dict(board_data)
	else:
		board_stub = BoardStub.new()

	match_slots.clear()
	for entry in payload.get("match_slots", []):
		if entry is Dictionary:
			match_slots.append(PlayerSlot.from_dict(entry))


func _transition_to(target_phase: MatchPhase.Phase) -> bool:
	if not can_transition_to(target_phase):
		return false

	_on_exit_phase(current_phase)
	current_phase = target_phase
	_on_enter_phase(target_phase)
	match_epoch += 1
	return true


func _on_enter_phase(phase: MatchPhase.Phase) -> void:
	match phase:
		MatchPhase.Phase.MINIGAME_SELECTION:
			selected_minigame_id = SNAPSHOT_ARENA_MINIGAME_ID
			minigame_instance_id = _allocate_minigame_instance_id()
			result_id = ""
			reward_application_id = ""
		MatchPhase.Phase.BRIEFING:
			briefing_ready_by_player_id.clear()
			for slot in match_slots:
				briefing_ready_by_player_id[slot.player_id] = false
		MatchPhase.Phase.COUNTDOWN:
			countdown_seconds_remaining = COUNTDOWN_SECONDS
			_countdown_elapsed = 0.0
		MatchPhase.Phase.ACTIVE_MINIGAME:
			minigame_outcome_applied = false
		MatchPhase.Phase.RESULTS:
			_apply_minigame_results()
		MatchPhase.Phase.RETURN_TO_BOARD:
			_apply_pending_board_rewards()
		MatchPhase.Phase.BOARD:
			_reset_minigame_run_state()


func _on_exit_phase(_phase: MatchPhase.Phase) -> void:
	pass


func _apply_minigame_results() -> void:
	if result_id == "":
		result_id = "result_%s" % minigame_instance_id
	if _applied_result_ids.has(result_id):
		return

	_applied_result_ids[result_id] = true
	pending_board_rewards.clear()
	minigame_outcome_applied = false

	if match_slots.is_empty():
		return

	var winner_id := minigame_winner_player_id
	if winner_id == "" or _slot_for_player_id(winner_id) == null:
		winner_id = match_slots[_rng.randi_range(0, match_slots.size() - 1)].player_id

	pending_board_rewards.append(
		{
			"beans": 3,
			"player_id": winner_id,
			"reason": "minigame_win",
		}
	)
	minigame_outcome_applied = true


func _apply_pending_board_rewards() -> void:
	if reward_application_id == "":
		reward_application_id = "reward_%s" % minigame_instance_id
	if _applied_reward_ids.has(reward_application_id):
		return

	_applied_reward_ids[reward_application_id] = true
	for reward in pending_board_rewards:
		if reward is Dictionary:
			board_stub.award_beans(
				String(reward.get("player_id", "")),
				int(reward.get("beans", 0)),
			)
	pending_board_rewards.clear()


func _all_briefing_ready() -> bool:
	if match_slots.is_empty():
		return false
	for slot in match_slots:
		if not bool(briefing_ready_by_player_id.get(slot.player_id, false)):
			return false
	return true


func _reset_minigame_run_state() -> void:
	selected_minigame_id = ""
	minigame_instance_id = ""
	result_id = ""
	reward_application_id = ""
	briefing_ready_by_player_id.clear()
	pending_board_rewards.clear()
	minigame_outcome_applied = false
	minigame_winner_player_id = ""
	countdown_seconds_remaining = 0
	_countdown_elapsed = 0.0


func _allocate_minigame_instance_id() -> String:
	var id := "minigame_%d" % _next_minigame_serial
	_next_minigame_serial += 1
	return id


func _export_slots() -> Array:
	var payload: Array = []
	for slot in match_slots:
		payload.append(slot.to_dict())
	return payload


func _slot_for_player_id(player_id: String) -> PlayerSlot:
	for slot in match_slots:
		if slot.player_id == player_id:
			return slot
	return null
