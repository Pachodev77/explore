shader_type spatial;

uniform sampler2D grass_tex;
uniform sampler2D sand_tex;
uniform sampler2D snow_tex;
uniform sampler2D jungle_tex;

uniform float uv_scale = 0.025; // Ajustado para metros (más grande)

varying vec3 world_pos;

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Usamos la posición global real para que las texturas continúen entre tiles
	vec2 uv = fract(world_pos.xz * uv_scale);
	
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 sand = texture(sand_tex, uv).rgb;
	vec3 snow = texture(snow_tex, uv).rgb;
	vec3 jungle = texture(jungle_tex, uv).rgb;
	
	// Pesos de mezcla por Vertex Color (RGBA)
	float w_grass = COLOR.r;
	float w_sand = COLOR.g;
	float w_snow = COLOR.b;
	float w_jungle = COLOR.a;
	
	vec3 green_jungle = jungle * vec3(0.3, 0.6, 0.2); // Tinte verde selvático oscuro aplicado sobre la textura
	
	float total = w_grass + w_sand + w_snow + w_jungle + 0.0001;
	vec3 final_color = (grass * w_grass + sand * w_sand + snow * w_snow + green_jungle * w_jungle) / total;
	
	ALBEDO = final_color;
	ROUGHNESS = 0.8;
}
