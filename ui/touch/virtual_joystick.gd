class_name TouchJoystick
extends Control
## Плавающий джойстик. Сам не читает ввод — им управляет TouchControls.
## (Имя TouchJoystick: в Godot 4.7+ есть встроенный класс VirtualJoystick)

@export var radius: float = 110.0
@export_range(0.0, 0.9, 0.01) var deadzone: float = 0.12
@export var base_color: Color = Color(1, 1, 1, 0.12)
@export var ring_color: Color = Color(1, 1, 1, 0.35)
@export var knob_color: Color = Color(1, 1, 1, 0.5)

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
	_active = true
	_center = _to_local(viewport_pos)
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
	var offset: Vector2 = (_to_local(viewport_pos) - _center).limit_length(radius)
	_knob = _center + offset

	var raw: Vector2 = offset / radius
	var magnitude: float = minf(raw.length(), 1.0)
	if magnitude < deadzone:
		output = Vector2.ZERO
	else:
		# Ремап мёртвой зоны: движение плавно стартует от 0, а не скачком
		output = raw.normalized() * inverse_lerp(deadzone, 1.0, magnitude)
	queue_redraw()


func _to_local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos


func _rest_center() -> Vector2:
	return Vector2(radius * 1.5, size.y - radius * 1.5)


func _on_resized() -> void:
	if not _active:
		end()


func _draw() -> void:
	draw_circle(_center, radius, base_color)
	draw_arc(_center, radius, 0.0, TAU, 48, ring_color, 3.0, true)
	draw_circle(_knob, radius * 0.4, knob_color)
