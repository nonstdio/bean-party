extends GutTest

const _MATERIAL_PATHS: Array[String] = [
	"res://assets/standard/materials/identity-circle.tres",
	"res://assets/standard/materials/identity-triangle.tres",
	"res://assets/standard/materials/identity-square.tres",
	"res://assets/standard/materials/identity-diamond.tres",
]


func test_identity_registry_is_complete_and_unique() -> void:
	assert_eq(StandardVisuals.IDENTITY_IDS.size(), MatchConstants.MAX_PLAYERS)
	assert_eq(StandardVisuals.IDENTITY_COLORS.size(), MatchConstants.MAX_PLAYERS)
	assert_eq(StandardVisuals.IDENTITY_ICONS.size(), MatchConstants.MAX_PLAYERS)
	assert_eq(StandardVisuals.IDENTITY_MATERIALS.size(), MatchConstants.MAX_PLAYERS)
	assert_eq(MatchConstants.SLOT_COLORS, StandardVisuals.IDENTITY_COLORS)
	assert_eq(PlayerIdentityConstants.IDS, StandardVisuals.IDENTITY_IDS)
	assert_eq(PlayerIdentityConstants.COLORS, MatchConstants.SLOT_COLORS)

	var ids: Dictionary = {}
	var colors: Dictionary = {}
	for identity_index in MatchConstants.MAX_PLAYERS:
		var identity_id := StandardVisuals.IDENTITY_IDS[identity_index]
		var identity_color := StandardVisuals.IDENTITY_COLORS[identity_index]
		assert_false(ids.has(identity_id), "identity id repeated")
		assert_false(colors.has(identity_color), "identity color repeated")
		assert_not_null(StandardVisuals.IDENTITY_ICONS[identity_index])
		assert_not_null(StandardVisuals.IDENTITY_MATERIALS[identity_index])
		assert_eq(
			StandardVisuals.identity_icon_for_color(identity_color),
			StandardVisuals.IDENTITY_ICONS[identity_index],
		)
		assert_eq(
			StandardVisuals.identity_material_for_color(identity_color),
			StandardVisuals.IDENTITY_MATERIALS[identity_index],
		)
		ids[identity_id] = true
		colors[identity_color] = true


func test_identity_colors_survive_player_slot_json_round_trip() -> void:
	for identity_index in MatchConstants.MAX_PLAYERS:
		var slot := PlayerSlot.create(
			"player_%d" % identity_index,
			MatchConstants.OFFLINE_PEER_ID,
			identity_index,
			"Player %d" % (identity_index + 1),
			PlayerIdentityConstants.COLORS[identity_index],
		)
		var decoded: Variant = JSON.parse_string(JSON.stringify(slot.to_dict()))
		var restored := PlayerSlot.from_dict(decoded as Dictionary)
		assert_eq(restored.slot_color, PlayerIdentityConstants.COLORS[identity_index])
		assert_eq(StandardVisuals.identity_index_for_color(restored.slot_color), identity_index)


func test_identity_materials_match_registry() -> void:
	for identity_index in _MATERIAL_PATHS.size():
		var material := load(_MATERIAL_PATHS[identity_index]) as StandardMaterial3D
		assert_not_null(material)
		assert_eq(material.albedo_color, StandardVisuals.IDENTITY_COLORS[identity_index])
		assert_eq(material.metallic, 0.0)
		assert_almost_eq(material.roughness, 0.78, 0.001)


func test_prototype_theme_matches_shared_tokens() -> void:
	var theme := load("res://assets/standard/ui/prototype-theme.tres") as Theme
	assert_not_null(theme)
	assert_eq(theme.get_color(&"font_color", &"ShellTitle"), StandardVisuals.FOCUS)
	assert_eq(theme.get_color(&"font_color", &"ShellPrimary"), StandardVisuals.TEXT_PRIMARY)
	assert_eq(
		theme.get_color(&"font_color", &"ShellSecondary"),
		StandardVisuals.TEXT_SECONDARY,
	)
	assert_eq(theme.get_color(&"font_color", &"ShellMuted"), StandardVisuals.TEXT_MUTED)
	var background := theme.get_stylebox(&"panel", &"ShellBackground") as StyleBoxFlat
	assert_not_null(background)
	assert_eq(background.bg_color, StandardVisuals.CANVAS)


func test_badge_maps_known_and_unknown_colors() -> void:
	var scene := load("res://scenes/shared/player_identity_badge.tscn") as PackedScene
	var badge := scene.instantiate() as PlayerIdentityBadge
	add_child_autofree(badge)
	await get_tree().process_frame

	for identity_index in MatchConstants.MAX_PLAYERS:
		badge.set_slot_color(StandardVisuals.IDENTITY_COLORS[identity_index])
		assert_eq(badge.get_identity_index(), identity_index)

	badge.set_slot_color(Color.WHITE)
	assert_eq(badge.get_identity_index(), -1)
	assert_eq(badge.tooltip_text, "Circle")


func test_static_bean_has_expected_components_and_triangle_budget() -> void:
	var scene := load(
		"res://assets/standard/characters/bean-static-prototype.glb"
	) as PackedScene
	assert_not_null(scene)
	var bean := scene.instantiate()
	add_child_autofree(bean)

	for expected_name in [
		"Body",
		"Shoe_Left",
		"Shoe_Right",
		"Shin_Left",
		"Shin_Right",
		"Eye_Left_White",
		"Eye_Right_White",
		"Pupil_Left",
		"Pupil_Right",
	]:
		assert_not_null(bean.find_child(expected_name, true, false), expected_name)
	for rejected_name in ["Arm_Left", "Arm_Right", "Face_Smile"]:
		assert_null(bean.find_child(rejected_name, true, false), rejected_name)

	var body := bean.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body)
	assert_almost_eq(body.get_aabb().size.x, 0.64, 0.01)
	assert_almost_eq(body.get_aabb().size.y, 1.39, 0.01)
	var eye := bean.find_child("Eye_Left_White", true, false) as Node3D
	var pupil := bean.find_child("Pupil_Left", true, false) as Node3D
	assert_lt(eye.global_position.z, 0.0, "bean eyes must face Godot -Z")
	assert_lt(pupil.global_position.z, eye.global_position.z, "pupil must sit ahead of eye")

	var triangle_count := 0
	for node in bean.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangle_count += indices.size() / 3
	assert_gt(triangle_count, 0)
	assert_lte(triangle_count, 6000)


func test_existing_minigames_use_prototype_theme() -> void:
	for scene_path in [
		"res://minigames/reference-tap/scenes/main.tscn",
		"res://minigames/snapshot-arena/scenes/main.tscn",
		"res://minigames/action-spike/scenes/main.tscn",
		"res://minigames/_network_stub/network_stub_minigame.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		assert_not_null(scene, scene_path)
		var instance := scene.instantiate() as Control
		assert_not_null(instance, scene_path)
		assert_not_null(instance.theme, scene_path)
		assert_eq(
			instance.theme.resource_path,
			"res://assets/standard/ui/prototype-theme.tres",
			scene_path,
		)
		instance.free()


func test_gallery_instantiates_all_identities_and_diagnostics() -> void:
	var scene := load("res://scenes/dev/standard_asset_gallery.tscn") as PackedScene
	assert_not_null(scene)
	var gallery := scene.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame

	assert_eq(gallery.get_bean_instance_count(), MatchConstants.MAX_PLAYERS)
	gallery.set_camera_preset(0)
	assert_eq(gallery.camera_preset, 0)
	gallery.set_camera_preset(99)
	assert_eq(gallery.camera_preset, 2)
	gallery.set_grayscale_enabled(true)
	assert_true(gallery.grayscale_enabled)
	assert_eq(gallery._world_environment.environment.adjustment_saturation, 0.0)
