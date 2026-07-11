extends GutTest


func test_spawn_and_despawn_are_idempotent() -> void:
	var registry := ActionNetcodeEntityRegistry.new()
	registry.reset("instance_a")
	var first := registry.spawn_entity("prop", "", 1, {}, "spawn_msg_1")
	var second := registry.spawn_entity("prop", "", 1, {}, "spawn_msg_1")
	assert_eq(first, second)
	assert_true(registry.despawn_entity(first, 2, "removed", "despawn_msg_1"))
	assert_false(registry.despawn_entity(first, 2, "removed", "despawn_msg_1"))
	assert_eq(registry.get_entity(first), {})
