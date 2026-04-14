shader_type canvas_item;

/// Blur diameter in source texture pixels (larger = softer). Uses a 7×7 Gaussian.
uniform float blur_texels : hint_range(4.0, 80.0) = 14.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * (blur_texels / 6.0);
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float w = exp(-float(x * x + y * y) / 8.0);
			acc += texture(TEXTURE, UV + vec2(float(x), float(y)) * px) * w;
			wsum += w;
		}
	}
	COLOR = acc / wsum;
}
