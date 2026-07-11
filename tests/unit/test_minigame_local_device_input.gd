extends GutTest


func test_slot_three_uses_disjoint_numpad_keys() -> void:
	var slot_three_keys := (
		MinigameLocalDeviceInput.SLOT_3_HORIZONTAL_KEYS
		+ MinigameLocalDeviceInput.SLOT_3_VERTICAL_KEYS
	)
	var shared_arrow_keys := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

	for key in shared_arrow_keys:
		assert_false(
			key in slot_three_keys,
			"slot 3 must not share arrow keys with slot 0",
		)


func test_jump_edge_reports_rising_edge_only() -> void:
	MinigameLocalDeviceInput.reset_input_edge_state()
	assert_true(MinigameLocalDeviceInput._consume_jump_edge(1, true))
	assert_false(
		MinigameLocalDeviceInput._consume_jump_edge(1, true),
		"held jump must not retrigger",
	)
	assert_false(MinigameLocalDeviceInput._consume_jump_edge(1, false))
	assert_true(
		MinigameLocalDeviceInput._consume_jump_edge(1, true),
		"released then pressed jump must retrigger",
	)
