shader_type spatial;

uniform sampler2D grass_tex;
uniform sampler2D sand_tex;
uniform sampler2D snow_tex;
uniform sampler2D jungle_tex;

uniform float uv_scale = 0.025; // Ajustado para metros (más grande)

varying vec3 world_pos;
varying vec2 terrain_uv;  // OPTIMIZACIÓN: Calcular UV en vertex

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// OPTIMIZACIÓN: Mover cálculo de UV aquí (se ejecuta por vértice, no por pixel)
	terrain_uv = fract(world_pos.xz * uv_scale);
}

void fragment() {
	// Usar UV pre-calculado (OPTIMIZACIÓN)
	vec2 uv = terrain_uv;
	
	// Pesos de mezcla por Vertex Color (RGBA)
	float w_grass = COLOR.r;
	float w_sand = COLOR.g;
	float w_snow = COLOR.b;
	float w_jungle = COLOR.a;
	
	// Mezcla simple y rápida por pesos (Mejor para GPU que los "if")
	vec3 final_color = texture(grass_tex, uv).rgb * w_grass;
	final_color += texture(sand_tex, uv).rgb * w_sand;
	final_color += texture(snow_tex, uv).rgb * w_snow;
	
	vec3 jungle = texture(jungle_tex, uv).rgb;
	final_color += (jungle * vec3(0.3, 0.6, 0.2)) * w_jungle;
	
	float total = w_grass + w_sand + w_snow + w_jungle + 0.0001;
	ALBEDO = final_color / total;
	ROUGHNESS = 0.8;
}
