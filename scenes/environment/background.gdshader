shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 color1 : source_color = vec4(0.02, 0.05, 0.1, 1.0);
uniform vec4 color2 : source_color = vec4(0.05, 0.15, 0.25, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.25;
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform vec2 cam_offset = vec2(0.0, 0.0);

void fragment() {
	// Базовые координаты с учетом масштаба и параллакса камеры
	vec2 uv = ((FRAGCOORD.xy + cam_offset) / 1000.0) * (scale * 0.25);
	
	// Очень медленное, умиротворяющее покачивание жидкости в разные стороны
	float t = TIME * speed * 0.06;
	
	// Колебания в разные стороны (круговой дрейф вместо одностороннего движения)
	vec2 sway1 = vec2(sin(t * 0.9), cos(t * 0.7)) * 0.04;
	vec2 sway2 = vec2(cos(t * 0.6 + 1.5), sin(t * 0.8 + 2.4)) * 0.035;
	
	// Мелкая прозрачная водная рябь на поверхности жидкости
	vec2 wave_uv = uv * 2.5;
	vec2 water_ripple = vec2(
		sin(wave_uv.y * 2.5 + t * 4.0) + cos(wave_uv.x * 2.0 - t * 3.0),
		cos(wave_uv.x * 2.5 + t * 3.5) + sin(wave_uv.y * 2.0 - t * 4.5)
	) * 0.012;
	
	// Слой 1: глубокий мягкий фон микросреды
	vec4 bg_sample = texture(noise_texture, uv + sway1 + water_ripple);
	
	// Слой 2: прозрачное преломление верхнего слоя воды (доменное искривление)
	vec2 refraction = (bg_sample.rg - vec2(0.5)) * 0.08;
	vec4 water_sample = texture(noise_texture, uv * 1.35 + sway2 + refraction + water_ripple * 1.5);
	
	// Прозрачная водная игра света / каустика на поверхности
	float water_depth = bg_sample.r;
	float water_highlight = abs(water_sample.r - bg_sample.r);
	
	// Базовое мягкое тонирование цветами уровня
	float blend = smoothstep(0.1, 0.85, water_depth);
	vec4 final_color = mix(color1, color2, blend);
	
	// Эффект чистой прозрачной воды: мягкие светящиеся переливы и блики ряби
	float caustics = smoothstep(0.12, 0.4, water_highlight) * 0.28;
	final_color.rgb += color2.rgb * caustics;
	
	// Едва заметные взвешенные микрочастицы в толще воды
	vec2 p_uv = uv * 2.8 + vec2(sin(t * 1.2) * 0.05, cos(t * 1.0) * 0.05);
	vec4 p_samp = texture(noise_texture, p_uv);
	if (p_samp.b > 0.85) {
		float dust = smoothstep(0.85, 0.98, p_samp.b) * 0.12;
		final_color.rgb += vec3(dust);
	}
	
	COLOR = final_color;
}
