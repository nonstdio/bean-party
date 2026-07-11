extends Control

const KEEPAWAY_SCENE := "res://minigames/keepaway-yard/scenes/keepaway_yard.tscn"


func _ready() -> void:
	var play_button := get_node_or_null("Margin/Content/PlayKeepaway") as Button
	if play_button != null:
		play_button.pressed.connect(_on_play_keepaway_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()


func _on_play_keepaway_pressed() -> void:
	get_tree().change_scene_to_file(KEEPAWAY_SCENE)
