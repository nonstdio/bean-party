extends VBoxContainer

@onready var _match_session: MatchSession = %MatchSession
@onready var _lobby_session: NetworkLobbySession = %NetworkLobbySession
@onready var _slots_list: VBoxContainer = %NetworkSlotsList
@onready var _add_player_button: Button = %NetworkAddPlayerButton
@onready var _status_label: Label = %NetworkLobbyStatusLabel

var _row_nodes: Dictionary = {}


func _ready() -> void:
	_lobby_session.slots_structure_changed.connect(_on_slots_structure_changed)
	_lobby_session.session_state_changed.connect(_on_session_state_changed)
	_match_session.session_state_changed.connect(_update_chrome)
	_match_session.ping_updated.connect(_on_ping_updated)
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


func _on_ping_updated(_peer_id: int, _ping_ms: int) -> void:
	_refresh_all_slot_rows()


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

	var local_slots := _lobby_session.get_local_slots()
	_add_player_button.visible = local_slots.is_empty() and _lobby_session.can_add_local_slot()
	_add_player_button.text = "Join match"
	_add_player_button.disabled = not _lobby_session.can_add_local_slot()
	_status_label.text = _build_status_text()


func _build_status_text() -> String:
	if _lobby_session.slots.is_empty():
		return "Network lobby active. One player per screen; up to %d peers." % (
			MatchConstants.MAX_PLAYERS
		)

	var ready_line := "%d of %d ready" % [
		_lobby_session.ready_count(),
		_lobby_session.slots.size(),
	]
	var role := "host" if _match_session.is_server() else "client"
	return "%s · %s · one player per screen" % [ready_line, role]


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
	peer_label.text = _format_peer_label(slot)
	peer_label.custom_minimum_size = Vector2(72, 0)
	row.set_meta(&"peer_label", peer_label)
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

	var ping_label := Label.new()
	ping_label.custom_minimum_size = Vector2(56, 0)
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ping_label.text = _format_ping_for_slot(slot)
	row.set_meta(&"ping_label", ping_label)
	row.add_child(ping_label)

	if not _lobby_session.owns_slot(slot.player_id):
		var remote_label := Label.new()
		remote_label.text = "Remote"
		row.add_child(remote_label)

	return row


func _format_peer_label(slot: PlayerSlot) -> String:
	if slot.owning_peer_id == 1:
		return "Host"
	return "Peer %d" % slot.owning_peer_id


func _format_ping_for_slot(slot: PlayerSlot) -> String:
	var local_peer_id := _match_session.multiplayer.get_unique_id()
	if slot.owning_peer_id == local_peer_id:
		if _match_session.is_server():
			return "local"
		return _format_ping_ms(_match_session.get_ping_ms(1))

	return _format_ping_ms(_match_session.get_ping_ms(slot.owning_peer_id))


func _format_ping_ms(ping_ms: int) -> String:
	if ping_ms < 0:
		return "…"
	return "%d ms" % ping_ms


func _refresh_slot_row(row: HBoxContainer, slot: PlayerSlot) -> void:
	if row.has_meta(&"peer_label"):
		var peer_label: Label = row.get_meta(&"peer_label")
		peer_label.text = _format_peer_label(slot)

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

	if row.has_meta(&"ping_label"):
		var ping_label: Label = row.get_meta(&"ping_label")
		ping_label.text = _format_ping_for_slot(slot)


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
