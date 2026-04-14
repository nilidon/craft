shader_type canvas_item;

/// Max darkness at the inner edges (alpha of black overlay).
uniform float strength : hint_range(0.0, 0.85) = 0.34;
/// Inner content width / height (same units as inner_h).
uniform float box_aspect : hint_range(0.15, 2.5) = 0.62;
/// Inner rect height in pixels (for corner radius → normalized SDF).
uniform float inner_h : hint_range(32.0, 1024.0) = 330.0;
/// Inner corner radius in pixels (matches frame / gray band).
uniform float corner_px : hint_range(0.0, 48.0) = 9.0;
/// Where radial falloff starts (aspect-corrected space, ~0.35–1.45).
uniform float radius : hint_range(0.35, 1.45) = 0.82;
uniform float softness : hint_range(0.06, 0.55) = 0.38;
/// Width of the mask edge blend in p-space (wider = no hard “gap” before the frame line).
uniform float mask_softness : hint_range(0.01, 0.12) = 0.038;
/// Grow the masked shape toward the frame (pixels, ~2–5) so shadow meets the border line.
uniform float mask_inflate_px : hint_range(0.0, 8.0) = 3.25;

void fragment() {
	// Aspect-corrected coords; |p.x|≤box_aspect, |p.y|≤1 at edges.
	vec2 p = (UV * 2.0 - 1.0) * vec2(box_aspect, 1.0);
	float r_p = (2.0 * corner_px) / max(inner_h, 1.0);
	vec2 half_ext = max(vec2(box_aspect, 1.0) - vec2(r_p), vec2(0.0001));
	float sd = length(max(abs(p) - half_ext, vec2(0.0))) - r_p;
	// Pull boundary outward (more “inside”) so vignette isn’t cut off short of the visible stroke.
	float expand_p = (2.0 * mask_inflate_px) / max(inner_h, 1.0);
	sd -= expand_p;
	float edge = mask_softness * 2.25;
	float mask = 1.0 - smoothstep(-edge, 0.0, sd);

	vec2 c = UV - vec2(0.5);
	c.x *= box_aspect;
	float d = length(c) * 2.0;
	float v = smoothstep(radius - softness * 0.5, radius + softness * 0.5, d);
	float a = v * strength * mask;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
