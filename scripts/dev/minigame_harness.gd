extends Control

@export_file("*.tres") var manifest_path := "res://minigames/reference-tap/minigame.tres"
@export_range(2, 4, 1) var player_count: int = 2
@export var rng_seed: int = 12345

@onready var _runner: MinigameRunner = %MinigameRunner
@onready var _status: Label = %Status
@onready var _player_buttons: HBoxContainer = %PlayerButtons

var _session: OfflineMatchSession
var _input_source: MinigameInputSource
var _instance_serial: int = 0


func _ready() -> void:
	process_priority = 100
	_runner.minigame_loaded.connect(_on_minigame_loaded)
	_runner.minigame_finished.connect(_on_minigame_finished)
	_runner.contract_failed.connect(_on_contract_failed)
	_create_players()
	_start_new_run()


func _process(_delta: float) -> void:
	if _input_source != null:
		_input_source.finish_frame()


func _create_players() -> void:
	_session = OfflineMatchSession.new()
	for index in player_count:
		var slot := _session.add_local_slot("Player %d" % (index + 1))
		var button := Button.new()
		button.text = "%s: primary" % slot.display_name
		button.pressed.connect(_press_primary.bind(slot.player_id))
		_player_buttons.add_child(button)


func _start_new_run() -> void:
	var manifest := load(manifest_path) as MinigameManifest
	if manifest == null:
		_status.text = "Could not load manifest: %s" % manifest_path
		return
	if _runner.load_minigame(manifest, _create_context()):
		_runner.start_active_minigame()


func _create_context() -> MinigameContext:
	_instance_serial += 1
	var player_ids := PackedStringArray()
	for slot in _session.slots:
		player_ids.append(slot.player_id)
	_input_source = MinigameInputSource.new(player_ids)
	return (
		MinigameContext
		. create(
			"harness-%d" % _instance_serial,
			_session.slots,
			{},
			rng_seed,
			_input_source,
		)
	)


func _press_primary(player_id: String) -> void:
	if _input_source == null:
		return
	_input_source.set_action_strength(player_id, MinigameInputSource.ACTION_PRIMARY, 1.0)
	call_deferred("_release_primary", player_id)


func _release_primary(player_id: String) -> void:
	if _input_source != null:
		_input_source.set_action_strength(player_id, MinigameInputSource.ACTION_PRIMARY, 0.0)


func _on_retry_pressed() -> void:
	if _runner.state == MinigameRunner.State.FINISHED:
		_runner.retry_minigame(_create_context())


func _on_abort_pressed() -> void:
	_runner.abort_active_minigame("Harness requested early exit")


func _on_minigame_loaded(minigame_id: StringName) -> void:
	_status.text = "Loaded %s with %d local players." % [minigame_id, player_count]


func _on_minigame_finished(result: MinigameResult) -> void:
	if result.status == MinigameResult.Status.ABORTED:
		_status.text = "Aborted: %s" % result.abort_reason
	else:
		_status.text = "Finished with placements: %s" % str(result.placements)


func _on_contract_failed(errors: PackedStringArray) -> void:
	_status.text = "Contract failure: %s" % "; ".join(errors)
