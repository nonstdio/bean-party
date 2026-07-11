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
	snapshot.local_device_slots = session.export_local_device_slots()
	snapshot.board_stub = BoardStub.new()
	snapshot.board_stub.reset_for_slots(snapshot.slots)
	snapshot.match_settings = {"max_players": 4}
	return snapshot
