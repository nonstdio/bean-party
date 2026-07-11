extends GutTest

const KEEPAWAY_SCENE := preload("res://minigames/keepaway-yard/scenes/keepaway_yard.tscn")
const RULES_SCRIPT := preload("res://minigames/keepaway-yard/scripts/keepaway_rules.gd")


func test_keepaway_scene_instantiates_and_restarts_cleanly() -> void:
	var scene := KEEPAWAY_SCENE.instantiate()
	add_child_autofree(scene)

	assert_eq(scene.name, "KeepawayYard")
	assert_not_null(scene.rules)
	assert_eq(scene.rules.phase, RULES_SCRIPT.Phase.BRIEFING)

	scene._restart_round()
	assert_eq(scene.rules.phase, RULES_SCRIPT.Phase.READY)
	assert_eq(scene.rules.holder_id, -1)
	assert_almost_eq(scene.rules.scores[0], 0.0, 0.001)
