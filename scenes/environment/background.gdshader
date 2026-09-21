shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.04, 0.08, 0.12, 1.0);
uniform vec4 color2 : source_color = vec4(0.25, 0.65, 0.85, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.007;
uniform float caustics_intensity : hint_range(0.0, 1.5) = 0.42;
uniform float particles_intensity : hint_range(0.0, 1.5) = 0.35;
uniform vec2 cam_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 base_uv = UV;
	float t = TIME * speed;
	
	// Мировые координаты с учетом масштаба экрана и плавного смещения камеры
	vec2 p_uv = (SCREEN_UV * 3.5) + (cam_offset * 0.00015);
	
	// 1. Вязкие течения цитоплазмы (Двойной вихревой дрейф - Domain Warping)
	// Создает эффект плавно текущей органической жидкости без резких рывков
	vec2 flow = vec2(
		sin(p_uv.y * 1.6 + t * 0.45) + cos(p_uv.x * 1.3 - t * 0.35),
		cos(p_uv.x * 1.5 + t * 0.40) + sin(p_uv.y * 1.4 - t * 0.30)
	);
	vec2 swirl = vec2(
		sin(p_uv.x * 2.2 + flow.y * 1.3 + t * 0.50),
		cos(p_uv.y * 2.2 + flow.x * 1.3 - t * 0.40)
	);
	
	// Сэмплируем фоновый арт с мягким преломлением (всего 1 выборка текстуры на кадр!)
	vec2 warped_uv = base_uv + swirl * distortion_strength;
	vec4 art = texture(TEXTURE, clamp(warped_uv, vec2(0.001), vec2(0.999)));
	
	// 2. Шелковистая биолюминесцентная каустика (Трёхлучевая волновая интерференция)
	// Суперпозиция 3 гармоник под углом 60 градусов: чистая математика ALU (0 циклов, 0 текстур)
	vec2 c_uv = p_uv * 1.8 + swirl * 0.4;
	float a1 = dot(c_uv, vec2(1.0, 0.0)) + t * 0.60;
	float a2 = dot(c_uv, vec2(-0.5, 0.866025)) - t * 0.50;
	float a3 = dot(c_uv, vec2(-0.5, -0.866025)) + t * 0.55;
	
	float wave = sin(a1 + sin(a2)) + sin(a2 + sin(a3)) + sin(a3 + sin(a1));
	float caustics = 1.0 - abs(wave) / 3.0;
	caustics = pow(max(0.0, caustics), 4.5) * caustics_intensity;
	
	// 3. Двухслойный дрейф парящих микро-спор и глубокого боке
	// Слой A: Глубокие мерцающие микроспоры / био-пыль
	vec2 sp1_uv = p_uv * 4.5 + vec2(t * 0.08, -t * 0.06);
	float sp1 = sin(sp1_uv.x * 6.3 + sin(sp1_uv.y * 4.2 + t)) * cos(sp1_uv.y * 5.8 - cos(sp1_uv.x * 4.5));
	float micro_spores = smoothstep(0.88, 0.99, sp1) * 0.4;
	
	// Слой B: Близкие мягкие расфокусированные био-боке (парящие клетки вблизи линзы)
	vec2 sp2_uv = (SCREEN_UV * 2.0) + (cam_offset * 0.00025) + vec2(-t * 0.03, t * 0.04);
	float sp2 = sin(sp2_uv.x * 2.8 + t * 0.3) * cos(sp2_uv.y * 2.4 - t * 0.25);
	float bokeh = pow(smoothstep(0.92, 0.998, sp2), 1.8) * 0.35;
	
	float total_particles = (micro_spores + bokeh) * particles_intensity;
	
	// 4. Осмотическое био-дыхание среды (медленная, медитативная пульсация)
	float bio_pulse = 0.95 + 0.05 * sin(t * 0.5);
	
	// 5. Оптическая глубина линзы микроскопа (мягкая виньетка по краям)
	float dist_from_center = length(SCREEN_UV - vec2(0.5));
	float lens_vignette = smoothstep(0.88, 0.32, dist_from_center);
	
	// 6. Итоговый композит: базовый арт + свечение каустики + споры + оптика линзы
	vec3 final_rgb = art.rgb;
	
	// Подсветка каустики в палитре главы со светлым ядром нитей
	vec3 caustic_color = mix(color2.rgb, vec3(0.9, 0.98, 1.0), 0.25);
	final_rgb += caustic_color * caustics;
	
	// Свечение парящих спор
	vec3 spore_color = mix(color2.rgb, vec3(0.95, 1.0, 0.98), 0.35);
	final_rgb += spore_color * total_particles;
	
	// Применение био-дыхания и оптики линзы
	final_rgb *= bio_pulse;
	final_rgb *= mix(vec3(0.88), vec3(1.02), lens_vignette);
	
	COLOR = vec4(final_rgb, art.a);
}
