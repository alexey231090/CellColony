extends Control

@onready var shield_button: Button = $HBoxContainer/ShieldButton
@onready var energy_label: Label = $EnergyLabel
@onready var cooldown_bar: ProgressBar = $HBoxContainer/ShieldButton/CooldownBar

var normal_style: StyleBoxFlat
var highlight_style: StyleBoxFlat

func _ready() -> void:
	add_to_group("perks_ui")
	shield_button.pressed.connect(_on_shield_pressed)
	# Красивый стиль для кнопок
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
	
	shield_button.text = "🛡 Щит\n+50% (20)"

func set_button_highlight(perk_id: String, is_active: bool) -> void:
	if perk_id == "shield":
		if is_active:
			shield_button.add_theme_stylebox_override("normal", highlight_style)
		else:
			# Возвращаем обычный стиль
			shield_button.add_theme_stylebox_override("normal", normal_style)

func update_perk_status(energy: float, cd_ratio: float) -> void:
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
	
	# Если энергии не хватает — затемняем текст (?)
	# Пока оставим так.


func _on_shield_pressed() -> void:
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.has_method("activate_perk"):
		sm.activate_perk("shield")
