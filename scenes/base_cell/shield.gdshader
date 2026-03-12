shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 1.0, 0.5, 0.1);
uniform float line_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float scale : hint_range(1.0, 50.0) = 15.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

// Функция для создания гексагональной сетки
// Возвращает расстояние до ближайшего края шестиугольника
float hex_dist(vec2 p) {
	p = abs(p);
	float d = dot(p, normalize(vec2(1.0, 1.73)));
	return max(d, p.x);
}

void fragment() {
	vec2 uv = UV;
	
	// Масштаб сетки
	vec2 s = vec2(1.0, 1.73205);
	vec2 h = s * 0.5;
	vec2 p = uv * scale;
	
	vec2 a = mod(p, s) - h;
	vec2 b = mod(p - h, s) - h;
	
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	
	// Расстояние до центра гексагона
	float d = length(gv);
	
	// Пульсация
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.3 + 0.7;
	
	// Рисуем границы (соты)
	// d в данном случае - это расстояние от центра. Края гексагона примерно на 0.5.
	float edge = smoothstep(0.4, 0.5, d * (1.0 + line_thickness * pulse));
	
	vec4 final_color = mix(fill_color, line_color, edge);
	
	// Мягкая маска круга
	float mask = smoothstep(0.5, 0.45, length(uv - 0.5));
	
	COLOR = final_color;
	COLOR.a *= mask * line_color.a;
}
