class_name TouchControls
extends Control
## Мультитач: джойстик движения, обзор свайпом, кнопки действий.
## Приоритет при касании: кнопка → зона джойстика → обзор.

@export var joystick: TouchJoystick
## Скрывать управление на устройствах без тачскрина
@export var hide_without_touchscreen: bool = false

var _buttons: Array[TouchActionButton] = []
var _button_touches: Dictionary = {}  # индекс пальца -> TouchActionButton
var _joystick_index: int = -1
var _look_index: int = -1
var _look_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_collect_buttons(self)
	if joystick == null:
		push_error("TouchControls: не назначен joystick")
	if hide_without_touchscreen and not DisplayServer.is_touchscreen_available():
		hide()
	visibility_changed.connect(_on_visibility_changed)
	# Раскладка из настроек: позиции, размер кнопок, сторона джойстика
	Settings.changed.connect(apply_layout)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout.call_deferred()


## Расставить кнопки и джойстик по настройкам (своя раскладка, размер)
func apply_layout() -> void:
	if not is_inside_tree():
		return
	var screen: Vector2 = get_viewport_rect().size
	for button: TouchActionButton in _buttons:
		if is_instance_valid(button):
			ControlLayout.apply_to_button(button, screen)
	ControlLayout.apply_to_joystick(joystick)


## Вектор движения -1..1 (вперёд = -Y)
func get_move_vector() -> Vector2:
	return joystick.output if joystick != null else Vector2.ZERO


## Накопленный сдвиг обзора в пикселях с прошлого вызова
func consume_look_delta() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta


## Кнопка, созданная кодом после _ready (меню, машина)
func register_button(button: TouchActionButton) -> void:
	if button != null and not button in _buttons:
		_buttons.append(button)
		if is_inside_tree():
			ControlLayout.apply_to_button(button, get_viewport_rect().size)


func unregister_button(button: TouchActionButton) -> void:
	if button == null:
		return
	button.force_release()
	_buttons.erase(button)
	for index: int in _button_touches.keys():
		if _button_touches[index] == button:
			_button_touches.erase(index)


func reset_all() -> void:
	for button: TouchActionButton in _buttons:
		if is_instance_valid(button):
			button.force_release()
	_button_touches.clear()
	if joystick != null:
		joystick.end()
	_joystick_index = -1
	_look_index = -1
	_look_delta = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_touch_dragged(drag.index, drag.position, drag.relative)


func _on_touch_pressed(index: int, pos: Vector2) -> void:
	# Защита от повторного press с тем же индексом без release
	_on_touch_released(index)

	for button: TouchActionButton in _buttons:
		if is_instance_valid(button) and button.is_visible_in_tree() \
				and button.contains_viewport_point(pos):
			button.press()
			_button_touches[index] = button
			return

	if joystick != null and _joystick_index == -1 and joystick.is_visible_in_tree() \
			and joystick.contains_viewport_point(pos):
		_joystick_index = index
		joystick.begin(pos)
		return

	if _look_index == -1:
		_look_index = index


func _on_touch_released(index: int) -> void:
	if _button_touches.has(index):
		var button: TouchActionButton = _button_touches[index]
		if is_instance_valid(button):
			button.release()
		_button_touches.erase(index)
	if index == _joystick_index:
		_joystick_index = -1
		if joystick != null:
			joystick.end()
	if index == _look_index:
		_look_index = -1


func _on_touch_dragged(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joystick_index and joystick != null:
		joystick.drag(pos)
	elif index == _look_index:
		_look_delta += relative


func _collect_buttons(node: Node) -> void:
	for child: Node in node.get_children():
		if child is TouchActionButton:
			_buttons.append(child)
		_collect_buttons(child)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		reset_all()


func _notification(what: int) -> void:
	# Игра свернута / пришёл звонок — отпускаем всё, чтобы не было залипания
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			reset_all()
