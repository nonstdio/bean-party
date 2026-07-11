extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 19000 + int(Time.get_ticks_msec() % 1000)


func test_rejects_fifth_player_across_peers() -> void:
	var authority := NetworkLobbyAuthority.new()

	assert_not_null(authority.try_add_slot(1, "Host"))
	assert_not_null(authority.try_add_slot(2, "Client A"))
	assert_not_null(authority.try_add_slot(3, "Client B"))
	assert_not_null(authority.try_add_slot(4, "Client C"))
	assert_eq(authority.slots.size(), MatchConstants.MAX_PLAYERS)

	var overflow := authority.try_add_slot(4, "Client D")
	assert_null(overflow)
	assert_eq(authority.slots.size(), MatchConstants.MAX_PLAYERS)


func test_rejects_second_slot_for_same_peer() -> void:
	var authority := NetworkLobbyAuthority.new()

	assert_not_null(authority.try_add_slot(1, "Host"))
	assert_null(authority.try_add_slot(1, "Host Two"))
	assert_eq(authority.slots.size(), 1)


func test_rejects_slot_mutation_for_wrong_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_slot := authority.try_add_slot(1, "Host")
	var client_slot := authority.try_add_slot(2, "Client")

	assert_false(authority.try_remove_slot(2, host_slot.player_id))
	assert_false(authority.try_set_ready(2, host_slot.player_id, true))
	assert_false(authority.try_set_display_name(2, host_slot.player_id, "Hijacked"))
	assert_false(host_slot.ready)

	assert_true(authority.try_set_ready(2, client_slot.player_id, true))
	assert_true(client_slot.ready)


func test_each_peer_uses_local_player_index_zero() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_slot := authority.try_add_slot(1, "Host")
	var client_slot := authority.try_add_slot(2, "Client")

	assert_eq(host_slot.local_player_index, 0)
	assert_eq(client_slot.local_player_index, 0)


func test_remove_slot_only_affects_requested_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_slot := authority.try_add_slot(1, "Host")
	var client_slot := authority.try_add_slot(2, "Client")

	assert_true(authority.try_remove_slot(2, client_slot.player_id))
	assert_eq(authority.slots.size(), 1)
	assert_eq(authority.slots[0].player_id, host_slot.player_id)
	assert_eq(host_slot.local_player_index, 0)


func test_remove_slots_for_peer_clears_only_that_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_slot := authority.try_add_slot(1, "Host")
	authority.try_add_slot(2, "Client A")
	authority.try_add_slot(3, "Client B")

	authority.remove_slots_for_peer(2)
	assert_eq(authority.slots.size(), 2)
	assert_eq(authority.slots[0].player_id, host_slot.player_id)


func test_ready_count_tracks_authority_state() -> void:
	var authority := NetworkLobbyAuthority.new()
	var first := authority.try_add_slot(1, "One")
	var second := authority.try_add_slot(2, "Two")

	assert_eq(authority.ready_count(), 0)
	assert_true(authority.try_set_ready(1, first.player_id, true))
	assert_true(authority.try_set_ready(2, second.player_id, true))
	assert_eq(authority.ready_count(), 2)


func test_display_name_change_survives_export_round_trip() -> void:
	var authority := NetworkLobbyAuthority.new()
	var slot := authority.try_add_slot(1, "Host")

	assert_true(authority.try_set_display_name(1, slot.player_id, "Captain Bean"))

	var replica := NetworkLobbyAuthority.new()
	replica.load_slots(authority.export_slots())
	assert_eq(replica.slots[0].display_name, "Captain Bean")


func test_can_add_local_slot_false_when_peer_already_has_player() -> void:
	var authority := NetworkLobbyAuthority.new()
	authority.try_add_slot(1, "Host")

	assert_false(authority.can_add_slot_for_peer(1))
	assert_true(authority.can_add_slot_for_peer(2))


func test_export_and_load_round_trip_preserves_slots() -> void:
	var authority := NetworkLobbyAuthority.new()
	authority.try_add_slot(1, "Host")
	authority.try_add_slot(2, "Guest")
	authority.try_set_ready(2, authority.slots[1].player_id, true)

	var replica := NetworkLobbyAuthority.new()
	replica.load_slots(authority.export_slots())

	assert_eq(replica.slots.size(), 2)
	assert_eq(replica.slots[0].owning_peer_id, 1)
	assert_eq(replica.slots[1].owning_peer_id, 2)
	assert_true(replica.slots[1].ready)
