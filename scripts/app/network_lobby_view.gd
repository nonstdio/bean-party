extends VBoxContainer

const _CONTROLLER_LABELS: Array[String] = [
	"Controller 1",
	"Controller 2",
	"Controller 3",
	"Controller 4",
]

@onready var _match_session: MatchSession = %MatchSession
@onready var _lobby_session: NetworkLobbySession = %NetworkLobbySession
@onready var _slots_list: VBoxContainer = %NetworkSlotsList
@onready var _add_player_button: Button = %NetworkAddPlayerButton
@onready var _status_label: Label = %NetworkLobbyStatusLabel

var _row_nodes: Dictionary = {}
var _syncing_controller_pickers := false


func _ready() -> void:
	_lobby_session.slots_structure_changed.connect(_on_slots_structure_changed)
	_lobby_session.session_state_changed.connect(_on_session_state_changed)
	_match_session.session_state_changed.connect(_update_chrome)
	_add_player_button.pressed.connect(_on_add_player_pressed)
	_sync_slot_rows()
	_update_chrome()


func _on_session_state_changed() -> void:
	_refresh_all_slot_rows()
	_update_chrome()


func _on_add_player_pressed() -> void:
	if _lobby_session.can_add_local_slot():
		_lobby_session.request_add_local_slot()


func _on_slots_structure_changed() -> void:
	_sync_slot_rows()
	_update_chrome()


func _sync_slot_rows() -> void:
	var current_ids: Dictionary = {}
	for slot in _lobby_session.slots:
		current_ids[slot.player_id] = true
		if not _row_nodes.has(slot.player_id):
			var row := _build_slot_row(slot)
			_row_nodes[slot.player_id] = row
			_slots_list.add_child(row)
		else:
			_refresh_slot_row(_row_nodes[slot.player_id], slot)

	for player_id in _row_nodes.keys():
		if not current_ids.has(player_id):
			var row: Node = _row_nodes[player_id]
			row.queue_free()
			_row_nodes.erase(player_id)

	for i in _lobby_session.slots.size():
		var slot: PlayerSlot = _lobby_session.slots[i]
		var row: Node = _row_nodes[slot.player_id]
		_slots_list.move_child(row, i)


func _update_chrome() -> void:
	var visible := _match_session.is_session_established()
	self.visible = visible
	if not visible:
		return

	_add_player_button.disabled = not _lobby_session.can_add_local_slot()
	_status_label.text = _build_status_text()


func _build_status_text() -> String:
	if _lobby_session.slots.is_empty():
		return "Network lobby active. Add local players for this peer (up to %d total)." % (
			MatchConstants.MAX_PLAYERS
		)

	var ready_line := "%d of %d ready" % [
		_lobby_session.ready_count(),
		_lobby_session.slots.size(),
	]
	var role := "host" if _match_session.is_server() else "client"
	return "%s · %s · local peer %d" % [ready_line, role, _match_session.multiplayer.get_unique_id()]


func _build_slot_row(slot: PlayerSlot) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.set_meta(&"player_id", slot.player_id)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.color = slot.slot_color
	row.add_child(swatch)

	var peer_label := Label.new()
	peer_label.text = "P%d" % slot.owning_peer_id
	peer_label.custom_minimum_size = Vector2(36, 0)
	row.add_child(peer_label)

	var name_control: Control
	if _lobby_session.owns_slot(slot.player_id):
		var name_field := LineEdit.new()
		name_field.text = slot.display_name
		name_field.placeholder_text = "Display name"
		name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_field.focus_exited.connect(func() -> void:
			_commit_display_name(slot.player_id, name_field.text)
		)
		name_field.text_submitted.connect(func(new_text: String) -> void:
			_commit_display_name(slot.player_id, new_text)
		)
		name_control = name_field
	else:
		var name_label := Label.new()
		name_label.text = slot.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_control = name_label

	row.set_meta(&"name_display", name_control)
	row.add_child(name_control)

	var ready_toggle := CheckBox.new()
	ready_toggle.text = "Ready"
	ready_toggle.button_pressed = slot.ready
	ready_toggle.disabled = not _lobby_session.owns_slot(slot.player_id)
	ready_toggle.toggled.connect(func(is_pressed: bool) -> void:
		if not _lobby_session.owns_slot(slot.player_id):
			return
		_commit_display_name_from_row(row, slot.player_id)
		_lobby_session.request_set_ready(slot.player_id, is_pressed)
	)
	row.add_child(ready_toggle)

	if _lobby_session.owns_slot(slot.player_id):
		var controller_picker := OptionButton.new()
		for label in _CONTROLLER_LABELS:
			controller_picker.add_item(label)
		var device_slot := _lobby_session.get_local_device_slot(slot.player_id)
		if device_slot >= 0:
			controller_picker.select(mini(device_slot, _CONTROLLER_LABELS.size() - 1))
		controller_picker.item_selected.connect(func(index: int) -> void:
			if _syncing_controller_pickers:
				return
			if _lobby_session.set_local_device_slot(slot.player_id, index):
				_sync_all_controller_pickers()
		)
		row.set_meta(&"controller_picker", controller_picker)
		row.add_child(controller_picker)

		_update_remove_button(row, slot.player_id)
	else:
		var remote_label := Label.new()
		remote_label.text = "Remote"
		row.add_child(remote_label)

	return row


func _refresh_slot_row(row: HBoxContainer, slot: PlayerSlot) -> void:
	var name_display: Control = row.get_meta(&"name_display")
	if name_display is LineEdit:
		var name_field: LineEdit = name_display
		if not name_field.has_focus():
			name_field.text = slot.display_name
	elif name_display is Label:
		name_display.text = slot.display_name

	for child in row.get_children():
		if child is CheckBox:
			child.button_pressed = slot.ready

	if _lobby_session.owns_slot(slot.player_id):
		_update_remove_button(row, slot.player_id)


func _refresh_all_slot_rows() -> void:
	for slot in _lobby_session.slots:
		if _row_nodes.has(slot.player_id):
			_refresh_slot_row(_row_nodes[slot.player_id], slot)


func _commit_display_name_from_row(row: HBoxContainer, player_id: String) -> void:
	var name_display: Control = row.get_meta(&"name_display")
	if name_display is LineEdit:
		_commit_display_name(player_id, name_display.text)


func _commit_display_name(player_id: String, display_name: String) -> void:
	if not _lobby_session.owns_slot(player_id):
		return

	var slot := _lobby_session.get_slot(player_id)
	if slot == null:
		return

	var trimmed := display_name.strip_edges()
	if slot.display_name == trimmed:
		return

	_lobby_session.request_set_display_name(player_id, trimmed)


func _update_remove_button(row: HBoxContainer, player_id: String) -> void:
	var existing: Node = row.get_node_or_null(^"RemoveButton")
	var local_slots := _lobby_session.get_local_slots()
	if local_slots.size() <= 1:
		if existing != null:
			existing.queue_free()
		return

	if existing == null:
		var remove_button := Button.new()
		remove_button.name = &"RemoveButton"
		remove_button.text = "Remove"
		remove_button.pressed.connect(func() -> void:
			_lobby_session.request_remove_local_slot(player_id)
		)
		row.add_child(remove_button)


func _sync_all_controller_pickers() -> void:
	_syncing_controller_pickers = true
	for player_id in _row_nodes:
		var row: HBoxContainer = _row_nodes[player_id]
		if not row.has_meta(&"controller_picker"):
			continue
		var picker: OptionButton = row.get_meta(&"controller_picker")
		var device_slot := _lobby_session.get_local_device_slot(player_id)
		picker.select(mini(device_slot, _CONTROLLER_LABELS.size() - 1))
	_syncing_controller_pickers = false
