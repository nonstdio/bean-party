extends VBoxContainer

const _BADGE_SCENE := preload("res://scenes/shared/player_identity_badge.tscn")
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
var _row_nodes: Dictionary = {}
var _syncing_controller_pickers := false


func _ready() -> void:
	session = OfflineMatchSession.new()
	session.slots_structure_changed.connect(_on_slots_structure_changed)
	session.session_state_changed.connect(_update_chrome)
	_add_player_button.pressed.connect(_on_add_player_pressed)
	_seed_default_players()
	_sync_slot_rows()
	_update_chrome()


func _seed_default_players() -> void:
	session.add_local_slot("Player 1")
	session.add_local_slot("Player 2")


func _on_add_player_pressed() -> void:
	if session.can_add_slot():
		session.add_local_slot()


func _on_slots_structure_changed() -> void:
	_sync_slot_rows()
	_update_chrome()


func _sync_slot_rows() -> void:
	var current_ids: Dictionary = {}
	for slot in session.slots:
		current_ids[slot.player_id] = true
		if not _row_nodes.has(slot.player_id):
			var row := _build_slot_row(slot)
			_row_nodes[slot.player_id] = row
			_slots_list.add_child(row)
		else:
			_update_remove_button(_row_nodes[slot.player_id])

	for player_id in _row_nodes.keys():
		if not current_ids.has(player_id):
			var row: Node = _row_nodes[player_id]
			row.queue_free()
			_row_nodes.erase(player_id)

	for i in session.slots.size():
		var slot: PlayerSlot = session.slots[i]
		var row: Node = _row_nodes[slot.player_id]
		_slots_list.move_child(row, i)


func _update_chrome() -> void:
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
	row.set_meta(&"player_id", slot.player_id)

	var badge := _BADGE_SCENE.instantiate() as PlayerIdentityBadge
	badge.set_slot_color(slot.slot_color)
	row.add_child(badge)

	var name_field := LineEdit.new()
	name_field.text = slot.display_name
	name_field.placeholder_text = "Display name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.focus_exited.connect(
		func() -> void: session.set_display_name(slot.player_id, name_field.text)
	)
	name_field.text_submitted.connect(
		func(new_text: String) -> void: session.set_display_name(slot.player_id, new_text)
	)
	row.add_child(name_field)

	var ready_toggle := CheckBox.new()
	ready_toggle.text = "Ready"
	ready_toggle.button_pressed = slot.ready
	ready_toggle.toggled.connect(
		func(is_pressed: bool) -> void: session.set_ready(slot.player_id, is_pressed)
	)
	row.add_child(ready_toggle)

	var controller_picker := OptionButton.new()
	for label in _CONTROLLER_LABELS:
		controller_picker.add_item(label)
	var device_slot := session.get_local_device_slot(slot.player_id)
	if device_slot >= 0:
		controller_picker.select(mini(device_slot, _CONTROLLER_LABELS.size() - 1))
	controller_picker.item_selected.connect(
		func(index: int) -> void:
			if _syncing_controller_pickers:
				return
			if session.set_local_device_slot(slot.player_id, index):
				_sync_all_controller_pickers()
	)
	row.set_meta(&"controller_picker", controller_picker)
	row.add_child(controller_picker)

	_update_remove_button(row)
	return row


func _update_remove_button(row: HBoxContainer) -> void:
	var player_id: String = row.get_meta(&"player_id")
	var existing: Node = row.get_node_or_null(^"RemoveButton")
	if session.slots.size() <= 1:
		if existing != null:
			existing.queue_free()
		return

	if existing == null:
		var remove_button := Button.new()
		remove_button.name = &"RemoveButton"
		remove_button.text = "Remove"
		remove_button.pressed.connect(func() -> void: session.remove_slot(player_id))
		row.add_child(remove_button)


func _sync_all_controller_pickers() -> void:
	_syncing_controller_pickers = true
	for player_id in _row_nodes:
		var row: HBoxContainer = _row_nodes[player_id]
		var picker: OptionButton = row.get_meta(&"controller_picker")
		var device_slot := session.get_local_device_slot(player_id)
		picker.select(mini(device_slot, _CONTROLLER_LABELS.size() - 1))
	_syncing_controller_pickers = false
