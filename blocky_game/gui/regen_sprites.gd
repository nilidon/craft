extends Node

const Blocks = preload("../blocks/blocks.gd")
const Block = Blocks.Block

@onready var _viewport : SubViewport = $SubViewport
@onready var _mesh_instance : MeshInstance3D = $SubViewport/MeshInstance3D

var _blocks := Blocks.new()
var _target_names := [
	"prop_bed", "prop_couch", "prop_table_light_brown",
	"prop_wardrobe_light_brown", "prop_lamppost"
]
var _queue : Array[int] = []
var _current_idx := -1


func _ready():
	add_child(_blocks)
	for i in range(_blocks.get_block_count()):
		var block = _blocks.get_block(i).base_info
		if block.name in _target_names:
			_queue.append(i)
	print("Will regenerate ", _queue.size(), " sprites: ", _target_names)


func _process(_delta):
	if _current_idx >= 0 and _current_idx < _queue.size():
		var bid = _queue[_current_idx]
		var block = _blocks.get_block(bid).base_info
		if block.directory != "":
			var viewport_texture := _viewport.get_texture()
			var im := viewport_texture.get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			var fpath := str(Blocks.ROOT, "/", block.directory, "/", block.name, "_sprite.png")
			var err := im.save_png(fpath)
			if err != OK:
				push_error(str("Could not save ", fpath, ", error ", err))
			else:
				print("Saved ", fpath)

	_current_idx += 1

	if _current_idx < _queue.size():
		var bid = _queue[_current_idx]
		var block = _blocks.get_block(bid).base_info
		if block.directory != "":
			var gui_mesh : Mesh = load(block.gui_model_path)
			_mesh_instance.mesh = gui_mesh
			var lib := _blocks.get_model_library()
			var model := lib.get_model(block.voxels[0])
			var mat := model.get_material_override(0)
			_mesh_instance.material_override = mat
			print("Rendering: ", block.name)
	else:
		set_process(false)
		print("Done! All 5 sprites regenerated. You can close this scene.")
