class_name DangerMeter
extends Control
## Шкала опасности черепами: заполненные — уровень, тусклые — до максимума.

const SKULL_SIZE: float = 30.0
const GAP: float = 8.0
const ACTIVE_COLOR: Color = Color(0.9, 0.3, 0.12)
const INACTIVE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const HOLE_COLOR: Color = Color(0.06, 0.05, 0.05)

var level: int = 1
var max_level: int = 5


static func create(danger: int, maximum: int) -> DangerMeter:
	var meter := DangerMeter.new()
	meter.level = danger
	meter.max_level = maxi(maximum, 1)
	meter.mouse_filter = MOUSE_FILTER_IGNORE
	meter.custom_minimum_size = Vector2(meter.max_level * (SKULL_SIZE + GAP), SKULL_SIZE)
	return meter


func _draw() -> void:
	var r: float = SKULL_SIZE * 0.5
	for i in max_level:
		var c := Vector2(r + i * (SKULL_SIZE + GAP), size.y * 0.5)
		var color: Color = ACTIVE_COLOR if i < level else INACTIVE_COLOR
		draw_circle(c - Vector2(0.0, r * 0.15), r * 0.8, color)
		draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.3), Vector2(r * 0.9, r * 0.45)), color)
		if i < level:
			draw_circle(c + Vector2(-r * 0.3, -r * 0.1), r * 0.2, HOLE_COLOR)
			draw_circle(c + Vector2(r * 0.3, -r * 0.1), r * 0.2, HOLE_COLOR)
