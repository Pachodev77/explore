shader_type spatial;

uniform sampler2D grass_tex;
uniform sampler2D sand_tex;
uniform sampler2D snow_tex;
uniform sampler2D jungle_tex;

uniform float uv_scale = 0.025; 
uniform vec3 player_pos;
uniform float torch_intensity = 0.0; // 0 a 1 para activar el brillo per-pixel

varying vec3 world_pos;
varying vec2 terrain_uv;

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_uv = fract(world_pos.xz * uv_scale);
}

void fragment() {
	vec2 uv = terrain_uv;
	
	float w_grass = COLOR.r;
	float w_sand = COLOR.g;
	float w_snow = COLOR.b;
	float w_jungle = COLOR.a;
	
	vec3 final_color = texture(grass_tex, uv).rgb * w_grass;
	final_color += texture(sand_tex, uv).rgb * w_sand;
	final_color += texture(snow_tex, uv).rgb * w_snow;
	
	vec3 jungle = texture(jungle_tex, uv).rgb;
	final_color += (jungle * vec3(0.3, 0.6, 0.2)) * w_jungle;
	
	float total = w_grass + w_sand + w_snow + w_jungle + 0.0001;
	vec3 base_albedo = final_color / total;
	
	// --- FIX PARA MÓVILES: ILUMINACIÓN PER-PIXEL ---
	// La luz OmniLight en móviles a veces usa vertex-lighting que se ve "manchado" en mallas grandes.
	// Añadimos un sutil refuerzo per-pixel si la antorcha está activa.
	float d = distance(world_pos, player_pos);
	float torch_glow = clamp(1.0 - (d / 22.0), 0.0, 1.0);
	torch_glow = pow(torch_glow, 2.0); // Caída más natural
	
	// Solo aplicamos el brillo si torch_intensity es > 0
	vec3 light_boost = vec3(1.0, 0.6, 0.2) * torch_glow * torch_intensity * 0.8;
	
	ALBEDO = base_albedo + (base_albedo * light_boost);
	ROUGHNESS = 0.8;
}
