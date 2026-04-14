extends Control
class_name CoinsHudBadge
## Coin icon + amount in a row (no frame). Opaque trim on the texture for layout; stroked icon like mobile HUD.

var icon_texture: Texture2D
var _amount_text := "0"
## Pixel rect of opaque pixels in icon_texture (excludes transparent margins so layout centers the real coin).
var _coin_src_rect := Rect2()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_coin_texture(tex: Texture2D) -> void:
	icon_texture = tex
	if tex == null:
		_coin_src_rect = Rect2()
	else:
		_coin_src_rect = opaque_pixel_bounds(tex)
		if _coin_src_rect.size.x < 1.0 or _coin_src_rect.size.y < 1.0:
			_coin_src_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
	queue_redraw()


func set_amount_text(s: String) -> void:
	_amount_text = s
	queue_redraw()


## Tight bounds of non-transparent pixels (shared with reward UI that uses TextureRect + AtlasTexture).
static func opaque_pixel_bounds(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var fw := int(tex.get_width())
	var fh := int(tex.get_height())
	if fw < 1 or fh < 1:
		return Rect2(0, 0, maxf(float(fw), 1.0), maxf(float(fh), 1.0))
	var img := tex.get_image()
	if img == null or img.is_empty():
		return Rect2(0, 0, float(fw), float(fh))
	var im := img
	if im.get_format() != Image.FORMAT_RGBA8:
		im = im.duplicate()
		im.convert(Image.FORMAT_RGBA8)
	const a_cut := 0.06
	var min_x := fw
	var min_y := fh
	var max_x := -1
	var max_y := -1
	for y in range(fh):
		for x in range(fw):
			if im.get_pixel(x, y).a > a_cut:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2(0, 0, float(fw), float(fh))
	return Rect2(float(min_x), float(min_y), float(max_x - min_x + 1), float(max_y - min_y + 1))


func _draw_icon_region_with_stroke(tex: Texture2D, dest: Rect2, src_rect: Rect2) -> void:
	var stroke := Color(0.08, 0.1, 0.18, 0.94)
	var dirs: Array[Vector2] = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
	]
	for d in dirs:
		draw_texture_rect_region(tex, Rect2(dest.position + d, dest.size), src_rect, stroke)
	draw_texture_rect_region(tex, dest, src_rect, Color.WHITE)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	# Scale with control size (design matches [CoinsHud] _BADGE_DESIGN 120×78).
	const design_w := 120.0
	const design_h := 78.0
	var ui_sc := clampf(minf(size.x / design_w, size.y / design_h), 0.65, 1.5)
	var pad := 2.0 * ui_sc
	var inner_gap := 7.0 * ui_sc
	var content := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
	if content.size.x < 4.0 or content.size.y < 4.0:
		return

	var row_center_y := content.position.y + content.size.y * 0.5
	var f := ThemeDB.fallback_font

	var label_fs := clampi(int(round(22.0 * ui_sc)), 14, 36)
	var min_label_fs := clampi(int(round(11.0 * ui_sc)), 10, 16)
	var sz := Vector2.ZERO
	if f != null and not _amount_text.is_empty():
		sz = f.get_string_size(_amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs)

	var iw := 0.0
	var ih := 0.0
	var ts := Vector2.ZERO
	if icon_texture != null:
		if _coin_src_rect.size.x < 1.0 or _coin_src_rect.size.y < 1.0:
			_coin_src_rect = Rect2(0, 0, icon_texture.get_width(), icon_texture.get_height())
		ts = _coin_src_rect.size

	while label_fs >= min_label_fs:
		if f != null and not _amount_text.is_empty():
			sz = f.get_string_size(_amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs)
		else:
			sz = Vector2.ZERO
		var has_icon := icon_texture != null and ts.x > 0.0 and ts.y > 0.0
		var gap_w := inner_gap if has_icon else 0.0
		var max_iw := content.size.x - sz.x - gap_w
		max_iw = maxf(max_iw, 12.0 * ui_sc)
		iw = 0.0
		ih = 0.0
		if has_icon:
			# Without the old pill, content is taller/wider — cap coin so it stays HUD-sized, not huge.
			var cap := minf(content.size.y * 0.52, max_iw)
			cap = maxf(cap, 12.0 * ui_sc)
			var max_w := cap
			var max_h := minf(content.size.y, cap)
			var scl := minf(max_w / ts.x, max_h / ts.y)
			iw = ts.x * scl
			ih = ts.y * scl
			if iw > max_w:
				var rw := max_w / iw
				iw *= rw
				ih *= rw
			if ih > max_h:
				var rh := max_h / ih
				iw *= rh
				ih *= rh
		var block_w := iw + gap_w + sz.x
		if block_w <= content.size.x + 0.5:
			break
		label_fs -= 1

	var has_icon_draw := icon_texture != null and ts.x > 0.0 and ts.y > 0.0 and iw > 0.0
	var gap_draw := inner_gap if has_icon_draw else 0.0
	var block_w := iw + gap_draw + sz.x
	var block_left := content.position.x + (content.size.x - block_w) * 0.5
	var ix := block_left
	var iy := row_center_y - ih * 0.5
	if has_icon_draw:
		_draw_icon_region_with_stroke(icon_texture, Rect2(ix, iy, iw, ih), _coin_src_rect)

	if f != null and not _amount_text.is_empty():
		var text_x := block_left + iw + gap_draw
		var ascent := f.get_ascent(label_fs)
		var baseline := row_center_y + ascent - sz.y * 0.5
		var tp := Vector2(text_x, baseline)
		draw_string(
			f,
			tp,
			_amount_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label_fs,
			Color(0.96, 0.97, 1.0, 0.95)
		)
