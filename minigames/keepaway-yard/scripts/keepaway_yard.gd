extends Node2D

const RULES_SCRIPT := preload("res://minigames/keepaway-yard/scripts/keepaway_rules.gd")
const PLAYER_SCENE := preload("res://minigames/keepaway-yard/scripts/player_bean.gd")
const OBJECTIVE_SCENE := preload("res://minigames/keepaway-yard/scripts/objective_token.gd")
const MAIN_SCENE := "res://scenes/app/main.tscn"

const ARENA_SIZE := Vector2(760, 420)
const PLAYER_COUNT := 4

const MOVE_SPEED := 260.0
const MOVE_ACCELERATION := 2200.0
const MOVE_FRICTION := 1800.0
const BUMP_SPEED := 520.0
const BUMP_DURATION := 0.14
const BUMP_COOLDOWN := 1.1
const BUMP_HIT_RANGE := 42.0
const KNOCKBACK_SPEED := 340.0
const KNOCKBACK_DURATION := 0.2

var rules: KeepawayRules
var players: Array[CharacterBody2D] = []
var objective: Area2D
var ui_layer: CanvasLayer
var briefing_panel: Control
var hud_panel: Control
var results_panel: Control
var status_label: Label
var timer_label: Label
var holder_label: Label
var score_labels: Array[Label] = []
var results_list: Label
var player_count_setting: int = 4


func _ready() -> void:
	position = Vector2(640, 360)
	var camera := Camera2D.new()
	camera.enabled = true
	add_child(camera)
	_register_input_actions()
	rules = RULES_SCRIPT.new()
	rules.configure(player_count_setting)
	_build_arena()
	_build_players()
	_build_objective()
	_build_ui()
	_show_briefing()


func _physics_process(delta: float) -> void:
	rules.tick(delta)
	_handle_input()
	_update_players()
	_update_objective()
	_check_objective_pickups()
	_update_bump_collisions()
	_refresh_ui()
	if rules.phase == KeepawayRules.Phase.RESULTS and not results_panel.visible:
		_show_results()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_exit_to_main()


func _build_arena() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.12, 0.16, 0.14)
	floor_rect.size = ARENA_SIZE
	floor_rect.position = -ARENA_SIZE * 0.5
	add_child(floor_rect)

	var border := Line2D.new()
	border.width = 6.0
	border.default_color = Color(0.85, 0.85, 0.85)
	border.closed = true
	var half := ARENA_SIZE * 0.5
	border.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	add_child(border)

	_add_wall(Vector2(0, -half.y), Vector2(ARENA_SIZE.x, 20))
	_add_wall(Vector2(0, half.y), Vector2(ARENA_SIZE.x, 20))
	_add_wall(Vector2(-half.x, 0), Vector2(20, ARENA_SIZE.y))
	_add_wall(Vector2(half.x, 0), Vector2(20, ARENA_SIZE.y))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.position = center
	wall.add_child(shape)
	add_child(wall)


func _build_players() -> void:
	var spawns := [
		Vector2(-260, -120),
		Vector2(260, -120),
		Vector2(-260, 120),
		Vector2(260, 120),
	]
	for player_id in range(PLAYER_COUNT):
		var player: CharacterBody2D = PLAYER_SCENE.new()
		player.collision_layer = 2
		player.collision_mask = 1
		player.move_speed = MOVE_SPEED
		player.move_acceleration = MOVE_ACCELERATION
		player.move_friction = MOVE_FRICTION
		player.bump_speed = BUMP_SPEED
		player.bump_duration = BUMP_DURATION
		player.bump_cooldown = BUMP_COOLDOWN
		player.knockback_speed = KNOCKBACK_SPEED
		player.knockback_duration = KNOCKBACK_DURATION
		player.setup(player_id, spawns[player_id])
		player.visible = player_id < player_count_setting
		add_child(player)
		players.append(player)


func _build_objective() -> void:
	objective = OBJECTIVE_SCENE.new()
	objective.position = Vector2.ZERO
	objective.touched_by_player.connect(_on_objective_touched)
	add_child(objective)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	briefing_panel = _make_panel()
	ui_layer.add_child(briefing_panel)
	var briefing_text := Label.new()
	briefing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_text.custom_minimum_size = Vector2(700, 0)
	briefing_text.text = (
		"Keepaway Yard\n\n"
		+ "Hold the objective to score. Touch it while loose to pick it up.\n"
		+ "Bump the holder to knock it loose. Highest score when time runs out wins.\n\n"
		+ "P1: WASD + Space | P2: Arrows + Enter\n"
		+ "P3: IJKL + U | P4: Numpad 8456 + Numpad 0\n\n"
		+ "Press Enter or Space to ready up. Esc exits."
	)
	briefing_panel.add_child(_center_label(briefing_text))

	hud_panel = _make_panel()
	hud_panel.visible = false
	ui_layer.add_child(hud_panel)

	status_label = Label.new()
	status_label.position = Vector2(24, 16)
	hud_panel.add_child(status_label)

	timer_label = Label.new()
	timer_label.position = Vector2(24, 44)
	hud_panel.add_child(timer_label)

	holder_label = Label.new()
	holder_label.position = Vector2(24, 72)
	hud_panel.add_child(holder_label)

	for player_id in range(PLAYER_COUNT):
		var score_label := Label.new()
		score_label.position = Vector2(24, 104 + player_id * 24)
		hud_panel.add_child(score_label)
		score_labels.append(score_label)

	results_panel = _make_panel()
	results_panel.visible = false
	ui_layer.add_child(results_panel)

	results_list = Label.new()
	results_list.position = Vector2(24, 24)
	results_panel.add_child(results_list)


func _make_panel() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	return panel


func _center_label(label: Label) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return margin


func _show_briefing() -> void:
	rules.reset()
	briefing_panel.visible = true
	hud_panel.visible = false
	results_panel.visible = false
	objective.set_loose()
	_reset_objective_to_center()
	for player_id in range(PLAYER_COUNT):
		players[player_id].visible = player_id < player_count_setting


func _show_ready() -> void:
	rules.advance_to_ready()
	briefing_panel.visible = false
	hud_panel.visible = true
	results_panel.visible = false
	status_label.text = "Ready — press confirm to start countdown"


func _show_countdown() -> void:
	rules.start_countdown()
	status_label.text = "Countdown"


func _show_results() -> void:
	results_panel.visible = true
	var lines: PackedStringArray = PackedStringArray(["Final ranking:"])
	var rankings := rules.get_rankings()
	for rank_index in range(rankings.size()):
		var entry: Dictionary = rankings[rank_index]
		var player_id: int = entry["player_id"]
		if player_id >= player_count_setting:
			continue
		lines.append(
			"%d. P%d — %.1f" % [rank_index + 1, player_id + 1, entry["score"]]
		)
	lines.append("")
	lines.append("R = restart | Esc = exit to main menu")
	results_list.text = "\n".join(lines)


func _handle_input() -> void:
	match rules.phase:
		KeepawayRules.Phase.BRIEFING:
			if _confirm_pressed():
				_show_ready()
			return
		KeepawayRules.Phase.READY:
			if _confirm_pressed():
				_show_countdown()
			_apply_player_input(false)
			return
		KeepawayRules.Phase.COUNTDOWN:
			_apply_player_input(false)
			return
		KeepawayRules.Phase.ACTIVE:
			_apply_player_input(true)
			return
		KeepawayRules.Phase.RESULTS:
			if Input.is_action_just_pressed(&"ky_restart"):
				_restart_round()
			return


func _apply_player_input(allow_bump: bool) -> void:
	var move_inputs := [
		Input.get_vector(&"ky_p1_left", &"ky_p1_right", &"ky_p1_up", &"ky_p1_down"),
		Input.get_vector(&"ky_p2_left", &"ky_p2_right", &"ky_p2_up", &"ky_p2_down"),
		Input.get_vector(&"ky_p3_left", &"ky_p3_right", &"ky_p3_up", &"ky_p3_down"),
		Input.get_vector(&"ky_p4_left", &"ky_p4_right", &"ky_p4_up", &"ky_p4_down"),
	]
	var bump_pressed := [
		Input.is_action_just_pressed(&"ky_p1_bump"),
		Input.is_action_just_pressed(&"ky_p2_bump"),
		Input.is_action_just_pressed(&"ky_p3_bump"),
		Input.is_action_just_pressed(&"ky_p4_bump"),
	]

	for player_id in range(player_count_setting):
		var player: CharacterBody2D = players[player_id]
		player.set_move_input(move_inputs[player_id])
		if allow_bump and bump_pressed[player_id]:
			player.try_start_bump()


func _update_players() -> void:
	var half := ARENA_SIZE * 0.5 - Vector2(24, 24)
	for player_id in range(player_count_setting):
		var player: CharacterBody2D = players[player_id]
		player.position.x = clampf(player.position.x, -half.x, half.x)
		player.position.y = clampf(player.position.y, -half.y, half.y)


func _update_objective() -> void:
	if rules.holder_id >= 0:
		var holder: CharacterBody2D = players[rules.holder_id]
		objective.attach_to_holder(rules.holder_id)
		objective.follow_position(holder.position)
	else:
		objective.set_loose()


func _check_objective_pickups() -> void:
	if rules.phase != KeepawayRules.Phase.ACTIVE or rules.holder_id >= 0:
		return
	for player_id in range(player_count_setting):
		var player: CharacterBody2D = players[player_id]
		if player.position.distance_to(objective.position) <= 28.0:
			if rules.try_acquire_possession(player_id):
				objective.attach_to_holder(player_id)
				return


func _update_bump_collisions() -> void:
	if rules.phase != KeepawayRules.Phase.ACTIVE or rules.holder_id < 0:
		return

	var holder: CharacterBody2D = players[rules.holder_id]
	for player_id in range(player_count_setting):
		if player_id == rules.holder_id:
			continue
		var attacker: CharacterBody2D = players[player_id]
		if not attacker.is_bump_window_active():
			continue
		var distance := attacker.position.distance_to(holder.position)
		if distance > BUMP_HIT_RANGE:
			continue
		if rules.apply_holder_bump(player_id):
			var knock_dir := (holder.position - attacker.position).normalized()
			holder.apply_knockback(knock_dir)
			objective.set_loose()
			objective.position = holder.position + knock_dir * 24.0


func _on_objective_touched(player_id: int) -> void:
	if player_id >= player_count_setting:
		return
	if rules.try_acquire_possession(player_id):
		objective.attach_to_holder(player_id)


func _restart_round() -> void:
	rules.restart_round()
	results_panel.visible = false
	hud_panel.visible = true
	status_label.text = "Ready — press confirm to start countdown"
	objective.set_loose()
	_reset_objective_to_center()
	var spawns := [
		Vector2(-260, -120),
		Vector2(260, -120),
		Vector2(-260, 120),
		Vector2(260, 120),
	]
	for player_id in range(player_count_setting):
		var player: CharacterBody2D = players[player_id]
		player.position = spawns[player_id]
		player.velocity = Vector2.ZERO


func _refresh_ui() -> void:
	if not hud_panel.visible:
		return

	match rules.phase:
		KeepawayRules.Phase.READY:
			status_label.text = "Ready — press confirm to start countdown"
		KeepawayRules.Phase.COUNTDOWN:
			status_label.text = "Starting in %d" % [int(ceil(rules.countdown_remaining))]
		KeepawayRules.Phase.ACTIVE:
			status_label.text = "Round active"
		KeepawayRules.Phase.RESULTS:
			status_label.text = "Round over"

	timer_label.text = "Time: %.1fs" % rules.time_remaining
	if rules.holder_id < 0:
		holder_label.text = "Objective: LOOSE"
	else:
		holder_label.text = "Holder: P%d" % [rules.holder_id + 1]

	for player_id in range(PLAYER_COUNT):
		var visible_player := player_id < player_count_setting
		score_labels[player_id].visible = visible_player
		if visible_player:
			var cooldown_text := ""
			var player: CharacterBody2D = players[player_id]
			if player.get_cooldown_ratio() > 0.0:
				cooldown_text = " | bump %.1fs" % player.bump_cooldown_remaining
			score_labels[player_id].text = (
				"P%d: %.1f%s" % [player_id + 1, rules.scores[player_id], cooldown_text]
			)


func _reset_objective_to_center() -> void:
	objective.position = Vector2.ZERO


func _confirm_pressed() -> bool:
	return (
		Input.is_action_just_pressed(&"ky_p1_bump")
		or Input.is_action_just_pressed(&"ky_p2_bump")
		or Input.is_action_just_pressed(&"ky_confirm")
	)


func _register_input_actions() -> void:
	_add_key_action(&"ky_p1_left", KEY_A)
	_add_key_action(&"ky_p1_right", KEY_D)
	_add_key_action(&"ky_p1_up", KEY_W)
	_add_key_action(&"ky_p1_down", KEY_S)
	_add_key_action(&"ky_p1_bump", KEY_SPACE)

	_add_key_action(&"ky_p2_left", KEY_LEFT)
	_add_key_action(&"ky_p2_right", KEY_RIGHT)
	_add_key_action(&"ky_p2_up", KEY_UP)
	_add_key_action(&"ky_p2_down", KEY_DOWN)
	_add_key_action(&"ky_p2_bump", KEY_ENTER)

	_add_key_action(&"ky_p3_left", KEY_J)
	_add_key_action(&"ky_p3_right", KEY_L)
	_add_key_action(&"ky_p3_up", KEY_I)
	_add_key_action(&"ky_p3_down", KEY_K)
	_add_key_action(&"ky_p3_bump", KEY_U)

	_add_key_action(&"ky_p4_left", KEY_KP_4)
	_add_key_action(&"ky_p4_right", KEY_KP_6)
	_add_key_action(&"ky_p4_up", KEY_KP_8)
	_add_key_action(&"ky_p4_down", KEY_KP_5)
	_add_key_action(&"ky_p4_bump", KEY_KP_0)

	_add_key_action(&"ky_confirm", KEY_SPACE)
	_add_key_action(&"ky_restart", KEY_R)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _exit_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
