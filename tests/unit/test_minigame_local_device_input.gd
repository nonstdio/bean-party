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
