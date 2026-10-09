extends RefCounted
# Retained as the legacy representation boundary for import/comparison checks.
const CAPACITY_LIMIT: int = 9223372036854774784
static func capacity(energy):return preload("res://scripts/reactor_integer.gd").from_growth(energy)
