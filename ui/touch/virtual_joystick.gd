class_name TouchJoystick
extends Control
## Плавающий джойстик в 3D-стиле (углублённая база, объёмный стик с бликом).
## Сам не читает ввод — им управляет TouchControls.
## (Имя TouchJoystick: в Godot 4.7+ есть встроенный класс VirtualJoystick)

@export var radius: float = 110.0
@export_range(0.0, 0.9, 0.01) var deadzone: float = 0.12
@export var base_color: Color = Color(0.12, 0.13, 0.15, 0.45)
@export var ring_color: Color = Color(1, 1, 1, 0.35)
@export var knob_color: Color = Color(0.5, 0.53, 0.6, 0.85)

## Выход в диапазоне -1..1. Вверх по экрану = -Y (как у Input.get_vector).
var output: Vector2 = Vector2.ZERO

var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_on_resized()


func contains_viewport_point(viewport_pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_to_local(viewport_pos))


func begin(viewport_pos: Vector2) -> void:
	var local_pos: Vector2 = _to_local(viewport_pos)
	if not local_pos.is_finite():
		return
	_active = true
	_center = local_pos
	# База не должна вылезать за край зоны
	_center.x = clampf(_center.x, radius, maxf(radius, size.x - radius))
	_center.y = clampf(_center.y, radius, maxf(radius, size.y - radius))
	_update_knob(viewport_pos)


func drag(viewport_pos: Vector2) -> void:
	if _active:
		_update_knob(viewport_pos)


func end() -> void:
	_active = false
	output = Vector2.ZERO
	_center = _rest_center()
	_knob = _center
	queue_redraw()


func _update_knob(viewport_pos: Vector2) -> void:
	var local_pos: Vector2 = _to_local(viewport_pos)
	if not local_pos.is_finite() or radius <= 0.0:
		return
	var offset: Vector2 = (local_pos - _center).limit_length(radius)
	_knob = _center + offset

	var raw: Vector2 = offset / radius
	var magnitude: float = minf(raw.length(), 1.0)
	if magnitude < deadzone:
		output = Vector2.ZERO
	else:
		# Ремап мёртвой зоны: движение плавно стартует от 0, а не скачком
		output = raw.normalized() * inverse_lerp(deadzone, 1.0, magnitude)
	queue_redraw()


## Нефинитный результат (вырожденная трансформация в первые кадры) — Vector2.INF
func _to_local(viewport_pos: Vector2) -> Vector2:
	var xform: Transform2D = get_global_transform_with_canvas()
	if is_zero_approx(xform.determinant()):
		return Vector2.INF
	return xform.affine_inverse() * viewport_pos


func _rest_center() -> Vector2:
	return Vector2(radius * 1.5, size.y - radius * 1.5)


func _on_resized() -> void:
	if not _active:
		end()


func _draw() -> void:
	# Защита от NaN/INF: иначе draw_arc сыплет ошибками нормализации каждый кадр
	if not _center.is_finite() or not _knob.is_finite():
		_center = _rest_center()
		_knob = _center
	if radius <= 0.0 or not is_finite(radius):
		return
	# База: углубление — светлый край снизу, тёмный сверху (свет падает сверху)
	draw_circle(_center + Vector2(0.0, 3.0), radius, Color(1.0, 1.0, 1.0, 0.08))
	draw_circle(_center, radius, base_color)
	draw_circle(_center - Vector2(0.0, radius * 0.04), radius * 0.92, Color(0.0, 0.0, 0.0, 0.18))
	# Без antialiased: сглаженная дуга в Compatibility даёт ошибки нормализации
	draw_arc(_center, radius, 0.0, TAU, 48, ring_color, 3.0, false)

	# Стик: тень, боковина, лицевая сторона, блик
	var knob_radius: float = radius * 0.42
	draw_circle(_knob + Vector2(0.0, knob_radius * 0.22), knob_radius, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(_knob + Vector2(0.0, knob_radius * 0.1), knob_radius, knob_color.darkened(0.5))
	draw_circle(_knob, knob_radius, knob_color.darkened(0.15))
	draw_circle(_knob - Vector2(0.0, knob_radius * 0.08), knob_radius * 0.82, knob_color)
	draw_set_transform(_knob - Vector2(0.0, knob_radius * 0.4), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, knob_radius * 0.5, Color(1.0, 1.0, 1.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
