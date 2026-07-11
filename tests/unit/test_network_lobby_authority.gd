extends GutTest


func test_rejects_fifth_player_across_peers() -> void:
	var authority := NetworkLobbyAuthority.new()

	assert_not_null(authority.try_add_slot(1, "Host A"))
	assert_not_null(authority.try_add_slot(1, "Host B"))
	assert_not_null(authority.try_add_slot(2, "Client A"))
	assert_not_null(authority.try_add_slot(2, "Client B"))
	assert_eq(authority.slots.size(), MatchConstants.MAX_PLAYERS)

	var overflow := authority.try_add_slot(2, "Client C")
	assert_null(overflow)
	assert_eq(authority.slots.size(), MatchConstants.MAX_PLAYERS)


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


func test_local_player_indices_are_scoped_per_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_a := authority.try_add_slot(1, "Host A")
	var host_b := authority.try_add_slot(1, "Host B")
	var client_a := authority.try_add_slot(2, "Client A")

	assert_eq(host_a.local_player_index, 0)
	assert_eq(host_b.local_player_index, 1)
	assert_eq(client_a.local_player_index, 0)
	assert_eq(host_a.owning_peer_id, 1)
	assert_eq(client_a.owning_peer_id, 2)


func test_remove_slot_reindexes_only_owning_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_a := authority.try_add_slot(1, "Host A")
	var host_b := authority.try_add_slot(1, "Host B")
	var client_a := authority.try_add_slot(2, "Client A")

	assert_true(authority.try_remove_slot(1, host_a.player_id))
	assert_eq(host_b.local_player_index, 0)
	assert_eq(client_a.local_player_index, 0)


func test_remove_slots_for_peer_clears_only_that_peer() -> void:
	var authority := NetworkLobbyAuthority.new()
	var host_slot := authority.try_add_slot(1, "Host")
	authority.try_add_slot(2, "Client A")
	authority.try_add_slot(2, "Client B")

	authority.remove_slots_for_peer(2)
	assert_eq(authority.slots.size(), 1)
	assert_eq(authority.slots[0].player_id, host_slot.player_id)


func test_ready_count_tracks_authority_state() -> void:
	var authority := NetworkLobbyAuthority.new()
	var first := authority.try_add_slot(1, "One")
	var second := authority.try_add_slot(2, "Two")

	assert_eq(authority.ready_count(), 0)
	assert_true(authority.try_set_ready(1, first.player_id, true))
	assert_true(authority.try_set_ready(2, second.player_id, true))
	assert_eq(authority.ready_count(), 2)


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
