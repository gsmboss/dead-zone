class_name ControlLayoutEditor
extends CanvasLayer
## Редактор раскладки кнопок: превью всех экранных кнопок, перетаскивание пальцем,
## зона джойстика (перетащить на другую сторону), «ЗЕРКАЛО», «СБРОС», «СОХРАНИТЬ».
## Открывается из настроек (в убежище и на паузе). Сохраняет в Settings.set_layout().

signal closed

## Редактор открыт: «Назад»/пауза закрывает его, а не окна под ним
static var is_open: bool = false

const BACKGROUND: Color = Color(0.03, 0.035, 0.04, 0.9)
const ZONE_COLOR: Color = Color(0.25, 0.5, 0.9, 0.18)
const ZONE_BORDER: Color = Color(0.45, 0.7, 1.0, 0.7)
const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.3, 0.9)
## Сдвиг меньше этого (px) от стандартного места не сохраняется — кнопка «по умолчанию»
const SAME_PLACE: float = 3.0

var _root: Control
var _zone: Panel
var _zone_label: Label
var _buttons: Dictionary = {}  # действие → TouchActionButton (превью)
var _centers: Dictionary = {}  # действие → центр (px)
var _joystick_right: bool = false
var _dragging: StringName = &""
var _dragging_zone: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _selection: Control


## Открыть поверх текущей сцены
static func open(tree: SceneTree) -> ControlLayoutEditor:
	var editor := ControlLayoutEditor.new()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(editor)
	return editor


func _ready() -> void:
	is_open = true
	layer = 60
	process_mode = PROCESS_MODE_ALWAYS  # работает и на паузе
	_joystick_right = Settings.joystick_right
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout.call_deferred()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	# Зона джойстика
	_zone = Panel.new()
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone_style := StyleBoxFlat.new()
	zone_style.bg_color = ZONE_COLOR
	zone_style.border_color = ZONE_BORDER
	zone_style.set_border_width_all(3)
	zone_style.set_corner_radius_all(16)
	_zone.add_theme_stylebox_override(&"panel", zone_style)
	_root.add_child(_zone)
	_zone_label = UIKit.label("ДЖОЙСТИК\n(ПЕРЕТАЩИ НА ДРУГУЮ СТОРОНУ)", 26, _zone)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zone_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zone_label.modulate = Color(0.7, 0.85, 1.0)

	# Превью кнопок в выбранном стиле
	for action: StringName in ControlLayout.DEFAULTS:
		var entry: Array = ControlLayout.DEFAULTS[action]
		var button := TouchActionButton.new()
		button.use_settings_style = false
		button.action = action
		button.label = entry[3]
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(button)
		button.set_style(Settings.button_style, maxf(Settings.button_opacity, 0.6))
		_buttons[action] = button

	# Рамка выбранной кнопки
	_selection = Control.new()
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection.visible = false
	_selection.draw.connect(_draw_selection)
	_root.add_child(_selection)

	# Подсказка и панель действий сверху по центру
	var top := VBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 16.0
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 12)
	top.add_child(bar)
	_add_bar_button(bar, "ЗЕРКАЛО", _mirror)
	_add_bar_button(bar, "СБРОС", _reset)
	_add_bar_button(bar, "ОТМЕНА", _close)
	var save := _add_bar_button(bar, "СОХРАНИТЬ", _save)
	save.modulate = UIKit.GOOD
	var hint := UIKit.label("ПЕРЕТАСКИВАЙ КНОПКИ ПАЛЬЦЕМ", 22, top)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = UIKit.DIM


func _add_bar_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := UIKit.button(text, 24, 190.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


## Стартовые позиции: своя раскладка или стандартная
func _relayout() -> void:
	var screen: Vector2 = _screen()
	if _centers.is_empty():
		for action: StringName in _buttons:
			_centers[action] = ControlLayout.center_for(action, screen)
	for action: StringName in _buttons:
		_place(action)
	_place_zone()


func _place(action: StringName) -> void:
	var button: TouchActionButton = _buttons[action]
	var entry: Array = ControlLayout.DEFAULTS[action]
	var diameter: float = float(entry[2]) * Settings.button_scale
	var screen: Vector2 = _screen()
	var center: Vector2 = _centers[action]
	center.x = clampf(center.x, diameter * 0.5, maxf(diameter * 0.5, screen.x - diameter * 0.5))
	center.y = clampf(center.y, diameter * 0.5, maxf(diameter * 0.5, screen.y - diameter * 0.5))
	_centers[action] = center
	button.position = center - Vector2.ONE * diameter * 0.5
	button.size = Vector2.ONE * diameter
	if _dragging == action:
		_selection.position = button.position
		_selection.size = button.size
		_selection.queue_redraw()


func _place_zone() -> void:
	var screen: Vector2 = _screen()
	var width: float = screen.x * ControlLayout.JOYSTICK_ZONE
	_zone.position = Vector2(screen.x - width if _joystick_right else 0.0, screen.y * 0.35)
	_zone.size = Vector2(width, screen.y * 0.65)


func _on_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin_drag(mouse_button.position)
		else:
			_end_drag()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and (_dragging != &"" or _dragging_zone):
		_drag(motion.position)


func _begin_drag(pos: Vector2) -> void:
	# Верхняя (последняя добавленная) кнопка под пальцем
	var best: StringName = &""
	var best_distance: float = INF
	for action: StringName in _buttons:
		var button: TouchActionButton = _buttons[action]
		var radius: float = button.size.x * 0.5
		var distance: float = pos.distance_to(_centers[action])
		if distance <= radius * 1.1 and distance < best_distance:
			best = action
			best_distance = distance
	if best != &"":
		_dragging = best
		_grab_offset = _centers[best] - pos
		_selection.visible = true
		_place(best)
		Sfx.click()
		return
	if Rect2(_zone.position, _zone.size).has_point(pos):
		_dragging_zone = true
		Sfx.click()


func _drag(pos: Vector2) -> void:
	if _dragging != &"":
		_centers[_dragging] = pos + _grab_offset
		_place(_dragging)
	elif _dragging_zone:
		var right: bool = pos.x > _screen().x * 0.5
		if right != _joystick_right:
			_joystick_right = right
			_place_zone()


func _end_drag() -> void:
	_dragging = &""
	_dragging_zone = false
	_selection.visible = false


func _draw_selection() -> void:
	var radius: float = _selection.size.x * 0.5
	_selection.draw_arc(_selection.size * 0.5, radius + 6.0, 0.0, TAU, 48, SELECTED_COLOR, 4.0, false)


## Зеркально: кнопки на другую сторону, джойстик тоже
func _mirror() -> void:
	var screen: Vector2 = _screen()
	for action: StringName in _centers:
		var center: Vector2 = _centers[action]
		_centers[action] = Vector2(screen.x - center.x, center.y)
		_place(action)
	_joystick_right = not _joystick_right
	_place_zone()
	Sfx.click()


func _reset() -> void:
	var screen: Vector2 = _screen()
	for action: StringName in _buttons:
		_centers[action] = ControlLayout.default_center(action, screen)
		_place(action)
	_joystick_right = false
	_place_zone()
	Sfx.click()


func _save() -> void:
	var screen: Vector2 = _screen()
	var layout: Dictionary = {}
	for action: StringName in _centers:
		var center: Vector2 = _centers[action]
		if center.distance_to(ControlLayout.default_center(action, screen)) > SAME_PLACE:
			layout[String(action)] = center / screen
	Settings.set_layout(layout, _joystick_right)
	Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.0, 0.0)
	_close()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		_close()


func _exit_tree() -> void:
	is_open = false


func _close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _screen() -> Vector2:
	var screen: Vector2 = _root.get_viewport_rect().size if _root != null else Vector2.ZERO
	return Vector2(maxf(screen.x, 1.0), maxf(screen.y, 1.0))
