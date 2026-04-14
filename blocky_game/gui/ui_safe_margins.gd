extends RefCounted
class_name UiSafeMargins
## Best-effort display safe area → left, top, right, bottom margins (logical px).
## Desktop / unsupported hosts usually return zeros. Uses intersection of safe rect with usable screen,
## then maps from window pixel space into the same coordinate space as [Viewport.get_visible_rect].

const _MAX_INSET_PX := 200


static func insets_for_viewport(vp: Viewport) -> Vector4i:
	if vp == null:
		return Vector4i.ZERO
	if vp is SubViewport:
		return Vector4i.ZERO
	## Manual [DisplayServer] safe rects are often in a different space than stretched GUI coords on
	## phones; zeros keep layout on-screen. Rely on fullscreen + project stretch for edge clearance.
	if not Engine.is_editor_hint():
		var n := OS.get_name()
		if n == &"Android" or n == &"iOS":
			return Vector4i.ZERO
	var safe_i := Rect2i(DisplayServer.get_display_safe_area())
	if safe_i.size.x < 8 or safe_i.size.y < 8:
		return Vector4i.ZERO
	var scr_idx := DisplayServer.window_get_current_screen()
	var usable_i := Rect2i(DisplayServer.screen_get_usable_rect(scr_idx))
	if usable_i.size.x < 8 or usable_i.size.y < 8:
		return Vector4i.ZERO
	var inter := safe_i.intersection(usable_i)
	if inter.size.x < 8 or inter.size.y < 8:
		return Vector4i.ZERO
	var L := inter.position.x - usable_i.position.x
	var T := inter.position.y - usable_i.position.y
	var R := (usable_i.position.x + usable_i.size.x) - (inter.position.x + inter.size.x)
	var B := (usable_i.position.y + usable_i.size.y) - (inter.position.y + inter.size.y)
	L = clampi(L, 0, _MAX_INSET_PX)
	T = clampi(T, 0, _MAX_INSET_PX)
	R = clampi(R, 0, _MAX_INSET_PX)
	B = clampi(B, 0, _MAX_INSET_PX)
	var win_id: int = vp.get_window_id()
	var wsize: Vector2i = DisplayServer.window_get_size(win_id)
	if wsize.x < 1 or wsize.y < 1:
		return Vector4i.ZERO
	var vr: Rect2 = vp.get_visible_rect()
	var vsize: Vector2 = vr.size
	if vsize.x < 1.0 or vsize.y < 1.0:
		return Vector4i.ZERO
	var sx: float = vsize.x / float(wsize.x)
	var sy: float = vsize.y / float(wsize.y)
	## If scales diverge a lot, window vs GUI space mapping is unreliable — skip manual insets.
	if sx < 0.2 or sy < 0.2 or sx > 5.0 or sy > 5.0:
		return Vector4i.ZERO
	L = clampi(int(round(float(L) * sx)), 0, _MAX_INSET_PX)
	T = clampi(int(round(float(T) * sy)), 0, _MAX_INSET_PX)
	R = clampi(int(round(float(R) * sx)), 0, _MAX_INSET_PX)
	B = clampi(int(round(float(B) * sy)), 0, _MAX_INSET_PX)
	## Reject absurd totals (bad safe-area / multi-monitor / pre-transform coords).
	if float(L + R) > vsize.x * 0.38 or float(T + B) > vsize.y * 0.38:
		return Vector4i.ZERO
	## Never let one edge eat most of the short side after mapping.
	var cap_x: int = maxi(8, int(floorf(vsize.x * 0.12)))
	var cap_y: int = maxi(8, int(floorf(vsize.y * 0.12)))
	L = mini(L, cap_x)
	R = mini(R, cap_x)
	T = mini(T, cap_y)
	B = mini(B, cap_y)
	return Vector4i(L, T, R, B)


## Inner width/height for laying out content that already sits inside full-bleed safe padding.
static func content_size(vp: Viewport) -> Vector2:
	if vp == null:
		return Vector2.ZERO
	var s: Vector2 = vp.get_visible_rect().size
	var ins := insets_for_viewport(vp)
	return Vector2(
		maxf(32.0, s.x - float(ins.x + ins.z)),
		maxf(32.0, s.y - float(ins.y + ins.w))
	)
