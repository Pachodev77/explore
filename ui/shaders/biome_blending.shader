shader_type spatial;

// =============================================================================
// biome_blending.shader - SHADER DE TERRENO (Godot 3.x Compatible)
// =============================================================================
// Usa proyección triplanar para evitar texturas estiradas en pendientes.
// =============================================================================

uniform sampler2D grass_tex;
uniform sampler2D sand_tex;
uniform sampler2D snow_tex;
uniform sampler2D jungle_tex;
uniform sampler2D gravel_tex;

uniform float uv_scale = 0.04;
uniform float triplanar_sharpness = 6.0;
uniform vec3 player_pos;
uniform float torch_intensity = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float road_weight;

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	road_weight = UV2.x;
}

// Función triplanar simplificada
vec3 sample_triplanar(sampler2D tex, vec3 pos, vec3 normal, float scale) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.0001);
	
	vec2 uv_x = pos.zy * scale;
	vec2 uv_y = pos.xz * scale;
	vec2 uv_z = pos.xy * scale;
	
	vec3 tex_x = texture(tex, uv_x).rgb;
	vec3 tex_y = texture(tex, uv_y).rgb;
	vec3 tex_z = texture(tex, uv_z).rgb;
	
	return tex_x * blend.x + tex_y * blend.y + tex_z * blend.z;
}

// Muestreo híbrido optimizado
vec3 sample_terrain(sampler2D tex, vec3 pos, vec3 normal, float scale) {
	float flatness = abs(normal.y);
	
	if (flatness > 0.85) {
		// Superficie plana: UV simple
		return texture(tex, pos.xz * scale).rgb;
	} else if (flatness > 0.5) {
		// Transición
		vec3 simple_sample = texture(tex, pos.xz * scale).rgb;
		vec3 triplanar_sample = sample_triplanar(tex, pos, normal, scale);
		float blend_factor = (0.85 - flatness) / 0.35;
		return mix(simple_sample, triplanar_sample, blend_factor);
	} else {
		// Pendiente: triplanar
		return sample_triplanar(tex, pos, normal, scale);
	}
}

void fragment() {
	vec3 n = normalize(world_normal);
	
	// Pesos de bioma desde vertex color
	float w_grass = COLOR.r;
	float w_sand = COLOR.g;
	float w_snow = COLOR.b;
	float w_jungle = COLOR.a;
	
	// Muestrear texturas
	vec3 col_grass = sample_terrain(grass_tex, world_pos, n, uv_scale);
	vec3 col_sand = sample_terrain(sand_tex, world_pos, n, uv_scale);
	vec3 col_snow = sample_terrain(snow_tex, world_pos, n, uv_scale);
	vec3 col_jungle = sample_terrain(jungle_tex, world_pos, n, uv_scale);
	
	// Tinte de jungla
	col_jungle *= vec3(0.35, 0.65, 0.25);
	
	// Combinar biomas
	vec3 biome_color = col_grass * w_grass;
	biome_color += col_sand * w_sand;
	biome_color += col_snow * w_snow;
	biome_color += col_jungle * w_jungle;
	
	// Normalizar
	float total_weight = w_grass + w_sand + w_snow + w_jungle + 0.0001;
	vec3 base_color = biome_color / total_weight;
	
	// Textura de camino
	if (road_weight > 0.01) {
		vec2 gravel_uv = world_pos.xz * uv_scale * 1.8;
		vec3 gravel_color = texture(gravel_tex, gravel_uv).rgb;
		gravel_color *= vec3(0.82, 0.76, 0.70);
		float blend = smoothstep(0.0, 0.35, road_weight);
		base_color = mix(base_color, gravel_color, blend);
	}
	
	// Iluminación de antorcha
	if (torch_intensity > 0.01) {
		float dist_to_player = distance(world_pos, player_pos);
		float attenuation = clamp(1.0 - (dist_to_player / 22.0), 0.0, 1.0);
		attenuation = pow(attenuation, 2.0);
		vec3 torch_color = vec3(1.0, 0.55, 0.15);
		base_color += base_color * torch_color * attenuation * torch_intensity * 0.85;
	}
	
	ALBEDO = base_color;
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
}
