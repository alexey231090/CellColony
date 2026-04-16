@tool
extends VBoxContainer

const EMPTY_REPORT := "No snapshot yet. Run the game from the editor in debug mode, then press Copy Markdown Snapshot."

@onready var _status_label: Label = %StatusLabel
@onready var _copy_button: Button = %CopyButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _text_edit: TextEdit = %ReportTextEdit

var plugin: EditorPlugin
var _last_markdown := EMPTY_REPORT
var _awaiting_snapshot := false


func _ready() -> void:
	_text_edit.text = _last_markdown
	_copy_button.pressed.connect(request_snapshot_copy)
	_refresh_button.pressed.connect(_request_snapshot_only)


func request_snapshot_copy() -> void:
	_request_snapshot(true)


func _request_snapshot_only() -> void:
	_request_snapshot(false)


func _request_snapshot(copy_after_receive: bool) -> void:
	_awaiting_snapshot = copy_after_receive
	_status_label.text = "Requesting snapshot from running debug session..."

	if plugin and plugin.request_snapshot():
		return

	_awaiting_snapshot = false
	_status_label.text = "No active debug session found. Start the game with F5/F6 from the editor."


func receive_snapshot(payload: Dictionary, session_id: int) -> void:
	_last_markdown = _build_markdown(payload, session_id)
	_text_edit.text = _last_markdown
	_status_label.text = "Snapshot received."

	if _awaiting_snapshot:
		DisplayServer.clipboard_set(_last_markdown)
		_status_label.text = "Snapshot copied to clipboard."
	_awaiting_snapshot = false


func _build_markdown(payload: Dictionary, session_id: int) -> String:
	var summary: Dictionary = payload.get("summary", {})
	var current: Dictionary = payload.get("current", {})
	var spikes: Array = payload.get("spikes", [])
	var notes: Array = payload.get("notes", [])
	var lines: PackedStringArray = []

	lines.append("# Godot Performance Snapshot")
	lines.append("")
	lines.append("## Context")
	lines.append("- Session ID: %d" % session_id)
	lines.append("- Scene: `%s`" % str(payload.get("scene", "unknown")))
	lines.append("- Captured At: `%s`" % str(payload.get("captured_at", "unknown")))
	lines.append("- Window Seconds: %.1f" % float(payload.get("window_seconds", 0.0)))
	lines.append("- Sample Count: %d" % int(payload.get("sample_count", 0)))
	lines.append("")
	lines.append("## Summary")
	lines.append("- Average FPS: %s" % _format_number(summary.get("avg_fps", 0.0), 1))
	lines.append("- Lowest FPS: %s" % _format_number(summary.get("min_fps", 0.0), 1))
	lines.append("- Highest Frame Time: %s ms" % _format_number(1000.0 * float(summary.get("max_frame_time_s", 0.0)), 2))
	lines.append("- Average Frame Time: %s ms" % _format_number(1000.0 * float(summary.get("avg_frame_time_s", 0.0)), 2))
	lines.append("- Average Physics Time: %s ms" % _format_number(1000.0 * float(summary.get("avg_physics_time_s", 0.0)), 2))
	lines.append("- Average Non-Physics Time: %s ms" % _format_number(1000.0 * float(summary.get("avg_non_physics_time_s", 0.0)), 2))
	lines.append("- Average Draw Calls: %s" % _format_number(summary.get("avg_draw_calls", 0.0), 1))
	lines.append("- Peak Draw Calls: %d" % int(summary.get("max_draw_calls", 0)))
	lines.append("- Peak Static Memory: %s" % _format_bytes(summary.get("max_static_memory", 0.0)))
	lines.append("- Static Memory Delta: %s" % _format_signed_bytes(summary.get("memory_delta", 0.0)))
	lines.append("")
	lines.append("## Current Sample")
	lines.append("- FPS: %s" % _format_number(current.get("fps", 0.0), 1))
	lines.append("- Frame Time: %s ms" % _format_number(1000.0 * float(current.get("frame_time_s", 0.0)), 2))
	lines.append("- Physics Time: %s ms" % _format_number(1000.0 * float(current.get("physics_time_s", 0.0)), 2))
	lines.append("- Draw Calls: %d" % int(current.get("draw_calls", 0)))
	lines.append("- Static Memory: %s" % _format_bytes(current.get("static_memory", 0.0)))
	lines.append("- Video Memory: %s" % _format_bytes(current.get("video_memory", 0.0)))
	lines.append("- Objects: %d" % int(current.get("object_count", 0)))
	lines.append("- Nodes: %d" % int(current.get("node_count", 0)))
	lines.append("- Orphan Nodes: %d" % int(current.get("orphan_node_count", 0)))
	lines.append("- 2D Physics Active Objects: %d" % int(current.get("physics_2d_active", 0)))
	lines.append("- 3D Physics Active Objects: %d" % int(current.get("physics_3d_active", 0)))
	lines.append("")

	if not spikes.is_empty():
		lines.append("## Worst Frames")
		for spike in spikes:
			if spike is Dictionary:
				lines.append("- t=%.2fs | fps=%s | frame=%s ms | physics=%s ms | draw_calls=%d | static_mem=%s" % [
					float(spike.get("elapsed_s", 0.0)),
					_format_number(spike.get("fps", 0.0), 1),
					_format_number(1000.0 * float(spike.get("frame_time_s", 0.0)), 2),
					_format_number(1000.0 * float(spike.get("physics_time_s", 0.0)), 2),
					int(spike.get("draw_calls", 0)),
					_format_bytes(spike.get("static_memory", 0.0))
				])
		lines.append("")

	if not notes.is_empty():
		lines.append("## Notes")
		for note in notes:
			lines.append("- %s" % str(note))
		lines.append("")

	lines.append("## AI Prompt")
	lines.append("Please analyze this Godot performance snapshot, identify likely bottlenecks, and suggest the highest-impact fixes first.")
	return "\n".join(lines)


func _format_number(value: Variant, decimals: int) -> String:
	return ("%0." + str(decimals) + "f") % float(value)


func _format_bytes(value: Variant) -> String:
	var amount := float(value)
	var units := ["B", "KB", "MB", "GB", "TB"]
	var unit_index := 0
	while amount >= 1024.0 and unit_index < units.size() - 1:
		amount /= 1024.0
		unit_index += 1
	return "%0.2f %s" % [amount, units[unit_index]]


func _format_signed_bytes(value: Variant) -> String:
	var amount := float(value)
	if amount >= 0.0:
		return "+%s" % _format_bytes(amount)
	return "-%s" % _format_bytes(abs(amount))
