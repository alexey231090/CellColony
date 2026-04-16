extends Node

const CAPTURE_PREFIX := "ai_profiler"
const SAMPLE_INTERVAL_SEC := 0.25
const MAX_SAMPLES := 120
const MAX_SPIKES := 5

var _samples: Array[Dictionary] = []
var _elapsed_since_sample := 0.0
var _session_elapsed := 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		return

	EngineDebugger.register_message_capture(CAPTURE_PREFIX, _capture_editor_message)
	set_process(true)
	_record_sample()


func _process(delta: float) -> void:
	_session_elapsed += delta
	_elapsed_since_sample += delta
	if _elapsed_since_sample < SAMPLE_INTERVAL_SEC:
		return

	_elapsed_since_sample = 0.0
	_record_sample()


func _capture_editor_message(message: String, _data: Array) -> bool:
	if message != "request_snapshot":
		return false

	EngineDebugger.send_message("%s:snapshot" % CAPTURE_PREFIX, [_build_snapshot()])
	return true


func _record_sample() -> void:
	_samples.append({
		"elapsed_s": _session_elapsed,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_s": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_time_s": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"physics_2d_active": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_3d_active": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	})

	if _samples.size() > MAX_SAMPLES:
		_samples.remove_at(0)


func _build_snapshot() -> Dictionary:
	var current: Dictionary = {}
	if not _samples.is_empty():
		current = _samples[_samples.size() - 1].duplicate(true)

	var summary := {
		"avg_fps": _average("fps"),
		"min_fps": _minimum("fps"),
		"avg_frame_time_s": _average("frame_time_s"),
		"max_frame_time_s": _maximum("frame_time_s"),
		"avg_physics_time_s": _average("physics_time_s"),
		"avg_non_physics_time_s": max(_average("frame_time_s") - _average("physics_time_s"), 0.0),
		"avg_draw_calls": _average("draw_calls"),
		"max_draw_calls": int(_maximum("draw_calls")),
		"max_static_memory": _maximum("static_memory"),
		"memory_delta": _last_minus_first("static_memory")
	}

	return {
		"captured_at": Time.get_datetime_string_from_system(),
		"scene": _get_scene_name(),
		"window_seconds": SAMPLE_INTERVAL_SEC * _samples.size(),
		"sample_count": _samples.size(),
		"current": current,
		"summary": summary,
		"spikes": _get_worst_frames(),
		"notes": _build_notes(summary, current)
	}


func _get_scene_name() -> String:
	var tree := get_tree()
	if tree == null:
		return "unknown"
	var current_scene := tree.current_scene
	if current_scene == null:
		return "unknown"
	if current_scene.scene_file_path.is_empty():
		return current_scene.name
	return current_scene.scene_file_path


func _build_notes(summary: Dictionary, current: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var avg_frame_time := float(summary.get("avg_frame_time_s", 0.0))
	var avg_physics_time := float(summary.get("avg_physics_time_s", 0.0))
	var avg_non_physics_time := float(summary.get("avg_non_physics_time_s", 0.0))
	var avg_draw_calls := float(summary.get("avg_draw_calls", 0.0))
	var min_fps := float(summary.get("min_fps", 9999.0))
	var memory_delta := float(summary.get("memory_delta", 0.0))

	if float(summary.get("min_fps", 9999.0)) < 50.0:
		notes.append("FPS dropped below 50 during the captured window.")
	if float(summary.get("max_frame_time_s", 0.0)) > 0.02:
		notes.append("At least one frame exceeded 20 ms.")
	if int(summary.get("max_draw_calls", 0)) > 1500:
		notes.append("Draw call count is high and may be CPU-side rendering overhead.")
	if avg_frame_time > 0.0 and avg_non_physics_time > avg_physics_time * 2.0:
		notes.append("Physics is a relatively small part of frame time; the main bottleneck is more likely rendering, scripts on the main thread, or GPU cost.")
	if min_fps < 35.0 and avg_draw_calls < 900.0:
		notes.append("FPS is low even though draw calls are not extreme, so script work, overdraw, shaders, or GPU fill-rate are worth checking next.")
	if memory_delta > 8.0 * 1024.0 * 1024.0:
		notes.append("Static memory increased noticeably during the sampled window, which may indicate allocations or content streaming spikes.")
	if int(current.get("orphan_node_count", 0)) > 0:
		notes.append("Orphan nodes are present, which can indicate leaked nodes.")
	if notes.is_empty():
		notes.append("No obvious red flags were detected in the sampled window; inspect worst frames for spikes.")
	return notes


func _get_worst_frames() -> Array[Dictionary]:
	var sorted_samples: Array[Dictionary] = []
	for sample in _samples:
		sorted_samples.append(sample)

	if sorted_samples.is_empty():
		return sorted_samples

	sorted_samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("frame_time_s", 0.0)) > float(b.get("frame_time_s", 0.0))
	)

	if sorted_samples.size() > MAX_SPIKES:
		sorted_samples.resize(MAX_SPIKES)
	return sorted_samples


func _average(key: String) -> float:
	if _samples.is_empty():
		return 0.0
	var total := 0.0
	for sample in _samples:
		total += float(sample.get(key, 0.0))
	return total / _samples.size()


func _minimum(key: String) -> float:
	if _samples.is_empty():
		return 0.0
	var result := float(_samples[0].get(key, 0.0))
	for sample in _samples:
		result = min(result, float(sample.get(key, 0.0)))
	return result


func _maximum(key: String) -> float:
	if _samples.is_empty():
		return 0.0
	var result := float(_samples[0].get(key, 0.0))
	for sample in _samples:
		result = max(result, float(sample.get(key, 0.0)))
	return result


func _last_minus_first(key: String) -> float:
	if _samples.size() < 2:
		return 0.0
	return float(_samples[_samples.size() - 1].get(key, 0.0)) - float(_samples[0].get(key, 0.0))
