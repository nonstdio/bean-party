class_name NetworkMatchRecovery
extends RefCounted


static func generate_session_id() -> String:
	return "recovery_%d_%d" % [Time.get_ticks_msec(), randi()]


static func generate_reconnect_token() -> String:
	return "%d-%d-%d" % [randi(), randi(), randi()]


static func tokens_match(expected: String, presented: String) -> bool:
	return expected != "" and presented != "" and expected == presented
