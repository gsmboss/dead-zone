class_name TouchScroll
extends Node
## Прокрутка ScrollContainer свайпом пальца (и мышью с зажатой кнопкой) с инерцией.
## Встроенная прокрутка Godot не работает, если палец лёг на кнопку или карточку,
## поэтому листаем сами по событиям экрана. Если свайп начался на кнопке, она на время
## отключается — нажатие не срабатывает при прокрутке (важно для «КУПИТЬ»).

## Сдвиг пальца, после которого это свайп, а не нажатие
const DEADZONE: float = 14.0
## Затухание инерции (пикселей/с за секунду)
const FRICTION: float = 2400.0
const MAX_SPEED: float = 4000.0

var _scroll: ScrollContainer
var _touch_index: int = -1
var _start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _velocity: float = 0.0
var _blocked: BaseButton


## Подключить к контейнеру (повторный вызов ничего не делает)
static func attach(scroll: ScrollContainer) -> void:
	if scroll == null or scroll.has_node(^"TouchScroll"):
		return
	var helper := TouchScroll.new()
	helper.name = "TouchScroll"
	helper._scroll = scroll
	# Встроенная прокрутка перетаскиванием выключена — иначе будет двойная скорость
	scroll.scroll_deadzone = 100000
	scroll.add_child(helper)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS  # окна настроек открываются и на паузе


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if _touch_index == -1 and _scroll.get_global_rect().has_point(touch.position):
				_touch_index = touch.index
				_start = touch.position
				_dragging = false
				_velocity = 0.0
		elif touch.index == _touch_index:
			_touch_index = -1
			if _dragging:
				_dragging = false
				_unblock.call_deferred()  # после того как кнопка получит отпускание
		return
	var drag := event as InputEventScreenDrag
	if drag == null or drag.index != _touch_index:
		return
	if not _dragging and drag.position.distance_to(_start) > DEADZONE:
		var moved: Vector2 = drag.position - _start
		if absf(moved.x) > absf(moved.y):
			_touch_index = -1  # горизонтальное движение — это слайдер, не прокрутка
			return
		_dragging = true
		_block_button()
	if _dragging:
		_scroll.scroll_vertical -= roundi(drag.relative.y)
		var speed: float = -drag.velocity.y
		_velocity = clampf(speed, -MAX_SPEED, MAX_SPEED)


func _process(delta: float) -> void:
	if _touch_index != -1 or absf(_velocity) < 1.0:
		return
	_scroll.scroll_vertical += roundi(_velocity * delta)
	_velocity = move_toward(_velocity, 0.0, FRICTION * delta)


## Кнопка под пальцем на время свайпа выключена: отпускание не превратится в нажатие
func _block_button() -> void:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null and node != _scroll:
		var button := node as BaseButton
		if button != null:
			if not button.disabled:
				button.disabled = true
				_blocked = button
			return
		node = node.get_parent()


func _unblock() -> void:
	if _blocked != null and is_instance_valid(_blocked):
		_blocked.disabled = false
	_blocked = null
