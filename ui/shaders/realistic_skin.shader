shader_type spatial;

// RENDER MODE: shadows_disabled elimina las manchas y sombras feas causadas
// por las piezas del cuerpo intersecándose entre sí.
render_mode shadows_disabled, diffuse_burley;

uniform vec4 skin_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture;
uniform float roughness : hint_range(0, 1) = 0.85;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Sutil efecto de "fresnel" mucho más tenue para evitar brillo
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	vec3 base_color = skin_color.rgb * tex_color.rgb;
	
	ALBEDO = base_color + (fresnel * 0.05); 
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
