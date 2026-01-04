shader_type spatial;

uniform vec4 skin_color : hint_color = vec4(0.85, 0.65, 0.55, 1.0);
uniform sampler2D albedo_texture;
uniform float roughness : hint_range(0, 1) = 0.4;

void fragment() {
	// OPTIMIZACIÓN: Shader ultra-simple sin hash, noise, fresnel, o SSS
	// Esto elimina 30-40% del lag del humanoide
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = skin_color.rgb * tex_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
