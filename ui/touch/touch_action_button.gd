class_name TouchActionButton
extends Control
## Экранная кнопка в 3D-стиле: тень, ободок, объём, блик; при нажатии вдавливается.
## Нажатия передаёт TouchControls, кнопка жмёт действие Input Map.

## Цвет кнопки по действию (если use_action_color)
const ACTION_COLORS: Dictionary = {
	&"fire": Color(0.78, 0.16, 0.12),
	&"aim": Color(0.16, 0.45, 0.8),
	&"reload": Color(0.85, 0.6, 0.15),
	&"jump": Color(0.2, 0.62, 0.32),
	&"switch_weapon": Color(0.45, 0.47, 0.52),
}
const DEFAULT_BUTTON_COLOR: Color = Color(0.35, 0.37, 0.42)
## Скорость анимации нажатия
const PRESS_SPEED: float = 14.0

@export var action: StringName = &""
@export var label: String = ""
## Цвет из ACTION_COLORS по действию; иначе — base_color
@export var use_action_color: bool = true
@export var base_color: Color = DEFAULT_BUTTON_COLOR
## Непрозрачность кнопки (не закрывать обзор)
@export_range(0.1, 1.0, 0.05) var opacity: float = 0.38
@export var label_color: Color = Color(1, 1, 1, 0.95)
## Подсвечивать кнопку, пока оружие в прицеле (для кнопки прицела)
@export var show_aim_state: bool = false
## Запас зоны нажатия сверх видимого круга (пальцы неточные)
@export_range(1.0, 1.5, 0.05) var hit_padding: float = 1.15

var _touch_count: int = 0
var _action_valid: bool = false
var _press_amount: float = 0.0
var _color: Color = DEFAULT_BUTTON_COLOR
var _aim_active: bool = false
var _weapon_manager: WeaponManager


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_action_valid = action != &"" and InputMap.has_action(action)
	if not _action_valid:
		push_warning("TouchActionButton '%s': действие '%s' не найдено в InputMap" % [name, action])
	_color = ACTION_COLORS.get(action, base_color) if use_action_color else base_color
	set_process(show_aim_state)


func _process(delta: float) -> void:
	var target: float = 1.0 if is_pressed() else 0.0
	var changed: bool = not is_equal_approx(_press_amount, target)
	_press_amount = move_toward(_press_amount, target, PRESS_SPEED * delta)

	if show_aim_state:
		if _weapon_manager == null or not is_instance_valid(_weapon_manager):
			_weapon_manager = get_tree().get_first_node_in_group(&"weapon_manager") as WeaponManager
		var aiming: bool = _weapon_manager != null and _weapon_manager.is_aiming()
		if aiming != _aim_active:
			_aim_active = aiming
			changed = true
	elif not changed:
		set_process(false)  # анимация закончилась — не тратим кадры
	if changed:
		queue_redraw()


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
	set_process(true)
	queue_redraw()


func release() -> void:
	if _touch_count == 0:
		return
	_touch_count -= 1
	if _touch_count == 0 and _action_valid:
		Input.action_release(action)
	set_process(true)
	queue_redraw()


func force_release() -> void:
	if _touch_count == 0:
		return
	_touch_count = 0
	if _action_valid:
		Input.action_release(action)
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	force_release()


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var p: float = _press_amount
	var depth: float = r * 0.09
	# Кнопка опускается при нажатии: тень короче, корпус ниже
	var center: Vector2 = size * 0.5 + Vector2(0.0, depth * p)
	var color: Color = _color.lightened(0.25) if _aim_active else _color
	color = color.lightened(0.15 * p)

	# Тень
	draw_circle(size * 0.5 + Vector2(0.0, depth * 1.4), r, Color(0.0, 0.0, 0.0, 0.25 * opacity))
	# Боковина (объём) — темнее и ниже лицевой стороны
	draw_circle(center + Vector2(0.0, depth * (1.0 - p)), r, _with_alpha(color.darkened(0.55)))
	# Ободок
	draw_circle(center, r, _with_alpha(color.darkened(0.3)))
	# Лицевая сторона: низ темнее, верх светлее (имитация градиента)
	draw_circle(center, r * 0.86, _with_alpha(color.darkened(0.12)))
	draw_circle(center - Vector2(0.0, r * 0.06), r * 0.78, Color(color.r, color.g, color.b, 0.35))
	# Блик сверху (эллипс через масштаб)
	draw_set_transform(center - Vector2(0.0, r * 0.38), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 1.0, 1.0, 0.22 * (1.0 - p * 0.6) * opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _aim_active:
		draw_arc(center, r * 1.06, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.9), 3.0, false)

	if label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(8, int(r * 0.42))
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# Вертикальное центрирование по базовой линии, текст с тенью
	var baseline_y: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var text_pos := Vector2(center.x - text_size.x * 0.5, baseline_y)
	draw_string(font, text_pos + Vector2(0.0, 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)


func _with_alpha(color: Color) -> Color:
	# Нажатая кнопка плотнее, чтобы был виден отклик
	var alpha: float = minf(opacity + 0.25 * _press_amount, 1.0)
	return Color(color.r, color.g, color.b, color.a * alpha)
