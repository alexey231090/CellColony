@tool
extends EditorDebuggerPlugin

var panel: Control


func _has_capture(capture: String) -> bool:
	return capture == "ai_profiler"


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "ai_profiler:snapshot":
		return false

	if panel and panel.has_method("receive_snapshot"):
		var payload: Dictionary = {}
		if not data.is_empty() and data[0] is Dictionary:
			payload = data[0]
		panel.receive_snapshot(payload, session_id)
	return true


func request_snapshot() -> bool:
	for session in get_sessions():
		if session and session.is_active():
			session.send_message("ai_profiler:request_snapshot")
			return true
	return false
