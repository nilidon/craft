# Container for all block types.
# It is not a resource because it references scripts that can depend on it,
# causing cycles. So instead, it's more convenient to make it a node in the tree.
# IMPORTANT: Needs to be first in tree. Other nodes may use it in _ready().
extends Node

const Block = preload("./block.gd")
const Util = preload("res://common/util.gd")

const ROTATION_TYPE_NONE = 0
const ROTATION_TYPE_AXIAL = 1
const ROTATION_TYPE_Y = 2
const ROTATION_TYPE_CUSTOM_BEHAVIOR = 3

const ROTATION_Y_NEGATIVE_X = 0
const ROTATION_Y_POSITIVE_X = 1
const ROTATION_Y_NEGATIVE_Z = 2
const ROTATION_Y_POSITIVE_Z = 3

const _opposite_y_rotation : Array[int] = [
	ROTATION_Y_POSITIVE_X,
	ROTATION_Y_NEGATIVE_X,
	ROTATION_Y_POSITIVE_Z,
	ROTATION_Y_NEGATIVE_Z
]

const _y_dir : Array[Vector3] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1)
]

const ROOT = "res://blocky_game/blocks"

const AIR_ID = 0

class RawMapping:
	var block_id := 0
	var variant_index := 0


var _voxel_library := preload("res://blocky_game/blocks/voxel_library.tres")
var _blocks = []
var _raw_mappings = []


func _init():
	print("Constructing blocks.gd")
	_create_block({
		"name": "air",
		"directory": "",
		"gui_model": "",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["air"],
		"transparent": true
	})
	_create_block({
		"name": "dirt",
		"gui_model": "dirt.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["dirt"],
		"transparent": false
	})
	_create_block({
		"name": "grass",
		"gui_model": "grass.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["grass"],
		"transparent": false
	})
	_create_block({
		"name": "log",
		"gui_model": "log_y.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["log_y"],
		"transparent": false
	})
	_create_block({
		"name": "planks",
		"display_name": "Plank",
		"gui_model": "planks.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["planks"],
		"transparent": false
	})
	_create_block({
		"name": "stairs",
		"display_name": "Plank Stairs",
		"gui_model": "stairs_nx.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["stairs_nz", "stairs_pz", "stairs_nx", "stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "tall_grass",
		"display_name": "Tall Grass",
		"gui_model": "tall_grass.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["tall_grass"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "clear_glass",
		"display_name": "Glass",
		"directory": "clear_glass",
		"gui_model": "clear_glass.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["clear_glass"],
		"transparent": true,
		"backface_culling": true
	})
	_create_block({
		"name": "water",
		"gui_model": "water_full.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["water_full", "water_top"],
		"transparent": true,
		"backface_culling": true
	})
	_create_block({
		"name": "rail",
		"gui_model": "rail_x.obj",
		"category": "decorations",
		"rotation_type": ROTATION_TYPE_CUSTOM_BEHAVIOR,
		"voxels": [
			# Order matters, see rail.gd
			"rail_x", "rail_z",
			"rail_turn_nx", "rail_turn_px", "rail_turn_nz", "rail_turn_pz",
			"rail_slope_nx", "rail_slope_px","rail_slope_nz", "rail_slope_pz"
		],
		"transparent": true,
		"backface_culling": true,
		"behavior": "rail.gd"
	})
	_create_block({
		"name": "leaves",
		"display_name": "Leaf",
		"gui_model": "leaves.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["leaves"],
		"transparent": true
	})
	_create_block({
		"name": "dead_shrub",
		"gui_model": "dead_shrub.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["dead_shrub"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "stone_bricks",
		"display_name": "Stone Brick",
		"gui_model": "stone_bricks.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["stone_bricks"],
		"transparent": false
	})
	_create_block({
		"name": "cobble",
		"display_name": "Cobblestone",
		"gui_model": "cobble.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["cobble"],
		"transparent": false
	})
	_create_block({
		"name": "sandstone",
		"gui_model": "sandstone.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["sandstone"],
		"transparent": false
	})
	_create_block({
		"name": "brick_red",
		"display_name": "Red Brick",
		"gui_model": "brick_red.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["brick_red"],
		"transparent": false
	})
	_create_block({
		"name": "wood_light",
		"display_name": "Light Wood",
		"gui_model": "wood_light.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["wood_light"],
		"transparent": false
	})
	_create_block({
		"name": "clay",
		"gui_model": "clay.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["clay"],
		"transparent": false
	})
	_create_block({
		"name": "slate",
		"gui_model": "slate.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["slate"],
		"transparent": false
	})
	_create_block({
		"name": "stone",
		"gui_model": "stone.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["stone"],
		"transparent": false
	})
	_create_block({
		"name": "smooth_stone",
		"gui_model": "smooth_stone.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["smooth_stone"],
		"transparent": false
	})
	_create_block({
		"name": "gravel",
		"gui_model": "gravel.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["gravel"],
		"transparent": false
	})
	_create_block({
		"name": "path",
		"gui_model": "path.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["path"],
		"transparent": false
	})
	_create_block({
		"name": "white_block",
		"display_name": "White",
		"gui_model": "white_block.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["white_block"],
		"transparent": false
	})
	_create_block({
		"name": "black_block",
		"display_name": "Black",
		"gui_model": "black_block.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["black_block"],
		"transparent": false
	})
	_create_block({
		"name": "blue_block",
		"display_name": "Blue",
		"gui_model": "blue_block.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["blue_block"],
		"transparent": false
	})
	_create_block({
		"name": "red_block",
		"display_name": "Red",
		"gui_model": "red_block.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["red_block"],
		"transparent": false
	})
	# Pack B: shape variants
	_create_block({
		"name": "stone_bricks_stairs",
		"display_name": "Stone Brick Stairs",
		"directory": "stone_bricks",
		"gui_model": "stone_bricks.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["stone_bricks_stairs_nz", "stone_bricks_stairs_pz", "stone_bricks_stairs_nx", "stone_bricks_stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "stone_bricks_slab",
		"display_name": "Stone Brick Slab",
		"directory": "stone_bricks",
		"gui_model": "stone_bricks.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["stone_bricks_slab"],
		"transparent": false
	})
	_create_block({
		"name": "cobble_stairs",
		"display_name": "Cobblestone Stairs",
		"directory": "cobble",
		"gui_model": "cobble.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["cobble_stairs_nz", "cobble_stairs_pz", "cobble_stairs_nx", "cobble_stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "cobble_slab",
		"display_name": "Cobblestone Slab",
		"directory": "cobble",
		"gui_model": "cobble.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["cobble_slab"],
		"transparent": false
	})
	_create_block({
		"name": "sandstone_stairs",
		"directory": "sandstone",
		"gui_model": "sandstone.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["sandstone_stairs_nz", "sandstone_stairs_pz", "sandstone_stairs_nx", "sandstone_stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "sandstone_slab",
		"directory": "sandstone",
		"gui_model": "sandstone.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["sandstone_slab"],
		"transparent": false
	})
	_create_block({
		"name": "brick_red_stairs",
		"display_name": "Red Brick Stairs",
		"directory": "brick_red",
		"gui_model": "brick_red.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["brick_red_stairs_nz", "brick_red_stairs_pz", "brick_red_stairs_nx", "brick_red_stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "brick_red_slab",
		"display_name": "Red Brick Slab",
		"directory": "brick_red",
		"gui_model": "brick_red.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["brick_red_slab"],
		"transparent": false
	})
	_create_block({
		"name": "wood_light_stairs",
		"display_name": "Light Wood Stairs",
		"directory": "wood_light",
		"gui_model": "wood_light.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"voxels": ["wood_light_stairs_nz", "wood_light_stairs_pz", "wood_light_stairs_nx", "wood_light_stairs_px"],
		"transparent": false
	})
	_create_block({
		"name": "wood_light_slab",
		"display_name": "Light Wood Slab",
		"directory": "wood_light",
		"gui_model": "wood_light.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["wood_light_slab"],
		"transparent": false
	})
	# Decorations
	_create_block({
		"name": "cactus",
		"display_name": "Cactus",
		"gui_model": "cactus.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["cactus"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "bush",
		"display_name": "Bush",
		"gui_model": "bush.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["bush"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "rock",
		"display_name": "Rock",
		"gui_model": "rock.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["rock"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "mushroom",
		"display_name": "Mushroom",
		"gui_model": "mushroom.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["mushroom"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "chest",
		"display_name": "Chest",
		"gui_model": "chest.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["chest"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "well",
		"display_name": "Well",
		"gui_model": "well.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["well"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "coins",
		"display_name": "Coins",
		"gui_model": "coins.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["coins"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "sword",
		"display_name": "Sword",
		"gui_model": "sword.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["sword"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "deco_fence",
		"display_name": "Fence",
		"gui_model": "deco_fence.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["deco_fence_nx", "deco_fence_px", "deco_fence_nz", "deco_fence_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "lantern",
		"display_name": "Lantern",
		"gui_model": "lantern.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["lantern"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "cloud",
		"display_name": "Cloud",
		"gui_model": "cloud.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["cloud"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "portal",
		"display_name": "Portal",
		"gui_model": "portal.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["portal"],
		"transparent": true,
		"backface_culling": false
	})
	# Furniture / Structures
	_create_block({
		"name": "prop_bed",
		"display_name": "Bed",
		"gui_model": "prop_bed_big.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_bed_px", "prop_bed_nx", "prop_bed_nz", "prop_bed_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_chair_light_brown",
		"display_name": "Chair",
		"gui_model": "prop_chair_light_brown.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_chair_light_brown_px", "prop_chair_light_brown_nx", "prop_chair_light_brown_nz", "prop_chair_light_brown_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_couch",
		"display_name": "Couch",
		"gui_model": "prop_couch_big.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_couch_px", "prop_couch_nx", "prop_couch_nz", "prop_couch_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_table_light_brown",
		"display_name": "Table",
		"gui_model": "prop_table_light_brown_big.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_table_light_brown_px", "prop_table_light_brown_nx", "prop_table_light_brown_nz", "prop_table_light_brown_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_drawer_light_brown",
		"display_name": "Drawer",
		"gui_model": "prop_drawer_light_brown.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_drawer_light_brown_px", "prop_drawer_light_brown_nx", "prop_drawer_light_brown_nz", "prop_drawer_light_brown_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_wardrobe_light_brown",
		"display_name": "Wardrobe",
		"gui_model": "prop_wardrobe_light_brown_big.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_wardrobe_light_brown_px", "prop_wardrobe_light_brown_nx", "prop_wardrobe_light_brown_nz", "prop_wardrobe_light_brown_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_lamppost",
		"display_name": "Lamp Post",
		"gui_model": "prop_lamppost_big.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_lamppost"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_oven",
		"display_name": "Oven",
		"gui_model": "prop_oven.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_oven_px", "prop_oven_nx", "prop_oven_nz", "prop_oven_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_mug",
		"display_name": "Mug",
		"gui_model": "prop_mug.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_mug"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_pan",
		"display_name": "Pan",
		"gui_model": "prop_pan.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_pan"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_glass_water",
		"display_name": "Water Glass",
		"gui_model": "prop_glass_water.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_glass_water"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_glass_wine",
		"display_name": "Wine Glass",
		"gui_model": "prop_glass_wine.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_glass_wine"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_pot_silver",
		"display_name": "Silver Pot",
		"gui_model": "prop_pot_silver.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_pot_silver"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_chair_dark_brown",
		"display_name": "Dark Chair",
		"gui_model": "prop_chair_dark_brown.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_chair_dark_brown_px", "prop_chair_dark_brown_nx", "prop_chair_dark_brown_nz", "prop_chair_dark_brown_pz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_campfire",
		"display_name": "Campfire",
		"gui_model": "prop_campfire.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["prop_campfire"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "prop_chest_light_brown",
		"display_name": "Chest",
		"gui_model": "prop_chest_light_brown.obj",
		"rotation_type": ROTATION_TYPE_Y,
		"category": "decorations",
		"voxels": ["prop_chest_light_brown_px", "prop_chest_light_brown_nx", "prop_chest_light_brown_pz", "prop_chest_light_brown_nz"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_sunflower",
		"display_name": "Sunflower",
		"gui_model": "nat_sunflower.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_sunflower"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_rose",
		"display_name": "Rose",
		"gui_model": "nat_rose.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_rose"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_white_tulip",
		"display_name": "White Tulip",
		"gui_model": "nat_white_tulip.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_white_tulip"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_rock_small",
		"display_name": "Small Rock",
		"gui_model": "nat_rock_small.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_rock_small"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_rock_large",
		"display_name": "Large Rock",
		"gui_model": "nat_rock_large.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_rock_large"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "nat_grass",
		"display_name": "Wild Grass",
		"gui_model": "nat_grass.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"category": "decorations",
		"voxels": ["nat_grass"],
		"transparent": true,
		"backface_culling": false
	})


func get_block(id: int) -> Block:
	assert(id >= 0)
	return _blocks[id]


func get_model_library() -> VoxelBlockyLibrary:
	return _voxel_library


func get_block_by_name(block_name: String) -> Block:
	for b in _blocks:
		if b.base_info.name == block_name:
			return b
	assert(false)
	return null


# Gets the corresponding block ID and variant index from a raw voxel value
func get_raw_mapping(raw_id: int) -> RawMapping:
	assert(raw_id >= 0)
	var rm = _raw_mappings[raw_id]
	assert(rm != null)
	return rm


func get_block_count() -> int:
	return len(_blocks)


func _create_block(params: Dictionary):
	_defaults(params, {
		"rotation_type": ROTATION_TYPE_NONE,
		"transparent": false,
		"backface_culling": true,
		"directory": params.name,
		"category": "blocks",
		"behavior": ""
	})

	var block : Block
	if params.behavior != "":
		# Block with special behavior
		var behavior_path := str(ROOT, "/", params.directory, "/", params.behavior)
		var behavior = load(behavior_path)
		block = behavior.new()
	else:
		# Generic
		block = Block.new()

	# Fill in base info
	var base_info := block.base_info
	base_info.id = len(_blocks)
	
	for i in len(params.voxels):
		var vname : String = params.voxels[i]
		var id := _voxel_library.get_model_index_from_resource_name(vname)
		if id == -1:
			push_error("Could not find voxel named {0}".format([vname]))
		assert(id != -1)
		params.voxels[i] = id
		var rm := RawMapping.new()
		rm.block_id = base_info.id
		rm.variant_index = i
		if id >= len(_raw_mappings):
			_raw_mappings.resize(id + 1)
		_raw_mappings[id] = rm

	base_info.name = params.name
	if params.has("display_name"):
		base_info.display_name = params.display_name
	else:
		base_info.display_name = params.name.capitalize()
	base_info.directory = params.directory
	base_info.category = params.category
	base_info.rotation_type = params.rotation_type
	base_info.voxels = params.voxels
	base_info.transparent = params.transparent
	base_info.backface_culling = params.backface_culling
	if base_info.directory != "":
		base_info.gui_model_path = str(ROOT, "/", params.directory, "/", params.gui_model)
		var sprite_path := str(ROOT, "/", params.directory, "/", params.name, "_sprite.png")
		base_info.sprite_texture = load(sprite_path)

	_blocks.append(block)
	add_child(block)


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			print("Deleting blocks.gd")


static func _defaults(d: Dictionary, defaults: Dictionary):
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k]


static func get_y_rotation_from_look_dir(dir: Vector3) -> int:
	var a = Util.get_direction_id4(Vector2(dir.x, dir.z))
	match a:
		0:
			return ROTATION_Y_NEGATIVE_X
		1:
			return ROTATION_Y_NEGATIVE_Z
		2:
			return ROTATION_Y_POSITIVE_X
		3:
			return ROTATION_Y_POSITIVE_Z
		_:
			assert(false)
	return -1


static func get_y_dir_vec(yid: int) -> Vector3:
	return _y_dir[yid]


static func get_opposite_y_dir(yid: int) -> int:
	return _opposite_y_rotation[yid]
