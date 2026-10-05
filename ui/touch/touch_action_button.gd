class_name TouchActionButton
extends Control
## Экранная кнопка. Нажатия передаёт TouchControls, кнопка жмёт действие Input Map.

@export var action: StringName = &""
@export var label: String = ""
@export var idle_color: Color = Color(1, 1, 1, 0.18)
@export var pressed_color: Color = Color(1, 1, 1, 0.45)
@export var label_color: Color = Color(1, 1, 1, 0.9)
## Запас зоны нажатия сверх видимого круга (пальцы неточные)
@export_range(1.0, 1.5, 0.05) var hit_padding: float = 1.15

var _touch_count: int = 0
var _action_valid: bool = false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_action_valid = action != &"" and InputMap.has_action(action)
	if not _action_valid:
		push_warning("TouchActionButton '%s': действие '%s' не найдено в InputMap" % [name, action])


func is_pressed() -> bool:
	return _touch_count > 0


func contains_viewport_point(viewport_pos: Vector2) -> bool:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_pos
	var r: float = minf(size.x, size.y) * 0.5
	return local.distance_to(size * 0.5) <= r * hit_padding


func press() -> void:
	_touch_count += 1
	if _touch_count == 1 and _action_valid:
		Input.action_press(action)
	queue_redraw()


func release() -> void:
	if _touch_count == 0:
		return
	_touch_count -= 1
	if _touch_count == 0 and _action_valid:
		Input.action_release(action)
	queue_redraw()


func force_release() -> void:
	if _touch_count == 0:
		return
	_touch_count = 0
	if _action_valid:
		Input.action_release(action)
	queue_redraw()


func _exit_tree() -> void:
	force_release()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	draw_circle(center, r, pressed_color if is_pressed() else idle_color)

	if label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(8, int(r * 0.45))
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# Вертикальное центрирование по базовой линии
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(center.x - text_size.x * 0.5, baseline_y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
