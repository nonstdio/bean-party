extends GutTest

const FORBIDDEN_SCRIPT_PATTERNS: PackedStringArray = [
	"ENetMultiplayerPeer",
	"MultiplayerPeer",
	"change_scene_to_file",
	"change_scene_to_packed",
	"Input.",
]


func test_every_discovered_minigame_uses_owned_root_and_controller() -> void:
	var registry := MinigameRegistry.new()
	assert_true(registry.discover(), "; ".join(registry.errors))

	for minigame_id in registry.get_minigame_ids():
		var manifest := registry.get_manifest(minigame_id)
		var instance := manifest.root_scene.instantiate()
		assert_true(instance is MinigameController, "%s root must extend MinigameController" % minigame_id)
		instance.free()


func test_every_discovered_minigame_sets_up_aborts_and_unloads_at_declared_bounds() -> void:
	var registry := MinigameRegistry.new()
	assert_true(registry.discover(), "; ".join(registry.errors))

	for minigame_id in registry.get_minigame_ids():
		var manifest := registry.get_manifest(minigame_id)
		var checked_counts: Dictionary = {}
		for player_count in [manifest.minimum_players, manifest.maximum_players]:
			if checked_counts.has(player_count):
				continue
			checked_counts[player_count] = true
			var runner := MinigameRunner.new()
			add_child_autofree(runner)
			var context := _create_context(player_count, "%s-%d" % [minigame_id, player_count])
			assert_true(runner.load_minigame(manifest, context), "%s setup failed" % minigame_id)
			assert_true(runner.abort_active_minigame("contract smoke abort"))
			assert_true(runner.unload_minigame())
			assert_eq(runner.get_child_count(), 0)
			await get_tree().process_frame


func test_minigames_do_not_reference_other_minigames_or_forbidden_shell_apis() -> void:
	var registry := MinigameRegistry.new()
	assert_true(registry.discover(), "; ".join(registry.errors))

	for minigame_id in registry.get_minigame_ids():
		var root := "res://minigames/%s" % minigame_id
		for file_path in _collect_contract_files(root):
			var contents := FileAccess.get_file_as_string(file_path)
			var other_reference := _find_other_minigame_reference(contents, String(minigame_id))
			assert_eq(other_reference, "", "%s references another minigame: %s" % [file_path, other_reference])
			if file_path.ends_with(".gd"):
				for forbidden_pattern in FORBIDDEN_SCRIPT_PATTERNS:
					assert_false(
						contents.contains(forbidden_pattern),
						"%s uses forbidden shell-owned API pattern: %s" % [file_path, forbidden_pattern],
					)


func _collect_contract_files(root: String) -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_contract_files_recursive(root, paths)
	return paths


func _collect_contract_files_recursive(root: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".gd") or file_name.ends_with(".tscn") or file_name.ends_with(".tres"):
			paths.append(root.path_join(file_name))
	for folder in directory.get_directories():
		_collect_contract_files_recursive(root.path_join(folder), paths)


func _find_other_minigame_reference(contents: String, own_id: String) -> String:
	var expression := RegEx.new()
	expression.compile("res://minigames/([a-z0-9][a-z0-9-]*)/")
	for match_result in expression.search_all(contents):
		var referenced_id := match_result.get_string(1)
		if referenced_id != own_id:
			return referenced_id
	return ""


func _create_context(player_count: int, instance_id: String) -> MinigameContext:
	var session := OfflineMatchSession.new()
	var player_ids := PackedStringArray()
	for index in player_count:
		var slot := session.add_local_slot("Player %d" % (index + 1))
		player_ids.append(slot.player_id)
	return MinigameContext.create(
		instance_id,
		session.slots,
		{},
		12345,
		MinigameInputSource.new(player_ids),
	)
