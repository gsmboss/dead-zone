class_name HitMarker
extends Control
## Крестик попадания вокруг прицела. Рисуется от своей позиции (0, 0) — центр прицела.

const SHOW_TIME: float = 0.15
const INNER: float = 9.0
const OUTER: float = 22.0
const WIDTH: float = 3.0

var _time_left: float = 0.0
var _color: Color = Color.WHITE
var _size_boost: float = 1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


## Цвет задаёт прицел (попадание, хедшот, убийство); убийство — крестик крупнее
func show_hit(color: Color, killed: bool) -> void:
	_color = color
	_size_boost = 1.35 if killed else 1.0
	_time_left = SHOW_TIME * (1.6 if killed else 1.0)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _time_left <= 0.0:
		return
	var color: Color = _color
	color.a = clampf(_time_left / SHOW_TIME, 0.0, 1.0)
	var inner: float = INNER * _size_boost
	var outer: float = OUTER * _size_boost
	for diagonal: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var dir: Vector2 = diagonal.normalized()
		draw_line(dir * inner, dir * outer, color, WIDTH, true)
