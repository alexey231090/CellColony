extends Control

@onready var shield_button: Button = $HBoxContainer/ShieldButton
@onready var energy_label: Label = $EnergyLabel
@onready var cooldown_bar: ProgressBar = $HBoxContainer/ShieldButton/CooldownBar

var speed_button: Button
var speed_cooldown_bar: ProgressBar
var rapid_button: Button
var rapid_cooldown_bar: ProgressBar
var virus_button: Button
var virus_cooldown_bar: ProgressBar

var normal_style: StyleBoxFlat
var highlight_style: StyleBoxFlat

func _ready() -> void:
	add_to_group("perks_ui")
	shield_button.pressed.connect(_on_shield_pressed)
	
	# Красивый стиль для кнопок (Синий/Зеленый по умолчанию)
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.6, 0.2, 0.8)
	normal_style.border_width_bottom = 4
	normal_style.border_color = Color(0.05, 0.4, 0.1, 0.8)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.8, 0.3, 0.9)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.05, 0.4, 0.1, 0.9)
	pressed_style.border_width_bottom = 0
	pressed_style.content_margin_top = 4 # Кнопка "нажимается"
	
	shield_button.add_theme_stylebox_override("normal", normal_style)
	shield_button.add_theme_stylebox_override("hover", hover_style)
	shield_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Стиль для выделенной кнопки (желтоватый)
	highlight_style = normal_style.duplicate()
	highlight_style.bg_color = Color(0.9, 0.8, 0.1, 0.9) # Желтый
	highlight_style.border_color = Color(0.6, 0.5, 0.0, 0.9)
	
	# Стиль для EnergyLabel
	if energy_label:
		var els = LabelSettings.new()
		els.font_size = 24
		els.font_color = Color(1.0, 0.9, 0.3, 1.0) # Желтый
		els.outline_size = 8
		els.outline_color = Color(0.1, 0.1, 0.1, 0.9)
		energy_label.label_settings = els
		
	# Стиль для CooldownBar (полупрозрачная заливка)
	if cooldown_bar:
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0, 0, 0, 0.5) # Темный оверлей
		cooldown_bar.add_theme_stylebox_override("fill", fill)
		var empty = StyleBoxFlat.new()
		empty.bg_color = Color(0, 0, 0, 0) # Прозрачный фон
		cooldown_bar.add_theme_stylebox_override("background", empty)
		cooldown_bar.value = 0
		cooldown_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm:
		shield_button.text = "1 | 🛡 Щит\n+50%% (%d)" % int(sm.SHIELD_ENERGY_COST)
	else:
		shield_button.text = "1 | 🛡 Щит\n+50% (20)"
	
	# === Создание кнопок динамически ===
	_setup_speed_button()
	_setup_rapid_button()

func _setup_speed_button() -> void:
	var hbox = $HBoxContainer
	if not hbox: return
	
	speed_button = Button.new()
	speed_button.name = "SpeedButton"
	
	speed_button.focus_mode = Control.FOCUS_NONE
	
	# Используем ТЕ ЖЕ стили, что и для Щита
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.8, 0.3, 0.9)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.05, 0.4, 0.1, 0.9)
	pressed_style.border_width_bottom = 0
	pressed_style.content_margin_top = 4
	
	speed_button.add_theme_stylebox_override("normal", normal_style)
	speed_button.add_theme_stylebox_override("hover", hover_style)
	speed_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Копируем настройки шрифта из ShieldButton (как в .tscn)
	speed_button.add_theme_font_size_override("font_size", 18)
	speed_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	speed_button.add_theme_constant_override("outline_size", 6)
	
	speed_button.custom_minimum_size = Vector2(120, 80) # Тот же размер, что у ShieldButton (из .tscn)
	
	# Настройка Progressbar для кулдауна (точно так же, как в сцене для Щита)
	speed_cooldown_bar = ProgressBar.new()
	speed_cooldown_bar.name = "CooldownBar"
	speed_cooldown_bar.show_percentage = false
	speed_cooldown_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Растягиваем на всю кнопку
	speed_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE # Чтобы не мешала клику
	speed_cooldown_bar.value = 0
	speed_cooldown_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	var s_fill = StyleBoxFlat.new()
	s_fill.bg_color = Color(0, 0, 0, 0.5)
	speed_cooldown_bar.add_theme_stylebox_override("fill", s_fill)
	var s_empty = StyleBoxFlat.new()
	s_empty.bg_color = Color(0, 0, 0, 0)
	speed_cooldown_bar.add_theme_stylebox_override("background", s_empty)
	
	speed_button.add_child(speed_cooldown_bar)
	
	# Текст кнопки (динамический)
	var sm = get_tree().get_first_node_in_group("selection_manager")
	var stats = CellStats.new() # Берем дефолтные значения из ресурса для текста
	if sm:
		speed_button.text = "2 | ⚡ Спринт\nx%.1f (%d)" % [sm.SPEED_BOOST_MULTIPLIER, int(sm.SPEED_ENERGY_COST)]
	else:
		speed_button.text = "2 | ⚡ Спринт\nx2 (15)"
	
	# Добавляем в контейнер
	hbox.add_child(speed_button)
	
	# Подключаем сигнал
	speed_button.pressed.connect(_on_speed_pressed)

func _setup_rapid_button() -> void:
	var hbox = $HBoxContainer
	if not hbox: return
	
	rapid_button = Button.new()
	rapid_button.name = "RapidButton"
	rapid_button.focus_mode = Control.FOCUS_NONE
	
	# Используем ТЕ ЖЕ стили
	rapid_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.15, 0.8, 0.3, 0.9)
	rapid_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.05, 0.4, 0.1, 0.9)
	pressed_style.border_width_bottom = 0
	pressed_style.content_margin_top = 4
	rapid_button.add_theme_stylebox_override("pressed", pressed_style)
	
	rapid_button.add_theme_font_size_override("font_size", 18)
	rapid_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rapid_button.add_theme_constant_override("outline_size", 6)
	rapid_button.custom_minimum_size = Vector2(120, 80)
	
	rapid_cooldown_bar = ProgressBar.new()
	rapid_cooldown_bar.name = "CooldownBar"
	rapid_cooldown_bar.show_percentage = false
	rapid_cooldown_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rapid_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rapid_cooldown_bar.value = 0
	rapid_cooldown_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	var s_fill = StyleBoxFlat.new()
	s_fill.bg_color = Color(0, 0, 0, 0.5)
	rapid_cooldown_bar.add_theme_stylebox_override("fill", s_fill)
	var s_empty = StyleBoxFlat.new()
	s_empty.bg_color = Color(0, 0, 0, 0)
	rapid_cooldown_bar.add_theme_stylebox_override("background", s_empty)
	
	rapid_button.add_child(rapid_cooldown_bar)
	
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm:
		rapid_button.text = "3 | 🔥 Огонь\nx%.1f (%d)" % [sm.RAPID_FIRE_MULTIPLIER, int(sm.RAPID_FIRE_ENERGY_COST)]
	else:
		rapid_button.text = "3 | 🔥 Огонь\nx3 (25)"
	
	hbox.add_child(rapid_button)
	rapid_button.pressed.connect(_on_rapid_pressed)
	
	_setup_virus_button()

func _setup_virus_button() -> void:
	var hbox = $HBoxContainer
	if not hbox: return
	
	virus_button = Button.new()
	virus_button.name = "VirusButton"
	virus_button.focus_mode = Control.FOCUS_NONE
	
	# Стиль для Вируса (Красновато-бордовый)
	var v_normal = normal_style.duplicate()
	v_normal.bg_color = Color(0.6, 0.1, 0.1, 0.8) # Темно-красный
	v_normal.border_color = Color(0.4, 0.05, 0.05, 0.8)
	
	var v_hover = v_normal.duplicate()
	v_hover.bg_color = Color(0.8, 0.15, 0.15, 0.9)
	
	var v_pressed = v_normal.duplicate()
	v_pressed.bg_color = Color(0.4, 0.05, 0.05, 0.9)
	v_pressed.border_width_bottom = 0
	v_pressed.content_margin_top = 4
	
	virus_button.add_theme_stylebox_override("normal", v_normal)
	virus_button.add_theme_stylebox_override("hover", v_hover)
	virus_button.add_theme_stylebox_override("pressed", v_pressed)
	
	virus_button.add_theme_font_size_override("font_size", 18)
	virus_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	virus_button.add_theme_constant_override("outline_size", 6)
	virus_button.custom_minimum_size = Vector2(120, 80)
	
	virus_cooldown_bar = ProgressBar.new()
	virus_cooldown_bar.name = "CooldownBar"
	virus_cooldown_bar.show_percentage = false
	virus_cooldown_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	virus_cooldown_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	virus_cooldown_bar.value = 0
	virus_cooldown_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	var s_fill = StyleBoxFlat.new()
	s_fill.bg_color = Color(0, 0, 0, 0.5)
	virus_cooldown_bar.add_theme_stylebox_override("fill", s_fill)
	var s_empty = StyleBoxFlat.new()
	s_empty.bg_color = Color(0, 0, 0, 0)
	virus_cooldown_bar.add_theme_stylebox_override("background", s_empty)
	
	virus_button.add_child(virus_cooldown_bar)
	
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm:
		virus_button.text = "4 | 💀 Вирус\n(%d)" % int(sm.VIRUS_ENERGY_COST)
	else:
		virus_button.text = "4 | 💀 Вирус\n(30)"
	
	hbox.add_child(virus_button)
	virus_button.pressed.connect(_on_virus_pressed)

func set_button_highlight(perk_id: String, is_active: bool) -> void:
	if perk_id == "shield":
		if is_active:
			shield_button.add_theme_stylebox_override("normal", highlight_style)
		else:
			# Возвращаем обычный стиль
			shield_button.add_theme_stylebox_override("normal", normal_style)
	elif perk_id == "speed" and speed_button:
		# Для мгновенных перков подсветка может не понадобиться, 
		# но добавим для консистентности или визуального "пшика"
		pass 

func update_perk_status(energy: float, cd_ratio: float, speed_cd_ratio: float, rapid_cd_ratio: float = 0.0, virus_cd_ratio: float = 0.0) -> void:
	if energy_label:
		# Округляем до 1 знака для красоты
		energy_label.text = "⚡ ЭНЕРГИЯ: " + str(roundi(energy))
	
	if cooldown_bar:
		cooldown_bar.value = cd_ratio * 100.0
		# Если кулдаун есть — кнопка кажется неактивной
		if cd_ratio > 0:
			shield_button.modulate.a = 0.6
		else:
			shield_button.modulate.a = 1.0
			
	# Обновление UI для ускорения
	if speed_cooldown_bar:
		speed_cooldown_bar.value = speed_cd_ratio * 100.0
		if speed_button:
			if speed_cd_ratio > 0:
				speed_button.modulate.a = 0.6
			else:
				speed_button.modulate.a = 1.0
				
	# Обновление UI для скорострельности
	if rapid_cooldown_bar:
		rapid_cooldown_bar.value = rapid_cd_ratio * 100.0
		if rapid_button:
			if rapid_cd_ratio > 0:
				rapid_button.modulate.a = 0.6
			else:
				rapid_button.modulate.a = 1.0
				
	# Обновление UI для вируса
	if virus_cooldown_bar:
		virus_cooldown_bar.value = virus_cd_ratio * 100.0
		if virus_button:
			if virus_cd_ratio > 0:
				virus_button.modulate.a = 0.6
			else:
				virus_button.modulate.a = 1.0

func _on_shield_pressed() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.has_method("activate_perk"):
		sm.activate_perk("shield")

func _on_speed_pressed() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.has_method("activate_perk"):
		sm.activate_perk("speed")

func _on_rapid_pressed() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.has_method("activate_perk"):
		sm.activate_perk("rapid_fire")

func _on_virus_pressed() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.has_method("activate_perk"):
		sm.activate_perk("virus")
