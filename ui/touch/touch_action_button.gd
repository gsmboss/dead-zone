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
## Значки-«стикеры» вместо текста (game-icons.net, CC BY 3.0): действие → файл в ICON_DIR
const ICON_DIR: String = "res://ui/touch/icons/"
const ACTION_ICONS: Dictionary = {
	&"fire": "bullets",
	&"aim": "eye-target",
	&"jump": "jump-across",
	&"reload": "machine-gun-magazine",
	&"switch_weapon": "switch-weapon",
	&"slide": "foot-trip",
	&"throw": "flash-grenade",
	&"pause": "pause-button",
	&"camera_view": "video-camera",
	&"torch": "torch",
	&"inventory": "knapsack",
	&"interact": "car-key",
}
## Доля диаметра кнопки под значок
const ICON_SHARE: float = 0.58
## Скорость анимации нажатия
const PRESS_SPEED: float = 14.0

@export var action: StringName = &""
@export var label: String = ""
## Значок вместо подписи; пусто — по действию из ACTION_ICONS (нет значка — рисуется label)
@export var icon: Texture2D
## Маленькая надпись в углу поверх значка (например, сколько гранат)
var badge: String = ""
## Цвет из ACTION_COLORS по действию; иначе — base_color
@export var use_action_color: bool = true
@export var base_color: Color = DEFAULT_BUTTON_COLOR
## Непрозрачность кнопки (не закрывать обзор). Если use_settings_style — из Settings.button_opacity
@export_range(0.1, 1.0, 0.05) var opacity: float = 0.38
## Стиль, прозрачность и размер из настроек игрока (выключить — для превью и особых кнопок)
@export var use_settings_style: bool = true
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
var _style: int = 0  # Settings.ButtonStyle
static var _icon_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_action_valid = action != &"" and InputMap.has_action(action)
	if not _action_valid:
		push_warning("TouchActionButton '%s': действие '%s' не найдено в InputMap" % [name, action])
	_color = ACTION_COLORS.get(action, base_color) if use_action_color else base_color
	if icon == null:
		icon = load_icon(str(ACTION_ICONS.get(action, "")))
	set_process(show_aim_state)
	if use_settings_style:
		Settings.changed.connect(_on_settings_changed)
		_on_settings_changed()


func _on_settings_changed() -> void:
	opacity = Settings.button_opacity
	_style = Settings.button_style
	queue_redraw()


## Значок из ui/touch/icons по имени файла (без .svg); null — нет такого
static func load_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]
	var path: String = ICON_DIR + icon_name + ".svg"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture == null:
		push_warning("TouchActionButton: нет значка %s" % path)
	_icon_cache[icon_name] = texture
	return texture


## Сменить значок по имени (машина: ключ / сиденье / дверь выхода; дрифт — колесо)
func set_icon_name(icon_name: String) -> void:
	icon = load_icon(icon_name)
	queue_redraw()


## Стиль для превью (редактор раскладки)
func set_style(style: int, alpha: float) -> void:
	_style = style
	opacity = alpha
	queue_redraw()


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
	if _style == Settings.ButtonStyle.FLAT:
		draw_circle(size * 0.5, r, _with_alpha(color))
		draw_circle(size * 0.5, r * 0.9, _with_alpha(color.lightened(0.08)))
		if _aim_active:
			draw_arc(size * 0.5, r * 1.06, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.9), 3.0, false)
		_draw_label(size * 0.5, r)
		return
	if _style == Settings.ButtonStyle.OUTLINE:
		var ring_alpha: float = minf(opacity * 1.8 + 0.3 * p, 1.0)
		draw_circle(size * 0.5, r, Color(0.0, 0.0, 0.0, 0.12 * opacity + 0.2 * p))
		draw_arc(size * 0.5, r - 2.0, 0.0, TAU, 48, Color(color.lightened(0.4), ring_alpha), 4.0, false)
		if _aim_active:
			draw_arc(size * 0.5, r * 1.08, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.9), 3.0, false)
		_draw_label(size * 0.5, r)
		return

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

	_draw_label(center, r)


func _draw_label(center: Vector2, r: float) -> void:
	if icon != null and Settings.button_icons:
		_draw_icon(center, r)
		return
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


## Значок с тенью; badge — в правом нижнем углу
func _draw_icon(center: Vector2, r: float) -> void:
	var side: float = r * 2.0 * ICON_SHARE
	var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	draw_texture_rect(icon, Rect2(rect.position + Vector2(0.0, maxf(r * 0.04, 2.0)), rect.size), false,
		Color(0.0, 0.0, 0.0, 0.45))
	draw_texture_rect(icon, rect, false, label_color)
	if badge.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(10, int(r * 0.36))
	var text_size: Vector2 = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at: Vector2 = center + Vector2(r * 0.42, r * 0.42)
	draw_circle(at, maxf(text_size.x, text_size.y) * 0.62, Color(0.05, 0.05, 0.05, 0.85))
	draw_string(font, at + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.38), badge,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.4))


func _with_alpha(color: Color) -> Color:
	# Нажатая кнопка плотнее, чтобы был виден отклик
	var alpha: float = minf(opacity + 0.25 * _press_amount, 1.0)
	return Color(color.r, color.g, color.b, color.a * alpha)
