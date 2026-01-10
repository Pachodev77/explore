shader_type spatial;

// Usamos render_mode para asegurar que no haya comportamientos extraños en móviles
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 spot_color : hint_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float spot_scale = 4.2;     
uniform float spot_threshold = 0.5; 
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform vec3 part_offset;

// Varying con alta precisión para móviles
varying highp vec3 v_noise_pos;

void vertex() {
	// Pre-multiplicamos la escala en el vertex para mejorar la precisión de interpolación
	v_noise_pos = (VERTEX + part_offset) * spot_scale;
}

// Hash ultra-potente y estable para móviles (Dave Hoskins modificado para highp)
highp float hash(highp vec3 p3) {
	p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Ruido de valor suave
highp float noise(highp vec3 x) {
    highp vec3 i = floor(x);
    highp vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(mix(hash(i + vec3(0.0,0.0,0.0)), hash(i + vec3(1.0,0.0,0.0)), f.x),
            mix(hash(i + vec3(0.0,1.0,0.0)), hash(i + vec3(1.0,1.0,0.0)), f.x), f.y),
        mix(mix(hash(i + vec3(0.0,0.0,1.0)), hash(i + vec3(1.0,0.0,1.0)), f.x),
            mix(hash(i + vec3(0.0,1.0,1.0)), hash(i + vec3(1.0,1.0,1.0)), f.x), f.y), 
        f.z
    );
}

void fragment() {
	// FBM de 2 octavas (suficiente y más estable en móvil) con rotación simple
	highp vec3 p = v_noise_pos;
	highp float n = 0.0;
	highp float a = 0.5;
	
	// Octava 1
	n += a * noise(p);
	
	// Octava 2 (Con offset y rotación manual simple)
	p = p * 2.02 + vec3(10.1, 7.5, -5.2);
	a *= 0.5;
	n += a * noise(p);
	
	// El ruido está en rango 0.0-1.0 aproximadamente.
	// Ajustamos el contraste para manchas de vaca clásicas.
	// Bajamos el threshold un poco (0.4) para asegurar que haya manchas negras.
	float spots = smoothstep(spot_threshold - 0.05, spot_threshold + 0.05, n);
	
	ALBEDO = mix(base_color.rgb, spot_color.rgb, spots);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
