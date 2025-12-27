shader_type spatial;

uniform vec4 skin_color : hint_color = vec4(0.85, 0.65, 0.55, 1.0);
uniform sampler2D albedo_texture;
uniform float roughness : hint_range(0, 1) = 0.4;
uniform float sss_strength : hint_range(0, 1) = 0.3;
uniform float detail_scale = 50.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    // Muestreo de textura
    vec4 tex_color = texture(albedo_texture, UV);
    
    // Ruido procedimental para poros y piel
    float n = hash(UV * detail_scale);
    float detail = smoothstep(0.4, 0.6, n) * 0.05;
    
    // Albedo: Blend entre color y textura
    ALBEDO = (skin_color.rgb * tex_color.rgb) - detail;
    ROUGHNESS = roughness + detail * 2.0;
    
    // Aproximación de SSS (Subsurface Scattering)
    // El efecto se nota más cuando la luz viene de atrás
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    vec3 sss_color = vec3(1.0, 0.2, 0.1) * sss_strength;
    EMISSION = sss_color * fresnel * 0.2;
    
    // Suavizado de normales para look orgánico
    NORMAL = normalize(NORMAL);
}
