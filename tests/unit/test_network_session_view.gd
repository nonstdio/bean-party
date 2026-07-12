extends GutTest


func _network_session_view() -> Node:
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	return main.get_node("Margin/Scroll/Content/NetworkSession")


func test_release_webrtc_host_shows_unconfigured_message() -> void:
	var view := _network_session_view()
	view._online_config_probe = {
		"development_mode": false,
		"signaling_url": "",
		"ice_config_url": "",
	}
	view._select_transport_mode(view.TransportMode.WEBRTC)
	view._signaling_url_field.text = ""
	view._host_webrtc()
	assert_eq(view._status_label.text, OnlineServiceConfig.unconfigured_message())


func test_release_webrtc_join_shows_unconfigured_message() -> void:
	var view := _network_session_view()
	view._online_config_probe = {
		"development_mode": false,
		"signaling_url": "",
		"ice_config_url": "",
	}
	view._select_transport_mode(view.TransportMode.WEBRTC)
	view._signaling_url_field.text = ""
	view._room_code_field.text = "room-code"
	view._join_webrtc()
	assert_eq(view._status_label.text, OnlineServiceConfig.unconfigured_message())
