extends GutTest

const RULES_SCRIPT := preload("res://minigames/keepaway-yard/scripts/keepaway_rules.gd")


func _make_rules(player_count: int = 2) -> KeepawayRules:
	var rules := RULES_SCRIPT.new()
	rules.configure(player_count)
	return rules


func _start_active_round(rules: KeepawayRules) -> void:
	rules.advance_to_ready()
	rules.start_countdown()
	rules.tick(KeepawayRules.COUNTDOWN_SEC)
	assert_eq(rules.phase, KeepawayRules.Phase.ACTIVE)


func test_possession_acquisition_when_objective_is_loose() -> void:
	var rules := _make_rules(2)
	_start_active_round(rules)

	assert_true(rules.try_acquire_possession(0))
	assert_eq(rules.holder_id, 0)
	assert_false(rules.try_acquire_possession(1))


func test_possession_loss_after_valid_opposing_bump() -> void:
	var rules := _make_rules(2)
	_start_active_round(rules)
	rules.try_acquire_possession(0)

	assert_true(rules.apply_holder_bump(1))
	assert_eq(rules.holder_id, -1)


func test_bump_blocked_for_holder_immunity() -> void:
	var rules := _make_rules(2)
	_start_active_round(rules)
	rules.try_acquire_possession(0)
	rules.apply_holder_bump(1)
	rules.try_acquire_possession(0)

	assert_false(rules.apply_holder_bump(1))


func test_possession_time_scoring() -> void:
	var rules := _make_rules(2)
	_start_active_round(rules)
	rules.try_acquire_possession(1)
	rules.tick(2.5)

	assert_almost_eq(rules.scores[1], 2.5, 0.001)
	assert_almost_eq(rules.scores[0], 0.0, 0.001)


func test_round_completion_moves_to_results() -> void:
	var rules := _make_rules(3)
	_start_active_round(rules)

	rules.tick(KeepawayRules.ROUND_DURATION_SEC + 0.1)
	assert_eq(rules.phase, KeepawayRules.Phase.RESULTS)
	assert_almost_eq(rules.time_remaining, 0.0, 0.001)


func test_rankings_are_deterministic_with_ties() -> void:
	var rules := _make_rules(4)
	_start_active_round(rules)
	rules.scores[0] = 10.0
	rules.scores[1] = 12.0
	rules.scores[2] = 12.0
	rules.scores[3] = 4.0

	var rankings := rules.get_rankings()
	assert_eq(rankings[0]["player_id"], 1)
	assert_eq(rankings[1]["player_id"], 2)
	assert_eq(rankings[2]["player_id"], 0)
	assert_eq(rankings[3]["player_id"], 3)

	var winners := rules.get_winners()
	assert_eq(winners, [1, 2])


func test_restart_resets_round_state_without_leaking_scores() -> void:
	var rules := _make_rules(2)
	_start_active_round(rules)
	rules.try_acquire_possession(0)
	rules.tick(4.0)
	rules.apply_holder_bump(1)

	rules.restart_round()
	assert_eq(rules.phase, KeepawayRules.Phase.READY)
	assert_eq(rules.holder_id, -1)
	assert_almost_eq(rules.scores[0], 0.0, 0.001)
	assert_almost_eq(rules.scores[1], 0.0, 0.001)
	assert_almost_eq(rules.time_remaining, KeepawayRules.ROUND_DURATION_SEC, 0.001)
	assert_almost_eq(rules.bump_immunity_remaining[0], 0.0, 0.001)
