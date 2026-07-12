extends Node

## Runs the exported-build WebRTC smoke probe when requested on the command line.


func _ready() -> void:
	if not WebRtcExportSmoke.should_run_from_cmdline():
		return

	var exit_code := WebRtcExportSmoke.run()
	get_tree().call_deferred("quit", exit_code)
