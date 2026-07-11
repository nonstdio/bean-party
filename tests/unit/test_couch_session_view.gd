extends GutTest


func test_name_field_survives_editing_without_row_rebuild() -> void:
	var scene := load("res://scenes/app/main.tscn") as PackedScene
	var main := scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame

	var view: VBoxContainer = main.find_child("CouchSession", true, false)
	assert_not_null(view)

	var first_player_id: String = view.session.slots[0].player_id
	var first_row: HBoxContainer = view._row_nodes[first_player_id]
	var name_field: LineEdit = first_row.get_child(1) as LineEdit

	name_field.grab_focus()
	name_field.text = "Be"
	await get_tree().process_frame
	name_field.text = "Bean"
	await get_tree().process_frame

	assert_true(name_field.has_focus())
	assert_same(first_row, view._row_nodes[first_player_id])
	assert_eq(name_field.text, "Bean")

	name_field.text_submitted.emit("Bean")
	assert_eq(view.session.get_slot(first_player_id).display_name, "Bean")
