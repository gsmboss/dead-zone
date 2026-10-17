class_name AchievementBadge
extends Control
## Рисованная медаль достижения: лента, круг цвета достижения, звезда. Неполученная — серая.

var color: Color = Color(1.0, 0.8, 0.3)
var locked: bool = false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.36
	var center := Vector2(size.x * 0.5, size.y * 0.56)
	var tint: Color = Color(0.4, 0.4, 0.42) if locked else color
	# Лента
	var ribbon: Color = tint.darkened(0.45)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.8, -r * 1.5), center + Vector2(-r * 0.15, -r * 1.5),
		center + Vector2(r * 0.25, -r * 0.4), center + Vector2(-r * 0.4, -r * 0.4)]), ribbon)
	draw_colored_polygon(PackedVector2Array([center + Vector2(r * 0.8, -r * 1.5), center + Vector2(r * 0.15, -r * 1.5),
		center + Vector2(-r * 0.25, -r * 0.4), center + Vector2(r * 0.4, -r * 0.4)]), ribbon.lightened(0.15))
	# Медаль: тень, обод, круг, блик
	draw_circle(center + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(center, r, tint.darkened(0.35))
	draw_circle(center, r * 0.82, tint)
	draw_arc(center, r * 0.62, PI * 1.1, PI * 1.6, 10, Color(1.0, 1.0, 1.0, 0.45), r * 0.12)
	# Звезда
	var points := PackedVector2Array()
	for i in 10:
		var angle: float = -PI * 0.5 + i * PI / 5.0
		var radius: float = r * (0.5 if i % 2 == 0 else 0.22)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.35) if locked else Color(1.0, 0.98, 0.85))
