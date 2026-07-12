class_name PlayerIdentityBadge
extends MarginContainer

@onready var _icon: TextureRect = %Icon

var _slot_color := Color.WHITE


func _ready() -> void:
	_apply_identity()


func set_slot_color(slot_color: Color) -> void:
	_slot_color = slot_color
	if is_node_ready():
		_apply_identity()


func get_identity_index() -> int:
	return StandardVisuals.identity_index_for_color(_slot_color)


func _apply_identity() -> void:
	var identity_index := get_identity_index()
	var display_index := StandardVisuals.fallback_identity_index(identity_index)
	_icon.texture = StandardVisuals.IDENTITY_ICONS[display_index]
	_icon.modulate = (
		StandardVisuals.IDENTITY_COLORS[identity_index] if identity_index >= 0 else _slot_color
	)
	tooltip_text = String(StandardVisuals.IDENTITY_IDS[display_index]).capitalize()
