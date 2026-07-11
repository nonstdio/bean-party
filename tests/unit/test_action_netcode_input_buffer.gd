extends GutTest


func test_record_input_accepts_out_of_order_ticks_idempotently() -> void:
	var buffer := ActionNetcodeInputBuffer.new()
	buffer.record_input("player_1", 3, {"move": Vector2.RIGHT})
	buffer.record_input("player_1", 1, {"move": Vector2.LEFT})
	buffer.record_input("player_1", 1, {"move": Vector2.UP})

	assert_eq(buffer.get_input_at_tick("player_1", 1).get("move"), Vector2.LEFT)
	assert_eq(buffer.get_input_at_tick("player_1", 3).get("move"), Vector2.RIGHT)
	assert_eq(buffer.get_latest_tick("player_1"), 3)
