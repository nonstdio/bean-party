extends Control


func _ready() -> void:
	var label := Label.new()
	label.text = "Network stub minigame (placeholder)"
	label.theme_type_variation = &"ShellPrimary"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
