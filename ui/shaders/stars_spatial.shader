shader_type spatial;
render_mode unshaded, cull_front;

uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;
uniform float star_density : hint_range(0.0, 1.0) = 0.8;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Genera una capa de estrellas con puntos circulares nítidos y estables
float star_layer(vec2 uv, float threshold, float size_factor) {
    vec2 grid = floor(uv);
    vec2 rel = fract(uv) - 0.5;
    float h = hash(grid);
    
    // Umbral mucho más alto para menos estrellas
    if (h < threshold) return 0.0;
    
    // Tamaño de la estrella un poco mayor para evitar aliasing (parpadeo al mover cámara)
    float size = 0.08 + (h - threshold) * size_factor;
    float dist = length(rel);
    
    // Suavizado más generoso para estabilidad visual
    return smoothstep(size, size * 0.4, dist);
}

varying vec3 world_dir;

void vertex() {
    VERTEX = VERTEX * 0.9;
    world_dir = (WORLD_MATRIX * vec4(VERTEX, 0.0)).xyz;
}

void fragment() {
    vec3 dir = normalize(world_dir);
    if (dir.y < -0.01) discard;

    float day_phase = 0.0;
    if (time_of_day < 0.22 || time_of_day > 0.78) day_phase = 0.0;
    else if (time_of_day > 0.35 && time_of_day < 0.65) day_phase = 1.0;
    else if (time_of_day >= 0.22 && time_of_day <= 0.35) day_phase = (time_of_day - 0.22) / 0.13;
    else day_phase = (0.78 - time_of_day) / 0.13;

    float star_intensity = 1.0 - day_phase;
    if (star_intensity < 0.01) discard;

    // Proyección más estable
    vec2 sky_uv = vec2(atan(dir.x, dir.z), acos(dir.y));
    
    float stars = 0.0;
    // Ajustado para un punto medio de densidad (un poco más que antes)
    stars += star_layer(sky_uv * 15.0, 0.988, 0.1);
    stars += star_layer(sky_uv * 40.0, 0.990, 0.05);
    stars += star_layer(sky_uv * 100.0, 0.992, 0.02); // Añadida una capa fina de estrellas lejanas

    if (stars < 0.1) discard;

    // Parpadeo mucho más lento y suave para evitar que "aparezcan y desaparezcan"
    float blink = 0.85 + 0.15 * sin(TIME * 0.5 + hash(floor(sky_uv * 10.0)) * 6.28);
    
    ALBEDO = vec3(1.0);
    ALPHA = stars * star_intensity * blink;
}
