extends Camera2D
## DevFreeCamera: Свободная камера для отладки

@export var speed: float = 1500.0
@export var fast_multiplier: float = 3.0

func _ready() -> void:
	make_current() # Делаем эту камеру активной
	zoom = Vector2(0.5, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom /= 1.1
		# Ограничиваем зум, чтобы не улетать в бесконечность
		zoom.x = clamp(zoom.x, 0.05, 5.0)
		zoom.y = zoom.x

func _process(delta: float) -> void:
	var move_dir = Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_dir.x += 1
	
	var current_speed = speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= fast_multiplier
		
	global_position += move_dir.normalized() * (current_speed / zoom.x) * delta
	
	# Zoom на кнопках Q/E
	if Input.is_key_pressed(KEY_Q): zoom *= 1.02
	if Input.is_key_pressed(KEY_E): zoom /= 1.02
