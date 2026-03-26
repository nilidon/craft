extends TextureRect

const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")
var _texture_cache := {}


func set_item(data: InventoryItem):
	if data == null:
		texture = null
		
	elif data.type == InventoryItem.TYPE_BLOCK:
		var block := _block_types.get_block(data.id)
		var sprite_tex: Texture2D = block.base_info.sprite_texture
		var block_name: String = block.base_info.name
		if block_name == "stairs" or block_name.ends_with("_stairs"):
			# Add a bit more top margin so stairs corners don't get clipped by slot framing.
			texture = _get_padded_texture(sprite_tex, 6, 2)
		else:
			texture = sprite_tex

	elif data.type == InventoryItem.TYPE_ITEM:
		var item := _item_db.get_item(data.id)
		texture = item.base_info.sprite
	
	else:
		assert(false)


func _get_padded_texture(src_tex: Texture2D, pad_top: int, pad_bottom: int) -> Texture2D:
	if src_tex == null:
		return null

	var key := str(src_tex.get_instance_id(), ":", pad_top, ":", pad_bottom)
	if _texture_cache.has(key):
		return _texture_cache[key]

	var src_img: Image = src_tex.get_image()
	if src_img == null:
		return src_tex

	var used: Rect2i = src_img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return src_tex

	var dst_w: int = src_img.get_width()
	var dst_h: int = src_img.get_height()
	var available_h: int = dst_h - pad_top - pad_bottom
	if available_h <= 0:
		return src_tex

	var scale: float = min(1.0, float(available_h) / float(used.size.y))
	var out_w: int = maxi(1, int(round(float(used.size.x) * scale)))
	var out_h: int = maxi(1, int(round(float(used.size.y) * scale)))

	var cut: Image = src_img.get_region(used)
	if out_w != used.size.x or out_h != used.size.y:
		cut.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	var dst := Image.create(dst_w, dst_h, false, Image.FORMAT_RGBA8)
	var place_x: int = (dst_w - out_w) / 2
	var place_y: int = pad_top + (available_h - out_h) / 2
	dst.blit_rect(cut, Rect2i(0, 0, out_w, out_h), Vector2i(place_x, place_y))

	var out_tex := ImageTexture.create_from_image(dst)
	_texture_cache[key] = out_tex
	return out_tex
