@tool
extends EditorPlugin

const PANEL_SCENE := preload("res://addons/ai_profiler_export/profiler_export_panel.tscn")
const DEBUGGER_SCRIPT := preload("res://addons/ai_profiler_export/profiler_debugger_plugin.gd")

var _panel: Control
var _debugger_plugin
var _bottom_button: Button


func _enter_tree() -> void:
	_panel = PANEL_SCENE.instantiate()
	_panel.plugin = self
	_panel.hide()

	_debugger_plugin = DEBUGGER_SCRIPT.new()
	_debugger_plugin.panel = _panel

	add_debugger_plugin(_debugger_plugin)
	_bottom_button = add_control_to_bottom_panel(_panel, "AI Profiler")
	add_tool_menu_item("AI Profiler Export/Copy Markdown Snapshot", _request_copy)


func _exit_tree() -> void:
	remove_tool_menu_item("AI Profiler Export/Copy Markdown Snapshot")

	if _bottom_button:
		remove_control_from_bottom_panel(_panel)

	if _debugger_plugin:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null

	if _panel:
		_panel.queue_free()
		_panel = null


func request_snapshot() -> bool:
	if _debugger_plugin == null:
		return false
	return _debugger_plugin.request_snapshot()


func _request_copy() -> void:
	if not _panel:
		return
	make_bottom_panel_item_visible(_panel)
	_panel.request_snapshot_copy()
