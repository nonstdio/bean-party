extends VBoxContainer

@onready var _match_session: MatchSession = %MatchSession
@onready var _lobby_session: NetworkLobbySession = %NetworkLobbySession
@onready var _board_session: NetworkBoardSession = %NetworkBoardSession
@onready var _board_label: Label = %NetworkBoardLabel
@onready var _hash_label: Label = %NetworkBoardHashLabel
@onready var _start_button: Button = %NetworkBoardStartButton
@onready var _turn_button: Button = %NetworkBoardTurnButton

var _local_active_player_id := ""


func _ready() -> void:
	_board_session.board_state_changed.connect(_refresh)
	_board_session.board_active_changed.connect(_on_board_active_changed)
	_match_session.session_state_changed.connect(_refresh)
	_lobby_session.slots_structure_changed.connect(_refresh)
	_start_button.pressed.connect(_on_start_pressed)
	_turn_button.pressed.connect(_on_turn_pressed)
	_refresh()


func _on_board_active_changed(_is_active: bool) -> void:
	_refresh()


func _on_start_pressed() -> void:
	_board_session.request_start_board()


func _on_turn_pressed() -> void:
	if _local_active_player_id == "":
		return
	_board_session.request_advance_turn(_local_active_player_id)


func _refresh() -> void:
	var in_session := _match_session.is_session_established()
	self.visible = in_session

	if not in_session:
		return

	_start_button.visible = _match_session.is_server()
	_start_button.disabled = _board_session.is_board_active() or _lobby_session.slots.is_empty()

	_local_active_player_id = ""
	if _board_session.is_board_active() and _board_session.can_local_player_advance_turn():
		_local_active_player_id = _board_session.get_active_player_id()

	_turn_button.disabled = _local_active_player_id == ""
	_board_label.text = _build_board_summary()
	_hash_label.text = "board hash %d" % _board_session.get_board_state_hash()


func _build_board_summary() -> String:
	if not _board_session.is_board_active():
		return "Board idle. Host starts the stub board when lobby slots are ready."

	var stub := _board_session.board_stub
	if stub.beans_by_player_id.is_empty():
		return "Board stub not initialized."

	var parts: PackedStringArray = PackedStringArray()
	parts.append("Turn %d" % stub.turn_index)
	parts.append("active %s" % stub.active_player_id)
	for slot in _board_session.get_board_slots():
		var beans := int(stub.beans_by_player_id.get(slot.player_id, 0))
		parts.append("%s: %d beans" % [slot.display_name, beans])
	return " · ".join(parts)
