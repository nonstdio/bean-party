class_name NetworkMatchRecovery
extends RefCounted

const TOKEN_BYTE_LENGTH := 32


static func generate_session_id() -> String:
	return "recovery_%s" % _random_hex(16)


static func generate_reconnect_token() -> String:
	return _random_hex(TOKEN_BYTE_LENGTH)


static func hash_token(token: String) -> String:
	if token == "":
		return ""

	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(token.to_utf8_buffer())
	return context.finish().hex_encode()


static func tokens_match(stored_hash: String, presented_token: String) -> bool:
	if stored_hash == "" or presented_token == "":
		return false
	return stored_hash == hash_token(presented_token)


static func _random_hex(byte_length: int) -> String:
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(byte_length)
	return bytes.hex_encode()
