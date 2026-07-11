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
