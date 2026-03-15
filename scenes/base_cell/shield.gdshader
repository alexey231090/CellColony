shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 1.0, 0.5, 0.1);
uniform float line_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float scale : hint_range(1.0, 50.0) = 15.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

// Функция для правильных сот (шестигранников)
float hex_dist(vec2 p) {
	p = abs(p);
	float d = dot(p, normalize(vec2(1.0, 1.73205)));
	return max(d, p.x);
}

void fragment() {
	vec2 uv = UV;
	
	// Смещение от центра (от -0.5 до 0.5)
	vec2 center_uv = uv - vec2(0.5);
	float dist_from_center = length(center_uv);
	
	// 1. Быстрая зубчатая рябь краев барьера (Искажение/Wobble)
	float angle = atan(center_uv.y, center_uv.x);
	float wobble = sin(angle * 12.0 + TIME * -8.0) * 0.01;
	wobble += sin(angle * 5.0 + TIME * 5.0) * 0.015; // Двойная частота
	float radius = 0.42; // Чуть меньше 0.5 чтобы не обрезалось квадратом
	
	// Мягкая маска купола со сглаживанием
	float mask = smoothstep(radius + 0.03 + wobble, radius - 0.03 + wobble, dist_from_center);
	
	// 2. Эффект краевого свечения (Rim Light) создаёт иллюзию шара (3D)
	// Чем ближе к краю (к radius), тем ярче (rim ~ 1.0). В центре более прозрачно (rim ~ 0.0)
	float rim = smoothstep(0.1, radius + 0.05, dist_from_center);
	
	// 3. Анимация "стекания" энергетических сот
	vec2 scroll_uv = uv;
	scroll_uv.y -= TIME * 0.35; // Смещение вниз
	// Легкое искажение сетки к центру (имитация линзы/выпуклости)
	scroll_uv += center_uv * dist_from_center * 0.3;
	
	// Математика сетки гексагонов
	vec2 s = vec2(1.0, 1.73205);
	vec2 h = s * 0.5;
	vec2 p = scroll_uv * scale;
	
	vec2 a = mod(p, s) - h;
	vec2 b = mod(p - h, s) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	
	// Правильное использование дистанции до краев сот
	float d = hex_dist(gv);
	
	// Пульсация толщины линий
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.3 + 0.7;
	
	// Динамическое мерцание горизонтальными волнами (переливы энергии)
	float flicker = clamp((sin(scroll_uv.y * 30.0 + TIME * -5.0) + 1.0) * 0.5, 0.4, 1.0);
	
	// 4. Отрисовка линий сот: края гексагона на 0.5
	float edge = smoothstep(0.48 - line_thickness * pulse, 0.5, d);
	edge *= flicker; // Применяем мерцание волнами
	
	// Собираем базовый цвет купола
	vec4 hex_field = mix(vec4(0.0), line_color, edge);
	
	// Добавляем мощное свечение на края (Rim) + внутреннюю заливку (fill_color)
	vec4 final_color = hex_field + (line_color * rim * 1.5) + (fill_color * (1.0 - rim * 0.5));
	
	// Применение маски: края мягко исчезают
	COLOR = final_color;
	// Делаем края плотнее для лучшей видимости границ, центр чуть прозрачнее
	COLOR.a *= mask * line_color.a * clamp(0.4 + rim * 0.8, 0.0, 1.0);
}
