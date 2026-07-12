extends GutTest


func test_snapshot_json_round_trip() -> void:
	var snapshot := _build_sample_snapshot()
	var encoded := MatchSnapshotSerializer.serialize(snapshot)
	var decoded := MatchSnapshotSerializer.deserialize(encoded)

	assert_not_null(decoded)
	assert_eq(MatchSnapshotSerializer.serialize(decoded), encoded)
	assert_eq(decoded.phase, MatchPhase.Phase.BRIEFING)
	assert_eq(decoded.slots.size(), 2)
	assert_eq(decoded.board_stub.beans_by_player_id.size(), 2)
	assert_false(encoded.contains("local_device_slots"))


func test_slot_order_survives_round_trip() -> void:
	var snapshot := MatchSnapshot.new()
	snapshot.match_epoch = 1
	snapshot.phase = MatchPhase.Phase.BOARD
	snapshot.slots.append(PlayerSlot.create("player_z", MatchConstants.OFFLINE_PEER_ID, 0, "Zed"))
	snapshot.slots.append(PlayerSlot.create("player_a", MatchConstants.OFFLINE_PEER_ID, 1, "Amy"))
	snapshot.pending_board_rewards = [
		{"beans": 2, "player_id": "player_z", "reason": "first"},
		{"beans": 1, "player_id": "player_a", "reason": "second"},
	]

	var decoded := MatchSnapshotSerializer.deserialize(MatchSnapshotSerializer.serialize(snapshot))

	assert_eq(decoded.slots[0].player_id, "player_z")
	assert_eq(decoded.slots[1].player_id, "player_a")
	assert_eq(decoded.pending_board_rewards[0]["player_id"], "player_z")
	assert_eq(decoded.pending_board_rewards[1]["player_id"], "player_a")


func _build_sample_snapshot() -> MatchSnapshot:
	var session := OfflineMatchSession.new()
	var first := session.add_local_slot("One")
	var second := session.add_local_slot("Two")

	var snapshot := MatchSnapshot.new()
	snapshot.match_epoch = 3
	snapshot.phase = MatchPhase.Phase.BRIEFING
	snapshot.rng_seed = 4242
	snapshot.rng_state = 99
	snapshot.selected_minigame_id = "keepaway-yard"
	snapshot.slots.append(first.duplicate_slot())
	snapshot.slots.append(second.duplicate_slot())
	snapshot.board_stub = BoardStub.new()
	snapshot.board_stub.reset_for_slots(snapshot.slots)
	snapshot.match_settings = {"max_players": 4}
	return snapshot
