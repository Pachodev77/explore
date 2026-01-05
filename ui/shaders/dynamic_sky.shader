shader_type spatial;
render_mode unshaded, cull_front, skip_vertex_transform;

// Parámetros de control
uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;
uniform vec3 sun_axis = vec3(1.0, 0.0, 0.0); // Eje de rotación del sol

// Colores del cielo (Constantes visuales)
const vec3 DAY_TOP = vec3(0.1, 0.4, 0.8);
const vec3 DAY_HORIZON = vec3(0.4, 0.7, 0.9);
const vec3 NIGHT_TOP = vec3(0.02, 0.02, 0.08);
const vec3 NIGHT_HORIZON = vec3(0.05, 0.05, 0.1);
const vec3 SUNSET = vec3(0.8, 0.3, 0.1);
const vec3 SUN_COLOR = vec3(1.0, 0.9, 0.7);

// Funciones de utilidad
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float star_layer(vec2 uv, float threshold, float size_factor) {
    vec2 grid = floor(uv);
    vec2 rel = fract(uv) - 0.5;
    float h = hash(grid);
    if (h < threshold) return 0.0;
    float size = 0.08 + (h - threshold) * size_factor;
    return smoothstep(size, size * 0.4, length(rel));
}

varying vec3 v_world_pos;

void vertex() {
    // Vertex shader simple para el skydome
    v_world_pos = VERTEX;
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 dir = normalize(v_world_pos);
    
    // 1. Calcular fases del día
    // 0.0 = Noche, 1.0 = Día, Interpolaciones en medio
    float day_amt = smoothstep(0.2, 0.25, time_of_day) - smoothstep(0.75, 0.8, time_of_day);
    float sunset_amt = smoothstep(0.2, 0.25, time_of_day) * (1.0 - smoothstep(0.25, 0.3, time_of_day));
    sunset_amt += smoothstep(0.7, 0.75, time_of_day) * (1.0 - smoothstep(0.75, 0.8, time_of_day));
    
    // 2. Gradiente del Cielo
    vec3 sky_top = mix(NIGHT_TOP, DAY_TOP, day_amt);
    vec3 sky_horizon = mix(NIGHT_HORIZON, DAY_HORIZON, day_amt);
    sky_horizon = mix(sky_horizon, SUNSET, sunset_amt * 0.8);
    
    float horizon_blend = smoothstep(-0.1, 0.3, dir.y);
    vec3 sky_color = mix(sky_horizon, sky_top, horizon_blend);
    
    // 3. Sol Procedural (Círculo simple)
    // Calcular posición del sol basado en time_of_day
    float sun_angle = (time_of_day - 0.25) * 6.28318;
    vec3 sun_dir = vec3(cos(sun_angle), sin(sun_angle), 0.0); 
    // Nota: Ajustado para coincidir con la rotación en GDScript (-angle en X, yaw 90)
    // Cuando sun_angle = 0 (time_of_day 0.25), cos=1, sin=0 -> Dir = (+1, 0, 0) = ESTE.
    
    float sun_dot = dot(dir, normalize(sun_dir));
    float sun_disk = smoothstep(0.998, 0.999, sun_dot);
    float sun_glow = smoothstep(0.95, 1.0, sun_dot) * 0.3;
    
    // 4. Estrellas (Solo de noche)
    float stars = 0.0;
    if (day_amt < 0.9) {
        vec2 sky_uv = vec2(atan(dir.x, dir.z), acos(dir.y));
        stars += star_layer(sky_uv * 15.0, 0.99, 0.1);
        stars += star_layer(sky_uv * 40.0, 0.995, 0.05);
        stars *= (1.0 - day_amt); // Desaparecen de día
    }
    
    // Composición final
    vec3 final_color = sky_color + vec3(stars) + (SUN_COLOR * sun_disk) + (SUNSET * sun_glow * sunset_amt);
    
    ALBEDO = final_color;
}
