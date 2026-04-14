extends RefCounted
## Compact snow-shell hut for tundra; hollow inside, door gap on +Z wall (above floor).

const Structure = preload("./structure.gd")

const _CH := VoxelBuffer.CHANNEL_TYPE


static func build(white_block_type: int) -> Structure:
	var voxels: Dictionary = {}
	var cx := 3.5
	var cz := 3.5
	var cy := 2.35
	var outer_r := 3.5
	var inner_r := 2.25

	for y in 6:
		for x in 8:
			for z in 8:
				var px := float(x) + 0.5
				var py := float(y) + 0.5
				var pz := float(z) + 0.5
				var dx := px - cx
				var dy := py - cy
				var dz := pz - cz
				var dist := sqrt(dx * dx + dy * dy + dz * dz)

				# Opening on high-Z face; keep y=0 floor continuous.
				var door_gap := z >= 6 and x >= 2 and x <= 5 and y >= 1 and y <= 3
				if door_gap:
					continue

				if y == 0:
					var hr := (px - cx) * (px - cx) + (pz - cz) * (pz - cz)
					if hr <= outer_r * outer_r:
						voxels[Vector3i(x, y, z)] = white_block_type
					continue

				if dist < inner_r:
					continue
				if dist <= outer_r:
					voxels[Vector3i(x, y, z)] = white_block_type

	var aabb := AABB()
	for pos in voxels:
		aabb = aabb.expand(pos)

	var structure := Structure.new()
	structure.offset = -aabb.position
	var buffer := structure.voxels
	buffer.create(int(aabb.size.x) + 1, int(aabb.size.y) + 1, int(aabb.size.z) + 1)
	for pos in voxels:
		var rpos: Vector3i = pos + structure.offset
		buffer.set_voxel(voxels[pos], rpos.x, rpos.y, rpos.z, _CH)
	return structure
