shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 4.0;
uniform vec4 bg_color : hint_color = vec4(0.06, 0.1, 0.13, 0.6); // #101922 darkened
uniform vec4 border_color : hint_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform float corner_radius : hint_range(0.0, 1.0) = 1.0;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
}
