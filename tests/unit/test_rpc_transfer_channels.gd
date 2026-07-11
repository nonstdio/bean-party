extends GutTest


func _rpc_config(node: Node, method: String) -> Dictionary:
	var node_script: Variant = node.get_script()
	if node_script == null:
		return {}
	var config: Variant = node_script.get_rpc_config()
	if config is not Dictionary:
		return {}
	var method_config: Variant = config.get(method)
	if method_config is not Dictionary:
		return {}
	return method_config


func test_session_control_rpcs_use_channel_zero_and_reliable() -> void:
	var cases: Array = [
		[MatchSession.new(), "_rpc_echo"],
		[NetworkLobbySession.new(), "_rpc_request_add_slot"],
		[NetworkBoardSession.new(), "_rpc_request_advance_turn"],
		[NetworkMatchPhaseSession.new(), "_rpc_request_briefing_ready"],
	]
	for entry in cases:
		var node: Node = entry[0]
		add_child_autofree(node)
		var config := _rpc_config(node, entry[1])
		assert_eq(
			int(config.get("channel", -1)),
			TransportMessageLanes.CHANNEL_RPC,
			"%s.%s should use RPC channel 0" % [node.get_class(), entry[1]],
		)
		assert_eq(
			int(config.get("transfer_mode", -1)),
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			"%s.%s should use reliable delivery" % [node.get_class(), entry[1]],
		)


func test_input_rpcs_use_channel_zero_and_unreliable_ordered() -> void:
	var cases: Array = [
		[NetworkActionMinigameSession.new(), "_rpc_submit_input"],
		[NetworkMinigameSession.new(), "_rpc_submit_input"],
	]
	for entry in cases:
		var node: Node = entry[0]
		add_child_autofree(node)
		var config := _rpc_config(node, entry[1])
		assert_eq(int(config.get("channel", -1)), TransportMessageLanes.CHANNEL_RPC)
		assert_eq(int(config.get("transfer_mode", -1)), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)


func test_snapshot_rpcs_use_channel_zero_and_unreliable() -> void:
	var cases: Array = [
		[NetworkActionMinigameSession.new(), "_rpc_apply_snapshot"],
		[NetworkMinigameSession.new(), "_rpc_apply_snapshot"],
	]
	for entry in cases:
		var node: Node = entry[0]
		add_child_autofree(node)
		var config := _rpc_config(node, entry[1])
		assert_eq(int(config.get("channel", -1)), TransportMessageLanes.CHANNEL_RPC)
		assert_eq(int(config.get("transfer_mode", -1)), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
