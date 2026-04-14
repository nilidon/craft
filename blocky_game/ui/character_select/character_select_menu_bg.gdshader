shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 0.02) = 0.006;
uniform vec4 tint : source_color = vec4(0.52, 0.56, 0.62, 0.94);

void fragment() {
	vec2 r = vec2(blur_radius, blur_radius);
	vec4 s = texture(TEXTURE, UV) * 0.34;
	s += texture(TEXTURE, UV + vec2(r.x, 0.0)) * 0.165;
	s += texture(TEXTURE, UV - vec2(r.x, 0.0)) * 0.165;
	s += texture(TEXTURE, UV + vec2(0.0, r.y)) * 0.165;
	s += texture(TEXTURE, UV - vec2(0.0, r.y)) * 0.165;
	COLOR = s * tint;
}
