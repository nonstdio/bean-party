extends VBoxContainer

const _CONTROLLER_LABELS: Array[String] = [
	"Controller 1",
	"Controller 2",
	"Controller 3",
	"Controller 4",
]

@onready var _slots_list: VBoxContainer = %SlotsList
@onready var _add_player_button: Button = %AddPlayerButton
@onready var _status_label: Label = %StatusLabel

var session: OfflineMatchSession


func _ready() -> void:
	session = OfflineMatchSession.new()
	session.slots_changed.connect(_on_slots_changed)
	_add_player_button.pressed.connect(_on_add_player_pressed)
	_seed_default_players()
	_refresh()


func _seed_default_players() -> void:
	session.add_local_slot("Player 1")
	session.add_local_slot("Player 2")


func _on_add_player_pressed() -> void:
	if session.can_add_slot():
		session.add_local_slot()


func _on_slots_changed() -> void:
	_refresh()


func _refresh() -> void:
	for child in _slots_list.get_children():
		child.queue_free()

	for slot in session.slots:
		_slots_list.add_child(_build_slot_row(slot))

	_add_player_button.disabled = not session.can_add_slot()
	_status_label.text = _build_status_text()


func _build_status_text() -> String:
	if session.slots.is_empty():
		return "Add local players for a couch session (up to %d)." % MatchConstants.MAX_PLAYERS

	var ready_line := "%d of %d ready" % [session.ready_count(), session.slots.size()]
	return "%s · peer %d (offline)" % [ready_line, MatchConstants.OFFLINE_PEER_ID]


func _build_slot_row(slot: PlayerSlot) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.color = slot.slot_color
	row.add_child(swatch)

	var name_field := LineEdit.new()
	name_field.text = slot.display_name
	name_field.placeholder_text = "Display name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.text_changed.connect(func(new_text: String) -> void:
		session.set_display_name(slot.player_id, new_text)
	)
	row.add_child(name_field)

	var ready_toggle := CheckBox.new()
	ready_toggle.text = "Ready"
	ready_toggle.button_pressed = slot.ready
	ready_toggle.toggled.connect(func(is_pressed: bool) -> void:
		session.set_ready(slot.player_id, is_pressed)
	)
	row.add_child(ready_toggle)

	var controller_picker := OptionButton.new()
	for label in _CONTROLLER_LABELS:
		controller_picker.add_item(label)
	var device_slot := session.get_local_device_slot(slot.player_id)
	if device_slot >= 0:
		controller_picker.select(mini(device_slot, _CONTROLLER_LABELS.size() - 1))
	controller_picker.item_selected.connect(func(index: int) -> void:
		session.set_local_device_slot(slot.player_id, index)
	)
	row.add_child(controller_picker)

	if session.slots.size() > 1:
		var remove_button := Button.new()
		remove_button.text = "Remove"
		remove_button.pressed.connect(func() -> void:
			session.remove_slot(slot.player_id)
		)
		row.add_child(remove_button)

	return row
