shader_type spatial;

uniform vec4 base_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pattern_color : hint_color = vec4(0.8, 0.4, 0.1, 1.0); // Marrón/Rojizo
uniform float pattern_scale = 10.0;
uniform float pattern_intensity = 0.5;

varying highp vec3 v_pos;

void vertex() {
	v_pos = VERTEX * pattern_scale;
}

void fragment() {
	// Patrón de plumas simple usando ruido senoidal
	float n = sin(v_pos.x) * sin(v_pos.y) * sin(v_pos.z);
	float mask = smoothstep(-0.2, 0.2, n);
	
	ALBEDO = mix(base_color.rgb, pattern_color.rgb, mask * pattern_intensity);
	ROUGHNESS = 0.8;
}
