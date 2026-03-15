shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.02, 0.05, 0.1, 1.0);
uniform vec4 color2 : source_color = vec4(0.05, 0.15, 0.25, 1.0);
uniform float speed = 0.5;
uniform float scale = 3.0;
uniform vec2 cam_offset = vec2(0.0, 0.0);

// Функция для генерации случайных чисел
vec2 random2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Биологический 'клеточный' шум
float cellular_noise(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float min_dist = 1.0;
	
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = random2(n + g);
			// Анимация движения "клеток"
			o = 0.5 + 0.5 * sin(TIME * speed + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r); // Квадрат расстояния
			if (d < min_dist) {
				min_dist = d;
			}
		}
	}
	return min_dist;
}

void fragment() {
	// Основные координаты с учетом экрана и масштаба (плюс смещение камеры)
	vec2 uv = ((FRAGCOORD.xy + cam_offset) / 1000.0) * scale;
	
	// Главный клеточный шум (крупный)
	float noise_val = cellular_noise(uv);
	
	// Мелкий шум (завихрения)
	float detail_noise = cellular_noise(uv * 2.5 - vec2(TIME * 0.2, TIME * -0.1));
	
	// Смешивание цветов
	// Инвертируем шум, чтобы "клетки" выделялись темным, а промежутки светлым
	float t = 1.0 - smoothstep(0.0, 0.6, noise_val);
	// Добавляем детали
	t += (1.0 - detail_noise) * 0.2;
	
	vec4 final_color = mix(color1, color2, clamp(t, 0.0, 1.0));
	
	// Микрочастицы (пылинки/органеллы, плавающие в жидкости)
	// Оставили только самые редкие и тусклые точки
	float particles = smoothstep(0.995, 0.999, 1.0 - cellular_noise(uv * 12.0 + vec2(TIME * 0.15)));
	final_color.rgb += vec3(particles * 0.03); 
	
	COLOR = final_color;
}
