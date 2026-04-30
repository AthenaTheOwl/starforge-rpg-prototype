class_name HexUtils
## Static hex-grid utility functions.
## Uses axial coordinates Vector2i(q, r) with flat-top orientation.

const SQRT3 := 1.7320508075688772


static func hex_to_pixel(coords: Vector2i, size: float) -> Vector2:
	var q := coords.x
	var r := coords.y
	var x := size * 1.5 * q
	var y := size * SQRT3 * (r + q / 2.0)
	return Vector2(x, y)


static func pixel_to_hex(pixel: Vector2, size: float) -> Vector2i:
	var q := pixel.x / (size * 1.5)
	var r := (pixel.y / (size * SQRT3)) - q / 2.0
	return axial_round(q, r)


static func axial_round(q_frac: float, r_frac: float) -> Vector2i:
	var s_frac := -q_frac - r_frac
	var q_round := roundi(q_frac)
	var r_round := roundi(r_frac)
	var s_round := roundi(s_frac)

	var q_diff := absf(q_round - q_frac)
	var r_diff := absf(r_round - r_frac)
	var s_diff := absf(s_round - s_frac)

	if q_diff > r_diff and q_diff > s_diff:
		q_round = -r_round - s_round
	elif r_diff > s_diff:
		r_round = -q_round - s_round

	return Vector2i(q_round, r_round)


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func hex_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	var result: Array[Vector2i] = []
	for d in directions:
		result.append(coords + d)
	return result


static func hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center] if radius == 0 else []
	var results: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	# Start at center + direction[4] * radius (south-west scaled)
	var current := center + Vector2i(-radius, radius)
	for i in 6:
		for _j in radius:
			results.append(current)
			current += directions[i]
	return results


static func flat_top_hex_points(size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		points.append(Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	return points
