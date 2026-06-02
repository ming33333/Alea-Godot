class_name PatternCheck
extends RefCounted

const INCOMPLETE := "Incomplete"
const FIVE_KIND := "5 of a Kind"
const FULL_HOUSE := "Full House"
const STRAIGHT := "Straight"


static func is_consecutive_straight(sorted: Array) -> bool:
	if sorted.size() != 5:
		return false
	for i in range(1, 5):
		if int(sorted[i]) != int(sorted[i - 1]) + 1:
			return false
	return true


static func check_pattern(row: Array) -> String:
	var sorted: Array = row.duplicate()
	sorted.sort()
	var counts: Dictionary = {}
	for val in row:
		var v: int = int(val)
		counts[v] = counts.get(v, 0) + 1
	var count_values: Array = counts.values()
	count_values.sort()
	count_values.reverse()
	if count_values[0] == 5:
		return FIVE_KIND
	if count_values.size() == 2 and count_values[0] == 3 and count_values[1] == 2:
		return FULL_HOUSE
	if is_consecutive_straight(sorted):
		return STRAIGHT
	return INCOMPLETE
