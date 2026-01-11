shader_type spatial;

// render_mode unshaded: Hace que el color sea sólido e ignore luces/sombras internas.
// Esto elimina manchas, brillos indeseados y artefactos en móviles.
render_mode unshaded, shadows_disabled;

uniform vec4 skin_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sun_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Color sólido resultante de la textura y el color base, afectado por la luz global
	ALBEDO = skin_color.rgb * tex_color.rgb * sun_color.rgb;
}
