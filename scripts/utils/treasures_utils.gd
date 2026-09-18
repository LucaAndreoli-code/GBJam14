class_name TreasureUtils
extends Node

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
	treasures_count: int, \
	points_total: int, \
	min_each: int = 1) -> Dictionary:
	var combos: Array = []
	var n := treasures_count
	var total := points_total
	var pts: Array[int] = [
		get_treasure_points_by_kind(TreasureInfo.Kind.SMALL),
		get_treasure_points_by_kind(TreasureInfo.Kind.MEDIUM),
		get_treasure_points_by_kind(TreasureInfo.Kind.BIG)
	]
	for z in range(min_each, n + 1):
		for y in range(min_each, n - z + 1):
			var x := n - y - z
			if x < min_each:
				continue
			if pts[0] * x + pts[1] * y + pts[2] * z == total:
				combos.append({
					TreasureInfo.Kind.SMALL: x,
					TreasureInfo.Kind.MEDIUM: y, 
					TreasureInfo.Kind.BIG: z})
	if combos.is_empty():
		push_error("No treasures composition for treasures_count=%d and points_total=%d" % [n, total])
		return {}
	return combos.pick_random()
