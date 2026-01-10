shader_type spatial;

// RENDER_MODE: Quitamos skip_vertex_transform para que Godot maneje la proyección
// de forma segura en todos los dispositivos (GLES2/GLES3).
render_mode unshaded, cull_front;

uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;

const vec3 DAY_TOP = vec3(0.1, 0.4, 0.8);
const vec3 DAY_HORIZON = vec3(0.4, 0.7, 0.9);
const vec3 NIGHT_TOP = vec3(0.01, 0.01, 0.05);
const vec3 NIGHT_HORIZON = vec3(0.02, 0.02, 0.08);
const vec3 SUNSET = vec3(0.8, 0.4, 0.2);
const vec3 SUN_COLOR = vec3(1.0, 0.95, 0.8);

varying highp vec3 v_dir;

void vertex() {
	// Guardamos la dirección normalizada del vértice para el fragmento
	v_dir = VERTEX;
}

highp float hash(highp vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

highp float star_layer(highp vec2 uv, float threshold, float size_factor) {
    highp vec2 grid = floor(uv);
    highp vec2 rel = fract(uv) - 0.5;
    highp float h = hash(grid);
    if (h < threshold) return 0.0;
    float size = 0.05 + (h - threshold) * size_factor;
    return smoothstep(size, size * 0.4, length(rel));
}

void fragment() {
    highp vec3 dir = normalize(v_dir);
    
    // Fases del día
    float day_amt = smoothstep(0.2, 0.3, time_of_day) - smoothstep(0.7, 0.8, time_of_day);
    float sunset_amt = smoothstep(0.18, 0.28, time_of_day) * (1.0 - smoothstep(0.28, 0.38, time_of_day));
    sunset_amt += smoothstep(0.62, 0.72, time_of_day) * (1.0 - smoothstep(0.72, 0.82, time_of_day));
    
    // Colores base
    vec3 sky_top = mix(NIGHT_TOP, DAY_TOP, day_amt);
    vec3 sky_horizon = mix(NIGHT_HORIZON, DAY_HORIZON, day_amt);
    sky_horizon = mix(sky_horizon, SUNSET, sunset_amt * 0.8);
    
    // Mezcla vertical
    float horizon_blend = smoothstep(-0.2, 0.5, dir.y);
    vec3 sky_color = mix(sky_horizon, sky_top, horizon_blend);
    
    // Sol mejorado
    highp float sun_angle = (time_of_day - 0.25) * 6.283185;
    highp vec3 sun_dir = normalize(vec3(cos(sun_angle), sin(sun_angle), 0.01));
    highp float sun_dot = clamp(dot(dir, sun_dir), 0.0, 1.0);
    
    float sun_disk = smoothstep(0.998, 0.999, sun_dot);
    float sun_glow = pow(sun_dot, 60.0) * 0.3;
    
    // Estrellas
    float stars = 0.0;
    if (day_amt < 0.5) {
        highp vec2 sky_uv = vec2(atan(dir.x, dir.z), acos(clamp(dir.y, -1.0, 1.0)));
        stars += star_layer(sky_uv * 20.0, 0.99, 0.1);
        stars *= (1.0 - day_amt * 2.0);
    }
    
    vec3 final_color = sky_color + stars + (SUN_COLOR * sun_disk) + (SUN_COLOR * sun_glow);
    ALBEDO = clamp(final_color, 0.0, 1.0);
}
