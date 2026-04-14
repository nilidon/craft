shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
/// Higher = softer blur (mipmap LOD).
uniform float blur_lod : hint_range(0.0, 5.0) = 2.25;
/// Extra taps in screen UV space (cheap wide blur on top of mip LOD).
uniform float tap_spread : hint_range(0.0, 0.02) = 0.0045;
uniform vec4 tint : source_color = vec4(0.96, 0.97, 1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_texture, uv, blur_lod).rgb;
	c += textureLod(screen_texture, uv + vec2(tap_spread, 0.0), blur_lod).rgb;
	c += textureLod(screen_texture, uv - vec2(tap_spread, 0.0), blur_lod).rgb;
	c += textureLod(screen_texture, uv + vec2(0.0, tap_spread), blur_lod).rgb;
	c += textureLod(screen_texture, uv - vec2(0.0, tap_spread), blur_lod).rgb;
	c *= 0.2;
	COLOR = vec4(c * tint.rgb, tint.a);
}
