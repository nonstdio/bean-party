extends GutTest

const MANIFEST_PATH := "res://minigames/action-spike/minigame.tres"


func test_manifest_satisfies_local_contract() -> void:
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	assert_not_null(manifest)
	assert_true(manifest.validate().is_empty())
	assert_eq(manifest.sync_profile, &"HOST_ACTION")


func test_player_visual_uses_standard_bean_material_and_marker() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var context := _create_context()
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	assert_true(runner.load_minigame(manifest, context))
	assert_true(runner.start_active_minigame())

	var controller := runner.get_active_controller()
	controller._process(0.016)
	var players_root := (
		controller.get_node("ViewportContainer/SubViewport/Arena3D/PlayersRoot") as Node3D
	)
	assert_eq(players_root.get_child_count(), 2)
	var first_visual := players_root.get_child(0) as Node3D
	assert_not_null(first_visual.find_child("Body", true, false))
	assert_not_null(first_visual.find_child("IdentityMarker", true, false))

	var body := first_visual.find_child("Body", true, false) as MeshInstance3D
	var material := body.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material)
	assert_eq(material.albedo_color, context.get_players()[0].slot_color)
	var second_visual := players_root.get_child(1) as Node3D
	var visual_forward := Vector3.FORWARD.rotated(Vector3.UP, second_visual.rotation.y)
	var expected_forward := ActionNetcodeHitscan.yaw_to_forward(PI * 0.25)
	assert_almost_eq(visual_forward.x, expected_forward.x, 0.0001)
	assert_almost_eq(visual_forward.z, expected_forward.z, 0.0001)

	var first_player_id := String(context.get_player_ids()[0])
	controller._offline_simulator.health_by_player_id[first_player_id] = 0
	controller._sync_player_meshes()
	for node in first_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		assert_almost_eq(mesh_instance.transparency, 0.55, 0.0001)
	var marker := first_visual.find_child("IdentityMarker", true, false) as Sprite3D
	assert_almost_eq(marker.modulate.a, 0.45, 0.0001)

	assert_true(runner.unload_minigame())
	await get_tree().process_frame


func _create_context() -> MinigameContext:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player 1")
	session.add_local_slot("Player 2")
	var player_ids := PackedStringArray()
	for slot in session.slots:
		player_ids.append(slot.player_id)
	return (
		MinigameContext
		. create(
			"action-spike-presentation",
			session.slots,
			{},
			12345,
			MinigameInputSource.new(player_ids),
		)
	)
