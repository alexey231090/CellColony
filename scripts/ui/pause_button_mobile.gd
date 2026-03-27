extends Control
class_name PauseButtonMobile
## PauseButtonMobile - Стильная круглая кнопка паузы в стиле перков
## Поддерживает эффекты объема, тени и анимацию нажатия

# --- Константы ---
const BUTTON_SIZE: float = 68.0
const ICON_SIZE: float = 24.0

# --- Состояние анимации ---
var visual_scale: float = 1.0
var target_scale: float = 1.0

# --- Ссылки ---
var pause_menu: Node = null

# --- StyleBoxes ---
var style_circle = StyleBoxFlat.new()

signal pressed_btn

func _ready() -> void:
    custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
    pivot_offset = Vector2(BUTTON_SIZE/2.0, BUTTON_SIZE / 2.0)
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    # Общая настройка круглой формы в стиле перков
    style_circle.set_corner_radius_all(int(BUTTON_SIZE / 2.0))
    style_circle.shadow_color = Color(0, 0, 0, 0.5)
    style_circle.shadow_size = 6
    style_circle.shadow_offset = Vector2(0, 3)
    
    # Реакция на ввод (и мышь, и тач)
    gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb = event as InputEventMouseButton
        if mb.button_index != MOUSE_BUTTON_LEFT: return
        
        if mb.pressed:
            target_scale = 0.85
            _on_tap()
        else:
            target_scale = 1.0
        get_viewport().set_input_as_handled()
    
    elif event is InputEventScreenTouch:
        if event.pressed:
            target_scale = 0.85
            _on_tap()
        else:
            target_scale = 1.0
        get_viewport().set_input_as_handled()

func _on_tap() -> void:
    # Испускаем сигнал нажатия
    pressed_btn.emit()

func _process(delta: float) -> void:
    # Плавное изменение размера при нажатии
    visual_scale = lerp(visual_scale, target_scale, delta * 20.0)
    scale = Vector2(visual_scale, visual_scale)
    queue_redraw()

func _draw() -> void:
    var center = Vector2(BUTTON_SIZE / 2.0, BUTTON_SIZE / 2.0)
    var radius = BUTTON_SIZE / 2.0 - 4.0
    
    # 1. Свечение (Glow)
    var glow_color = Color(0.1, 0.85, 0.55, 0.2)
    draw_circle(center, radius + 4.0, glow_color)
    
    # 2. Основная форма (Glassmorphism)
    style_circle.bg_color = Color(0.1, 0.12, 0.16, 0.85)
    style_circle.border_width_left = 2
    style_circle.border_width_right = 2
    style_circle.border_width_top = 2
    style_circle.border_width_bottom = 2
    style_circle.border_color = Color(0.1, 0.85, 0.55, 0.45)
    draw_style_box(style_circle, Rect2(0, 0, BUTTON_SIZE, BUTTON_SIZE))
    
    # 3. Иконка паузы (две полоски ||)
    var icon_color = Color.WHITE
    var bar_w = 7.0
    var bar_h = 26.0
    var gap = 9.0
    
    # Левая полоска
    draw_rect(Rect2(center.x - gap/2.0 - bar_w, center.y - bar_h/2.0, bar_w, bar_h), icon_color)
    # Правая полоска
    draw_rect(Rect2(center.x + gap/2.0, center.y - bar_h/2.0, bar_w, bar_h), icon_color)
