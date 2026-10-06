class_name ControlLayout
extends RefCounted
## Раскладка экранного управления: стандартные места кнопок (как в сценах уровней,
## GameMenus и DriveController) для редактора раскладки и пересчёт кнопок в игре
## по настройкам (свои позиции, размер, сторона джойстика).

## Действие → [якорь (доли экрана), центр относительно якоря (px), диаметр (px), подпись]
const DEFAULTS: Dictionary = {
	&"fire": [Vector2(1.0, 1.0), Vector2(-145.0, -145.0), 170.0, "FIRE"],
	&"aim": [Vector2(1.0, 1.0), Vector2(-420.0, -240.0), 120.0, "ПРИЦЕЛ"],
	&"jump": [Vector2(1.0, 1.0), Vector2(-315.0, -115.0), 110.0, "JUMP"],
	&"reload": [Vector2(1.0, 1.0), Vector2(-150.0, -330.0), 100.0, "R"],
	&"switch_weapon": [Vector2(1.0, 1.0), Vector2(-280.0, -330.0), 100.0, "⇄"],
	&"slide": [Vector2(1.0, 1.0), Vector2(-455.0, -115.0), 90.0, "ПОДКАТ"],
	&"throw": [Vector2(1.0, 1.0), Vector2(-95.0, -455.0), 90.0, "ГРАНАТА"],
	&"interact": [Vector2(1.0, 0.5), Vector2(-105.0, -40.0), 130.0, "СЕСТЬ"],
	&"pause": [Vector2(1.0, 0.0), Vector2(-75.0, 175.0), 90.0, "II"],
	&"camera_view": [Vector2(1.0, 0.0), Vector2(-185.0, 175.0), 90.0, "ВИД"],
	&"torch": [Vector2(1.0, 0.0), Vector2(-295.0, 175.0), 90.0, "ФАКЕЛ"],
	&"inventory": [Vector2(0.0, 0.0), Vector2(69.0, 155.0), 90.0, "СУМКА"],
}
## Зона джойстика по ширине экрана (слева; при joystick_right — зеркально справа)
const JOYSTICK_ZONE: float = 0.4
const META_RECT: StringName = &"layout_original"


## Стандартный центр кнопки в пикселях экрана
static func default_center(action: StringName, screen: Vector2) -> Vector2:
	var entry: Array = DEFAULTS.get(action, [])
	if entry.size() < 2:
		return screen * 0.5
	var anchor: Vector2 = entry[0]
	var offset: Vector2 = entry[1]
	return anchor * screen + offset


## Центр кнопки с учётом своей раскладки
static func center_for(action: StringName, screen: Vector2) -> Vector2:
	var custom: Vector2 = Settings.get_button_position(action)
	return custom * screen if custom.is_finite() else default_center(action, screen)


## Поставить кнопку по настройкам: своя позиция (если есть) и размер button_scale.
## Исходные якоря и отступы запоминаются при первом вызове — от них считается «по умолчанию»
static func apply_to_button(button: TouchActionButton, screen: Vector2) -> void:
	if button == null or screen.x <= 0.0 or screen.y <= 0.0:
		return
	if not button.has_meta(META_RECT):
		button.set_meta(META_RECT, [button.anchor_left, button.anchor_top, button.anchor_right,
			button.anchor_bottom, button.offset_left, button.offset_top, button.offset_right,
			button.offset_bottom])
	var original: Array = button.get_meta(META_RECT)
	var top_left := Vector2(original[0] * screen.x + original[4], original[1] * screen.y + original[5])
	var bottom_right := Vector2(original[2] * screen.x + original[6], original[3] * screen.y + original[7])
	var base_size: Vector2 = (bottom_right - top_left).abs()
	var center: Vector2 = (top_left + bottom_right) * 0.5
	var custom: Vector2 = Settings.get_button_position(button.action)
	if custom.is_finite():
		center = custom * screen
	var new_size: Vector2 = base_size * Settings.button_scale
	# Не даём кнопке уйти за край экрана
	center.x = clampf(center.x, new_size.x * 0.5, maxf(new_size.x * 0.5, screen.x - new_size.x * 0.5))
	center.y = clampf(center.y, new_size.y * 0.5, maxf(new_size.y * 0.5, screen.y - new_size.y * 0.5))
	button.anchor_left = 0.0
	button.anchor_top = 0.0
	button.anchor_right = 0.0
	button.anchor_bottom = 0.0
	button.offset_left = center.x - new_size.x * 0.5
	button.offset_top = center.y - new_size.y * 0.5
	button.offset_right = center.x + new_size.x * 0.5
	button.offset_bottom = center.y + new_size.y * 0.5


## Зона джойстика: слева или справа
static func apply_to_joystick(joystick: TouchJoystick) -> void:
	if joystick == null:
		return
	var right: bool = Settings.joystick_right
	joystick.anchor_left = 1.0 - JOYSTICK_ZONE if right else 0.0
	joystick.anchor_right = 1.0 if right else JOYSTICK_ZONE
	joystick.anchor_top = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 0.0
	joystick.offset_top = 0.0
	joystick.offset_right = 0.0
	joystick.offset_bottom = 0.0
	joystick.mirrored = right
