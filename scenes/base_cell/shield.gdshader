shader_type canvas_item;

uniform vec4 shield_color : source_color = vec4(0.3, 1.0, 0.4, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float hit_pulse : hint_range(0.0, 1.0) = 0.0;
uniform bool sprint_mode = false;
uniform float aura_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float sprint_angle = 0.0; // Направление движения

// Функция для правильных сот (шестигранников)
float hex_dist(vec2 p) {
	p = abs(p);
	float d = dot(p, normalize(vec2(1.0, 1.73205)));
	return max(d, p.x);
}

// Псевдо-случайная функция
float rand(float n){return fract(sin(n) * 43758.5453123);}

void fragment() {
	vec2 uv = UV;
	vec2 center_uv = uv - vec2(0.5);
	float dist_from_center = length(center_uv);
	
	if (sprint_mode) {
		// РЕЖИМ СПРИНТА: Эффект скорости (дождевые капли / спидлайны)
		// Поворачиваем UV на угол движения (sprint_angle)
		float c = cos(-sprint_angle);
		float s = sin(-sprint_angle);
		vec2 rot_uv = vec2(
			center_uv.x * c - center_uv.y * s,
			center_uv.x * s + center_uv.y * c
		);
		
		float lines = 0.0;
		// Генерируем 4 полоски
		for (float i = 1.0; i <= 4.0; i++) {
			// Рандомное смещение по высоте для каждой полоски
			float offset_y = (rand(i) - 0.5) * 0.7; 
			// Скорость с небольшим разбросом
			float speed_scale = 1.5 + rand(i * 1.5) * 1.0;
			
			// Полоски "стекают" назад (подвижность)
			float flow_x = rot_uv.x + TIME * (2.0 * speed_scale) + rand(i * 2.0);
			flow_x = fract(flow_x) - 0.5; // Сброс от -0.5 до 0.5
			
			// Ограничиваем линии кругом, чтобы они не выходили за радиус
			float circle_mask = smoothstep(0.48, 0.4, dist_from_center);
			
			// Толщина линии (маска по Y)
			float dy = abs(rot_uv.y - offset_y);
			float mask_y = smoothstep(0.02, 0.0, dy);
			
			// Маска по X (форма капли-полоски: тупая спереди, сужается сзади)
			// flow_x > 0 это хвост, flow_x < 0 это нос летящей капли
			float mask_x = smoothstep(-0.2, 0.0, flow_x) * smoothstep(0.15, -0.05, flow_x);
			
			lines += mask_y * mask_x * circle_mask;
		}
		
		COLOR = shield_color;
		COLOR.a = clamp(lines, 0.0, 1.0) * aura_intensity * intensity;
	} else {
		// РЕЖИМ ЩИТА: Шестигранное поле
		float angle = atan(center_uv.y, center_uv.x);
		float wobble = sin(angle * 12.0 + TIME * -8.0) * 0.01;
		wobble += sin(angle * 5.0 + TIME * 5.0) * 0.015;
		float radius = 0.42;
		
		float mask = smoothstep(radius + 0.03 + wobble, radius - 0.03 + wobble, dist_from_center);
		float rim = smoothstep(0.1, radius + 0.05, dist_from_center);
		
		vec2 scroll_uv = uv;
		scroll_uv.y -= TIME * 0.35;
		scroll_uv += center_uv * dist_from_center * 0.3;
		
		float scale = 15.0;
		vec2 s = vec2(1.0, 1.73205);
		vec2 h = s * 0.5;
		vec2 p = scroll_uv * scale;
		
		vec2 a = mod(p, s) - h;
		vec2 b = mod(p - h, s) - h;
		vec2 gv = dot(a, a) < dot(b, b) ? a : b;
		
		float d = hex_dist(gv);
		float line_thickness = 0.05;
		float edge = smoothstep(0.48 - line_thickness, 0.5, d);
		
		vec4 final_color = mix(vec4(0.0), shield_color, edge);
		final_color += (shield_color * rim * 1.5);
		final_color += (shield_color * 0.2 * (1.0 - rim)); // Внутренняя заливка
		
		COLOR = final_color;
		COLOR.a *= mask * clamp(0.4 + rim * 0.8, 0.0, 1.0) * intensity;
	}
}
