class_name ActionNetcodeFixedTick
extends RefCounted

var tick_hz: float = 30.0

var _accumulator: float = 0.0
var _sim_tick: int = 0


func reset(sim_tick: int = 0) -> void:
	_accumulator = 0.0
	_sim_tick = sim_tick


func get_sim_tick() -> int:
	return _sim_tick


func consume_ticks(delta: float) -> int:
	if tick_hz <= 0.0:
		return 0

	var step := 1.0 / tick_hz
	_accumulator += delta
	var ticks := 0
	while _accumulator >= step:
		_accumulator -= step
		_sim_tick += 1
		ticks += 1
	return ticks
