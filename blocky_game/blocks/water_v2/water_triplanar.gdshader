shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// World-space triplanar: neighboring water blocks share continuous UVs (no per-face 0..1 repeats).
// Keep uv_scale + albedo_tint in sync with blocky_game/blocks/render_water_sprite.py (hotbar icon).
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform float uv_scale : hint_range(0.02, 1.0, 0.001) = 0.22;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 0.55);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 b = abs(wnorm);
	float s = b.x + b.y + b.z + 1e-5;
	b /= s;
	vec2 uv_x = wpos.zy * uv_scale;
	vec2 uv_y = wpos.xz * uv_scale;
	vec2 uv_z = wpos.xy * uv_scale;
	vec4 cx = texture(albedo_tex, uv_x);
	vec4 cy = texture(albedo_tex, uv_y);
	vec4 cz = texture(albedo_tex, uv_z);
	vec4 col = cx * b.x + cy * b.y + cz * b.z;
	ALBEDO = col.rgb * albedo_tint.rgb;
	ALPHA = col.a * albedo_tint.a;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.06;
}
