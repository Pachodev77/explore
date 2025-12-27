shader_type sky;

uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;

// Función de ruido simple para las estrellas
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 dir = EYEDIR;
	
	// Colores del cielo
	vec3 day_sky_top = vec3(0.3, 0.5, 0.9); // Azul cielo
	vec3 day_sky_horizon = vec3(0.6, 0.75, 0.95); // Azul claro
	vec3 night_sky = vec3(0.01, 0.01, 0.05); // Casi negro
	vec3 sunset_color = vec3(1.0, 0.5, 0.2); // Naranja atardecer
	
	// Calcular gradiente vertical (arriba vs horizonte)
	float horizon_factor = 1.0 - abs(dir.y);
	
	// Fase del día (0 = noche, 1 = día)
	float day_phase = 0.0;
	if (time_of_day < 0.2 || time_of_day > 0.8) {
		day_phase = 0.0; // Noche
	} else if (time_of_day > 0.3 && time_of_day < 0.7) {
		day_phase = 1.0; // Día
	} else if (time_of_day >= 0.2 && time_of_day <= 0.3) {
		day_phase = smoothstep(0.2, 0.3, time_of_day); // Amanecer
	} else {
		day_phase = smoothstep(0.8, 0.7, time_of_day); // Atardecer
	}
	
	// Color base del cielo
	vec3 day_color = mix(day_sky_top, day_sky_horizon, horizon_factor);
	
	// Añadir color de atardecer en el horizonte durante transiciones
	float sunset_factor = 0.0;
	if (time_of_day > 0.2 && time_of_day < 0.35) {
		sunset_factor = sin((time_of_day - 0.2) / 0.15 * 3.14159) * horizon_factor;
	} else if (time_of_day > 0.65 && time_of_day < 0.8) {
		sunset_factor = sin((time_of_day - 0.65) / 0.15 * 3.14159) * horizon_factor;
	}
	day_color = mix(day_color, sunset_color, sunset_factor * 0.7);
	
	// Interpolar entre día y noche
	vec3 sky_color = mix(night_sky, day_color, day_phase);
	
	// ESTRELLAS (solo de noche)
	float star_intensity = 1.0 - day_phase;
	if (star_intensity > 0.01 && dir.y > 0.0) { // Solo en el hemisferio superior
		// Capas de estrellas para más densidad
		float stars = 0.0;
		
		// Capa 1: Estrellas grandes y brillantes
		vec2 uv1 = vec2(atan(dir.x, dir.z), acos(dir.y)) * 40.0;
		float field1 = noise(uv1);
		stars += step(0.97, field1) * hash(floor(uv1));
		
		// Capa 2: Estrellas pequeñas y densas
		vec2 uv2 = vec2(atan(dir.x, dir.z), acos(dir.y)) * 120.0;
		float field2 = noise(uv2);
		stars += step(0.95, field2) * hash(floor(uv2)) * 0.5;
		
		// Capa 3: Micro-estrellas de fondo
		vec2 uv3 = vec2(atan(dir.x, dir.z), acos(dir.y)) * 300.0;
		float field3 = noise(uv3);
		stars += step(0.92, field3) * hash(floor(uv3)) * 0.2;
		
		// Añadir parpadeo sutil con diferentes frecuencias
		float blink = 0.8 + 0.2 * sin(TIME * (hash(floor(uv1)) * 2.0 + 1.0) + hash(floor(uv1)) * 100.0);
		stars *= blink;
		
		// Aplicar estrellas al cielo
		sky_color += vec3(stars) * star_intensity;
	}
	
	COLOR = sky_color;
}
