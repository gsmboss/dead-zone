class_name HazardStripe
extends Control
## Полоса «опасно»: жёлто-чёрные диагональные полосы (рамки окон в стиле апокалипсиса).

@export var stripe_color: Color = Color(0.95, 0.72, 0.1)
@export var back_color: Color = Color(0.06, 0.06, 0.06)
@export var stripe_width: float = 16.0

var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 12.0
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), back_color)
	var h: float = size.y
	var x: float = -h
	_points.resize(4)
	while x < size.x + h:
		_points[0] = Vector2(x, h)
		_points[1] = Vector2(x + stripe_width, h)
		_points[2] = Vector2(x + stripe_width + h, 0.0)
		_points[3] = Vector2(x + h, 0.0)
		draw_colored_polygon(_points, stripe_color)
		x += stripe_width * 2.0
