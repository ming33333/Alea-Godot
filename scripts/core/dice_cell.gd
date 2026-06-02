class_name DiceCellData
extends RefCounted

var value: int = 1
var locked: bool = false
var history: Array[int] = []
var vertical_swaps_remaining: int = -1
var no_reroll: bool = false


func _init(v: int = 1, is_locked: bool = false) -> void:
	value = v
	locked = is_locked
	history = [v]


func duplicate_cell() -> DiceCellData:
	var c := DiceCellData.new(value, locked)
	c.history = history.duplicate()
	c.vertical_swaps_remaining = vertical_swaps_remaining
	c.no_reroll = no_reroll
	return c


func push_history(v: int) -> void:
	value = v
	if history.is_empty() or history[history.size() - 1] != v:
		history.append(v)
