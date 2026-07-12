extends GutTest


func test_cannot_exceed_max_players() -> void:
	var session := OfflineMatchSession.new()

	for i in MatchConstants.MAX_PLAYERS:
		var slot := session.add_local_slot("Player %d" % (i + 1))
		assert_not_null(slot, "slot %d should be created" % (i + 1))

	assert_eq(session.slots.size(), MatchConstants.MAX_PLAYERS)
	assert_false(session.can_add_slot())

	var overflow := session.add_local_slot("Player 5")
	assert_null(overflow)
	assert_eq(session.slots.size(), MatchConstants.MAX_PLAYERS)


func test_player_id_stable_when_toggling_ready() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Bean One")
	var player_id := slot.player_id

	session.set_ready(player_id, true)
	assert_eq(session.get_slot(player_id).player_id, player_id)
	assert_true(session.get_slot(player_id).ready)

	session.set_ready(player_id, false)
	assert_eq(session.get_slot(player_id).player_id, player_id)
	assert_false(session.get_slot(player_id).ready)


func test_multiple_local_player_indices_on_one_offline_peer() -> void:
	var session := OfflineMatchSession.new()
	var first := session.add_local_slot("Couch A")
	var second := session.add_local_slot("Couch B")

	assert_eq(first.local_player_index, 0)
	assert_eq(second.local_player_index, 1)
	assert_eq(first.owning_peer_id, MatchConstants.OFFLINE_PEER_ID)
	assert_eq(second.owning_peer_id, MatchConstants.OFFLINE_PEER_ID)
	assert_ne(first.player_id, second.player_id)


func test_local_device_mapping_stays_session_local() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Mapper")

	assert_eq(session.get_local_device_slot(slot.player_id), 0)

	session.set_local_device_slot(slot.player_id, 2)
	assert_eq(session.get_local_device_slot(slot.player_id), 2)
	assert_eq(slot.local_player_index, 0)


func test_remove_slot_reindexes_local_player_indices() -> void:
	var session := OfflineMatchSession.new()
	var first := session.add_local_slot("First")
	var second := session.add_local_slot("Second")
	var third := session.add_local_slot("Third")

	session.remove_slot(second.player_id)

	assert_eq(session.slots.size(), 2)
	assert_eq(session.get_slot(first.player_id).local_player_index, 0)
	assert_eq(session.get_slot(third.player_id).local_player_index, 1)


func test_player_id_not_reused_after_remove() -> void:
	var session := OfflineMatchSession.new()
	var removed := session.add_local_slot("Removed")
	var removed_id := removed.player_id

	session.remove_slot(removed_id)
	var replacement := session.add_local_slot("Replacement")

	assert_ne(replacement.player_id, removed_id)


func test_add_after_remove_uses_unused_controller_and_color() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("One")
	session.add_local_slot("Two")
	var third := session.add_local_slot("Three")

	session.remove_slot(third.player_id)
	var fourth := session.add_local_slot("Four")

	assert_eq(session.get_local_device_slot(fourth.player_id), 2)
	assert_eq(fourth.slot_color, MatchConstants.SLOT_COLORS[2])
	_assert_unique_device_slots(session)
	_assert_unique_slot_colors(session)


func test_set_local_device_slot_rejects_invalid_range() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Player")

	assert_false(session.set_local_device_slot(slot.player_id, -1))
	assert_false(session.set_local_device_slot(slot.player_id, MatchConstants.MAX_PLAYERS))
	assert_eq(session.get_local_device_slot(slot.player_id), 0)


func test_set_local_device_slot_swaps_occupied_controller() -> void:
	var session := OfflineMatchSession.new()
	var first := session.add_local_slot("First")
	var second := session.add_local_slot("Second")

	assert_true(session.set_local_device_slot(second.player_id, 0))
	assert_eq(session.get_local_device_slot(second.player_id), 0)
	assert_eq(session.get_local_device_slot(first.player_id), 1)


func test_set_display_name_does_not_emit_structure_changed() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Original")
	var structure_changes := [0]
	session.slots_structure_changed.connect(func() -> void: structure_changes[0] += 1)

	session.set_display_name(slot.player_id, "Renamed")

	assert_eq(slot.display_name, "Renamed")
	assert_eq(structure_changes[0], 0)


func test_set_ready_emits_session_state_not_structure() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Ready Bean")
	var structure_changes := [0]
	var state_changes := [0]
	session.slots_structure_changed.connect(func() -> void: structure_changes[0] += 1)
	session.session_state_changed.connect(func() -> void: state_changes[0] += 1)

	session.set_ready(slot.player_id, true)

	assert_eq(structure_changes[0], 0)
	assert_eq(state_changes[0], 1)


func _assert_unique_device_slots(session: OfflineMatchSession) -> void:
	var used: Dictionary = {}
	for slot in session.slots:
		var device_slot := session.get_local_device_slot(slot.player_id)
		assert_false(used.has(device_slot), "device slot %d assigned twice" % device_slot)
		used[device_slot] = true


func _assert_unique_slot_colors(session: OfflineMatchSession) -> void:
	var used: Dictionary = {}
	for slot in session.slots:
		assert_false(used.has(slot.slot_color), "slot color assigned twice")
		used[slot.slot_color] = true
