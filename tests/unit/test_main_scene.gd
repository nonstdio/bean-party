extends GutTest


func test_main_scene_instantiates() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	assert_not_null(scene)

	var main := scene.instantiate()
	add_child_autofree(main)

	assert_true(main is Control)
	assert_eq(main.name, &"Main")
