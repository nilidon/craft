extends TextureButton
## Builds texture_click_mask from the normal texture’s alpha so transparent padding is not clickable.


func _ready() -> void:
	_apply_click_mask_from_texture_alpha()


func _apply_click_mask_from_texture_alpha() -> void:
	var tex: Texture2D = texture_normal
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return
	var bm: BitMap = BitMap.new()
	bm.create_from_image_alpha(img, 0.12)
	texture_click_mask = bm
