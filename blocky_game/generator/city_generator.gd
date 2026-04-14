#tool
extends VoxelGeneratorScript
## Flat grid: parks (grass + fence layer); building doors = air openings; windows from 2nd wall row up.

const VoxelLibraryResource = preload("../blocks/voxel_library.tres")

const AIR := 0
const DIRT := 1
const GRASS := 2

const WORLD_SEED := 841927 ^ 0xC17E7

const CITY_SURFACE := 12
const TERRAIN_MIN_Y := -14
const TERRAIN_MAX_Y := 26

const STREET_WIDTH := 3
const LOT_SIZE := 16
const B_LO := 4
const B_HI := 12

const _CHANNEL := VoxelBuffer.CHANNEL_TYPE

var _heightmap_min_y := TERRAIN_MIN_Y
var _heightmap_max_y := TERRAIN_MAX_Y

var _stone := DIRT
var _cobble := DIRT
var _bricks := DIRT
var _brick_red := DIRT
var _wood := DIRT
var _slate := DIRT
var _glass := AIR
var _smooth := DIRT
var _slab_brick := DIRT
var _slab_wood := DIRT
var _slab_cobble := DIRT
var _fence_nx := AIR
var _fence_px := AIR
var _fence_nz := AIR
var _fence_pz := AIR
var _corner_post := DIRT


func _init() -> void:
	_stone = _idx("stone", _stone)
	_cobble = _idx("cobble", _cobble)
	_bricks = _idx("stone_bricks", _bricks)
	_brick_red = _idx("brick_red", _brick_red)
	_wood = _idx("wood_light", _wood)
	_slate = _idx("slate", _slate)
	var gl := VoxelLibraryResource.get_model_index_from_resource_name("clear_glass")
	if gl >= 0:
		_glass = gl
	_smooth = _idx("smooth_stone", _smooth)
	if _smooth == DIRT:
		_smooth = _stone
	_slab_brick = _idx("stone_bricks_slab", _slab_brick)
	if _slab_brick == DIRT:
		_slab_brick = _bricks
	_slab_wood = _idx("wood_light_slab", _slab_wood)
	if _slab_wood == DIRT:
		_slab_wood = _wood
	_slab_cobble = _idx("cobble_slab", _slab_cobble)
	if _slab_cobble == DIRT:
		_slab_cobble = _cobble
	_fence_nx = _idx("deco_fence_nx", _fence_nx)
	_fence_px = _idx("deco_fence_px", _fence_px)
	_fence_nz = _idx("deco_fence_nz", _fence_nz)
	_fence_pz = _idx("deco_fence_pz", _fence_pz)
	_corner_post = _idx("wood_light", _corner_post)
	if _corner_post == DIRT:
		_corner_post = _bricks


func _idx(name: String, fallback: int) -> int:
	var i: int = VoxelLibraryResource.get_model_index_from_resource_name(name)
	if i >= 0:
		return i
	return fallback


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _cell_local_16(g: int) -> int:
	var c := floori(float(g) / float(LOT_SIZE))
	return g - c * LOT_SIZE


func _lot_key(g: int) -> int:
	return floori(float(g) / float(LOT_SIZE))


func _lot_seed(lx: int, lz: int) -> int:
	return int(((lx * 92821) ^ (lz * 48271) ^ WORLD_SEED) & 0x7FFFFFFF)


func _is_street(gx: int, gz: int) -> bool:
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	return ux < STREET_WIDTH or uz < STREET_WIDTH


func _is_park(lseed: int) -> bool:
	return (lseed % 11) == 0


func _building_stories(lseed: int) -> int:
	return 3 + (lseed % 8)


func _building_bounds(lseed: int) -> Vector4i:
	var half_w := 3 + ((lseed >> 2) % 4)
	var half_d := 3 + ((lseed >> 5) % 4)
	var cx := 8
	var cz := 8
	var skew_x := (lseed % 3) - 1
	var skew_z := ((lseed / 3) % 3) - 1
	var ux0 := maxi(B_LO, cx - half_w + skew_x)
	var ux1 := mini(B_HI, cx + half_w + skew_x)
	var uz0 := maxi(B_LO, cz - half_d + skew_z)
	var uz1 := mini(B_HI, cz + half_d + skew_z)
	while ux1 - ux0 < 3:
		if ux0 > B_LO:
			ux0 -= 1
		elif ux1 < B_HI:
			ux1 += 1
		else:
			break
	while uz1 - uz0 < 3:
		if uz0 > B_LO:
			uz0 -= 1
		elif uz1 < B_HI:
			uz1 += 1
		else:
			break
	return Vector4i(ux0, ux1, uz0, uz1)


func _wall_type(lseed: int) -> int:
	var v := (lseed / 7) % 5
	match v:
		0:
			return _bricks
		1:
			return _brick_red
		2:
			return _wood
		3:
			return _slate
		_:
			return _smooth


func _roof_type(lseed: int) -> int:
	match (lseed >> 9) % 4:
		0:
			return _slab_brick
		1:
			return _slab_wood
		2:
			return _slab_cobble
		_:
			return _smooth


func _window_phase(lseed: int) -> int:
	return (lseed >> 4) % 3


func _sparse_windows(lseed: int) -> bool:
	return (lseed >> 7) % 3 == 0


func _is_building_footprint(gx: int, gz: int, lseed: int) -> bool:
	if _is_park(lseed):
		return false
	if _is_street(gx, gz):
		return false
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	var b := _building_bounds(lseed)
	return ux >= b.x and ux <= b.y and uz >= b.z and uz <= b.w


func _building_edge(gx: int, gz: int, lseed: int) -> bool:
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	var b := _building_bounds(lseed)
	if ux < b.x or ux > b.y or uz < b.z or uz > b.w:
		return false
	return ux == b.x or ux == b.y or uz == b.z or uz == b.w


func _door_column(ux: int, uz: int, lseed: int, b: Vector4i) -> bool:
	var span_x := b.y - b.x
	var span_z := b.w - b.z
	if span_x < 2 or span_z < 2:
		return false
	var face := lseed % 4
	var off_z := 1 + ((lseed >> 2) % maxi(1, span_z - 2))
	var off_x := 1 + ((lseed >> 4) % maxi(1, span_x - 2))
	match face:
		0:
			return ux == b.x and uz == b.z + off_z
		1:
			return ux == b.y and uz == b.z + off_z
		2:
			return uz == b.z and ux == b.x + off_x
		_:
			return uz == b.w and ux == b.x + off_x


func _is_door_here(gx: int, gz: int, wy: int, lseed: int) -> bool:
	if wy < CITY_SURFACE or wy > CITY_SURFACE + 1:
		return false
	if not _building_edge(gx, gz, lseed):
		return false
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	var b := _building_bounds(lseed)
	return _door_column(ux, uz, lseed, b)


func _window_here(gx: int, gz: int, wy: int, roof_y: int, lseed: int) -> bool:
	if _glass == AIR or wy >= roof_y:
		return false
	## First wall row above ground (wy == CITY_SURFACE): no windows.
	if wy <= CITY_SURFACE:
		return false
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	var b := _building_bounds(lseed)
	if _door_column(ux, uz, lseed, b):
		return false
	if not _building_edge(gx, gz, lseed):
		return false
	var phase := _window_phase(lseed)
	if _sparse_windows(lseed) and (wy - CITY_SURFACE + phase) % 4 != 1:
		return false
	elif not _sparse_windows(lseed) and (wy - CITY_SURFACE + phase) % 3 != 1:
		return false
	if (ux == b.x or ux == b.y) and ((uz + phase) % 3) == 1:
		return true
	if (uz == b.z or uz == b.w) and ((ux + phase) % 3) == 1:
		return true
	return false


func _on_park_grass_ring(ux: int, uz: int) -> bool:
	if ux < STREET_WIDTH or uz < STREET_WIDTH:
		return false
	if ux > 3 and ux < 15 and uz > 3 and uz < 15:
		return false
	return true


func _is_park_corner(ux: int, uz: int) -> bool:
	return (ux == 3 or ux == 15) and (uz == 3 or uz == 15)


## Fence sits on top of grass (wy == CITY_SURFACE): corner = solid post, edges = directional fence.
func _park_fence_layer(gx: int, gz: int, lseed: int) -> int:
	if not _is_park(lseed):
		return -1
	var ux := _cell_local_16(gx)
	var uz := _cell_local_16(gz)
	if not _on_park_grass_ring(ux, uz):
		return -1
	if _is_park_corner(ux, uz):
		return _corner_post
	if ux == 3 and _fence_nx != AIR:
		return _fence_nx
	if ux == 15 and _fence_px != AIR:
		return _fence_px
	if uz == 3 and _fence_nz != AIR:
		return _fence_nz
	if uz == 15 and _fence_pz != AIR:
		return _fence_pz
	return -1


func _surface_block(gx: int, gz: int) -> int:
	if _is_street(gx, gz):
		return _cobble
	var lx := _lot_key(gx)
	var lz := _lot_key(gz)
	var lseed := _lot_seed(lx, lz)
	if _is_park(lseed):
		return GRASS
	return _smooth


func _voxel_at(gx: int, gz: int, wy: int) -> int:
	if wy < CITY_SURFACE - 1:
		return _stone
	if wy == CITY_SURFACE - 1:
		return _surface_block(gx, gz)

	var lx := _lot_key(gx)
	var lz := _lot_key(gz)
	var lseed := _lot_seed(lx, lz)

	if wy == CITY_SURFACE:
		if _is_street(gx, gz):
			return AIR
		if _is_park(lseed):
			var pf := _park_fence_layer(gx, gz, lseed)
			if pf >= 0:
				return pf
			return AIR

	if _is_street(gx, gz):
		return AIR
	if _is_park(lseed):
		return AIR
	if not _is_building_footprint(gx, gz, lseed):
		return AIR

	var stories := _building_stories(lseed)
	var roof_y := CITY_SURFACE + stories
	if wy > roof_y:
		return AIR
	if wy == roof_y:
		return _roof_type(lseed)

	var wall := _wall_type(lseed)
	if _building_edge(gx, gz, lseed):
		if _is_door_here(gx, gz, wy, lseed):
			return AIR
		if _window_here(gx, gz, wy, roof_y, lseed):
			return _glass
		return wall
	return AIR


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, _unused_lod: int) -> void:
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y

	if origin_in_voxels.y > _heightmap_max_y:
		buffer.fill(AIR, _CHANNEL)
	elif origin_in_voxels.y + block_size < _heightmap_min_y:
		buffer.fill(_stone, _CHANNEL)
	else:
		for z in block_size:
			for x in block_size:
				var gx := origin_in_voxels.x + x
				var gz := origin_in_voxels.z + z
				for ly in block_size:
					var wy := oy + ly
					buffer.set_voxel(_voxel_at(gx, gz, wy), x, ly, z, _CHANNEL)

	buffer.compress_uniform_channels()
