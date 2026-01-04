shader_type spatial;

uniform vec4 water_color : hint_color = vec4(0.1, 0.4, 0.8, 0.95);
uniform vec4 deep_water_color : hint_color = vec4(0.05, 0.2, 0.5, 1.0);
uniform float wave_speed : hint_range(0.0, 5.0) = 0.3;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.1;
uniform float wave_frequency : hint_range(0.0, 10.0) = 2.0;

varying float height;

void vertex() {
	// Onda única simplificada para máximo rendimiento
	float w = sin(VERTEX.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
	VERTEX.y += w;
	height = VERTEX.y;
}

void fragment() {
	float depth = clamp(height * 2.0 + 0.5, 0.0, 1.0);
	vec3 color = mix(water_color.rgb, deep_water_color.rgb, depth);
	
	ALBEDO = color;
	ALPHA = mix(water_color.a, deep_water_color.a, depth);
	METALLIC = 0.2;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
}
