class_name TreasureUtils

const TREASURE_POINTS := {
	TreasureInfo.Kind.SMALL: 5,
	TreasureInfo.Kind.MEDIUM: 10,
	TreasureInfo.Kind.BIG: 50,
}

static func get_treasure_points_by_kind(kind: TreasureInfo.Kind) -> int:
	return TREASURE_POINTS[kind]

static func get_treasure_points(treasure: TreasureInfo) -> int:
	return TREASURE_POINTS[treasure.kind]

static func pick_composition(
	points_total: int,
	digging_spots: int,
	min_per_spot: int,
	max_per_spot: int,
	min_each: int = 1
) -> Dictionary:
	var pts: Array[int] = [
		get_treasure_points_by_kind(TreasureInfo.Kind.SMALL),
		get_treasure_points_by_kind(TreasureInfo.Kind.MEDIUM),
		get_treasure_points_by_kind(TreasureInfo.Kind.BIG)
	]
	var n_min := digging_spots * min_per_spot
	var n_max := digging_spots * max_per_spot
	var combos: Array = []
	for z in range(min_each, points_total / pts[2] + 1):
		for y in range(min_each, (points_total - pts[2] * z) / pts[1] + 1):
			var rest := points_total - pts[1] * y - pts[2] * z
			if rest % pts[0] != 0:
				continue
			var x := rest / pts[0]
			var n := x + y + z
			if x >= min_each and n >= n_min and n <= n_max:
				combos.append({
					TreasureInfo.Kind.SMALL: x,
					TreasureInfo.Kind.MEDIUM: y,
					TreasureInfo.Kind.BIG: z,
				})
	if combos.is_empty():
		push_error("No composition for %d points with %d spots" % [points_total, digging_spots])
		return {}
	return combos.pick_random()
