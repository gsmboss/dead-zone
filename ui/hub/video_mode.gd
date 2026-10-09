class_name VideoMode
extends CanvasLayer
## Режим съёмки персонажа (видеокамера в убежище). Ракурсы: ШТАТИВ — камера стоит, следит за
## игроком (можно ходить), СЛЕЖКА — едет за спиной (можно ходить), ОБЛЁТ — кружит вокруг
## (свайп крутит, сам облетает), КРУПНО — лицо (свайп крутит). Зум «+ / −», ПРИВЕТ — помахать.
## ЗАПИСЬ — чистый экран без кнопок и рамки (для записи экрана телефона); двойной тап или «назад» —
## вернуть кнопки. Сама игра видео не пишет: на Android это делает запись экрана системы.

signal closed

enum Shot { TRIPOD, FOLLOW, ORBIT, CLOSE }

const SHOT_NAMES: PackedStringArray = ["ШТАТИВ", "СЛЕЖКА", "ОБЛЁТ", "КРУПНО"]
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 1.25
const ORBIT_DISTANCE: float = 3.4
const CLOSE_DISTANCE: float = 1.3
const FOLLOW_DISTANCE: float = 4.2
const FOLLOW_HEIGHT: float = 1.0
## Облёт сам крутится, если свайпа не было столько секунд
const AUTO_ORBIT_DELAY: float = 2.0
const AUTO_ORBIT_SPEED: float = 0.3
const SWIPE_SPEED: float = 0.006
const SMOOTH: float = 6.0
const HINT_TIME: float = 3.0

## Открыт ли режим (телевизор в зоне отдыха не тратит кадры)
static var is_open: bool = false
## Ракурс запоминается между открытиями
static var _shot: int = Shot.TRIPOD

var tripod: Transform3D

var _player: Player
var _hud: Control
var _camera: Camera3D
var _ui: Control
var _viewfinder: Viewfinder
var _hint: Label
var _tabs: Control
var _zoom: float = 1.0
var _yaw: float = 0.0
var _pitch: float = 0.25
var _idle_swipe: float = 10.0
var _clean: bool = false
var _time: float = 0.0
var _look: Vector3 = Vector3.ZERO
var _saved_input: bool = true


## Открыть съёмку с камеры, стоящей в lens (объектив смотрит в -Z)
static func open(tree: SceneTree, lens: Transform3D) -> VideoMode:
	var mode := VideoMode.new()
	mode.tripod = lens
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(mode)
	return mode


## Угол обзора, при котором человек на расстоянии distance виден целиком (zoom > 1 — ближе)
static func framing_fov(distance: float, zoom: float) -> float:
	var fov: float = rad_to_deg(2.0 * atan(1.25 / maxf(distance, 0.5)))
	return clampf(fov / maxf(zoom, 0.1), 8.0, 75.0)


func _ready() -> void:
	layer = 40
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("VideoMode: игрок (группа \"player\") не найден")
		queue_free.call_deferred()
		return
	is_open = true
	_saved_input = _player.input_enabled
	_hud = get_tree().get_first_node_in_group(&"hub_hud") as Control
	if _hud != null:
		_hud.visible = false
		_hud.process_mode = Node.PROCESS_MODE_DISABLED
	Ads.hide_banner()
	_player.add_body_viewer()
	_camera = Camera3D.new()
	_camera.name = "VideoCamera"
	_camera.near = 0.05
	_camera.far = 300.0
	add_child(_camera)
	_camera.global_transform = tripod
	_camera.make_current()
	_look = _target()
	_yaw = _player.rotation.y
	_build_ui()
	_apply_shot()


func _exit_tree() -> void:
	if not is_open:
		return
	is_open = false
	if _player != null and is_instance_valid(_player):
		_player.remove_body_viewer()
		_player.input_enabled = _saved_input
		if _player.camera != null:
			_player.camera.make_current()
		if _player.touch_controls != null:
			_player.touch_controls.modulate.a = 1.0
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
		_hud.process_mode = Node.PROCESS_MODE_INHERIT
		Ads.show_banner()


func close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_time += delta
	_idle_swipe += delta
	if _viewfinder != null:
		_viewfinder.set_time(_time)
	var k: float = 1.0 - exp(-SMOOTH * delta)
	match _shot:
		Shot.TRIPOD:
			_look = _look.lerp(_target(), k)
			_place_camera(tripod.origin, _look)
			_camera.fov = framing_fov(tripod.origin.distance_to(_look), _zoom)
		Shot.FOLLOW:
			var forward: Vector3 = _forward()
			var wanted: Vector3 = _player.global_position - forward * (FOLLOW_DISTANCE / _zoom) \
				+ Vector3.UP * (FOLLOW_HEIGHT + _player.head.position.y)
			_look = _look.lerp(_target() + forward * 1.5, k)
			_place_camera(_camera.global_position.lerp(wanted, k), _look)
			_camera.fov = 60.0
		Shot.ORBIT:
			if _idle_swipe > AUTO_ORBIT_DELAY:
				_yaw += AUTO_ORBIT_SPEED * delta
			_look = _look.lerp(_target(), k)
			_place_camera(_look + _orbit_offset(ORBIT_DISTANCE / _zoom), _look)
			_camera.fov = 55.0
		Shot.CLOSE:
			var face: Vector3 = _player.head.global_position + Vector3.DOWN * 0.1
			_look = _look.lerp(face, k)
			_place_camera(_look + _orbit_offset(CLOSE_DISTANCE / _zoom), _look)
			_camera.fov = 45.0


func _input(event: InputEvent) -> void:
	if _clean:
		var double_tap: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).double_tap) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).double_click)
		if double_tap:
			get_viewport().set_input_as_handled()
			_set_clean(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _clean:
			_set_clean(false)
		else:
			close()
		return
	if _shot != Shot.ORBIT and _shot != Shot.CLOSE:
		return
	# Свайп крутит камеру (на ПК мышь превращается в касания — pointing/emulate_touch_from_mouse)
	var drag: Vector2 = Vector2.ZERO
	if event is InputEventScreenDrag:
		drag = (event as InputEventScreenDrag).relative
	if drag != Vector2.ZERO:
		_yaw -= drag.x * SWIPE_SPEED
		_pitch = clampf(_pitch + drag.y * SWIPE_SPEED, -0.35, 1.2)
		_idle_swipe = 0.0


## Грудь игрока (сидя — ниже: голова опускается)
func _target() -> Vector3:
	return _player.head.global_position + Vector3.DOWN * 0.55


func _forward() -> Vector3:
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD


func _orbit_offset(distance: float) -> Vector3:
	return Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * distance


func _place_camera(at: Vector3, look: Vector3) -> void:
	_camera.global_position = at
	if at.distance_squared_to(look) > 0.0004:
		_camera.look_at(look, Vector3.UP)


## Ходить можно в ШТАТИВЕ и СЛЕЖКЕ; в облёте и крупном плане свайп крутит камеру, а не игрока
func _apply_shot() -> void:
	var walking: bool = _shot == Shot.TRIPOD or _shot == Shot.FOLLOW
	_player.input_enabled = walking
	if _player.touch_controls != null:
		_player.touch_controls.visible = true
		_player.touch_controls.modulate.a = 0.0 if _clean or not walking else 1.0
		if not walking:
			_player.touch_controls.reset_all()
	if _shot == Shot.CLOSE:
		# Крупный план — спереди (лицо смотрит в -Z игрока)
		_yaw = _player.rotation.y + PI
		_pitch = 0.05
	elif _shot == Shot.ORBIT:
		_pitch = 0.3
	_idle_swipe = 10.0
	if _viewfinder != null:
		_viewfinder.shot_name = SHOT_NAMES[_shot]
		_viewfinder.queue_redraw()


func _select_shot(index: int) -> void:
	_shot = index
	_apply_shot()
	_rebuild_tabs()


func _change_zoom(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if _viewfinder != null:
		_viewfinder.zoom = _zoom
		_viewfinder.queue_redraw()


## Чистый экран: без кнопок, рамки и (в облёте) джойстика — только картинка
func _set_clean(enabled: bool) -> void:
	_clean = enabled
	_ui.visible = not enabled
	_viewfinder.visible = not enabled
	_apply_shot()
	if enabled:
		_show_hint("ВКЛЮЧИ ЗАПИСЬ ЭКРАНА НА ТЕЛЕФОНЕ\nДВОЙНОЙ ТАП — ВЕРНУТЬ КНОПКИ")


func _show_hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	var tween := _hint.create_tween()
	tween.tween_interval(HINT_TIME)
	tween.tween_property(_hint, "modulate:a", 0.0, 0.6)


# ---------- Интерфейс ----------

func _build_ui() -> void:
	_viewfinder = Viewfinder.new()
	_viewfinder.shot_name = SHOT_NAMES[_shot]
	add_child(_viewfinder)
	_viewfinder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_rebuild_tabs()

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	_ui.add_child(column)
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.offset_left = -236.0
	column.offset_right = -20.0
	column.offset_top = 104.0
	column.offset_bottom = 104.0
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override(&"separation", 10)
	column.add_child(zoom_row)
	var zoom_in := UIKit.button("+", 34, 103.0)
	zoom_in.pressed.connect(_change_zoom.bind(ZOOM_STEP))
	zoom_row.add_child(zoom_in)
	var zoom_out := UIKit.button("−", 34, 103.0)
	zoom_out.pressed.connect(_change_zoom.bind(1.0 / ZOOM_STEP))
	zoom_row.add_child(zoom_out)
	var wave := UIKit.button("ПРИВЕТ", 24, 216.0)
	wave.pressed.connect(func() -> void:
		if _player.body != null and not _player.seated:
			_player.body.play_emote())
	column.add_child(wave)
	var record := UIKit.button("● ЗАПИСЬ", 24, 216.0)
	record.modulate = Color(1.0, 0.6, 0.6)
	record.pressed.connect(_set_clean.bind(true))
	column.add_child(record)
	var exit := UIKit.button("ВЫХОД", 24, 216.0)
	exit.pressed.connect(close)
	column.add_child(exit)

	_hint = UIKit.label("", 26)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -420.0
	_hint.offset_right = 420.0
	_hint.offset_top = 120.0
	_hint.offset_bottom = 220.0
	_show_hint("ПОХОДИ ПЕРЕД КАМЕРОЙ ИЛИ ВЫБЕРИ РАКУРС")


func _rebuild_tabs() -> void:
	if _tabs != null:
		_tabs.queue_free()
	_tabs = UIKit.tab_bar(SHOT_NAMES, _shot, _select_shot)
	_ui.add_child(_tabs)
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tabs.offset_left = 24.0
	_tabs.offset_right = -256.0
	_tabs.offset_top = 16.0
	_tabs.offset_bottom = 16.0 + UIKit.BUTTON_HEIGHT


## Рамка видоискателя: уголки, «● REC» с таймером, ракурс и зум
class Viewfinder extends Control:
	const CORNER: float = 48.0
	const MARGIN: float = 28.0
	const LINE: float = 4.0

	var shot_name: String = ""
	var zoom: float = 1.0
	var _seconds: int = -1
	var _blink: bool = true

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_time(time: float) -> void:
		var seconds: int = floori(time)
		var blink: bool = fmod(time, 1.0) < 0.6
		if seconds != _seconds or blink != _blink:
			_seconds = seconds
			_blink = blink
			queue_redraw()

	func _draw() -> void:
		var color := Color(1.0, 1.0, 1.0, 0.85)
		var left: float = MARGIN
		var top: float = MARGIN + 90.0  # под вкладками ракурсов
		var right: float = size.x - MARGIN
		var bottom: float = size.y - MARGIN
		for corner: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
			var dx: float = CORNER if corner.x < size.x * 0.5 else -CORNER
			var dy: float = CORNER if corner.y < size.y * 0.5 else -CORNER
			draw_line(corner, corner + Vector2(dx, 0.0), color, LINE)
			draw_line(corner, corner + Vector2(0.0, dy), color, LINE)
		# Перекрестие в центре
		var center: Vector2 = size * 0.5
		draw_line(center - Vector2(18.0, 0.0), center + Vector2(18.0, 0.0), Color(color, 0.5), 2.0)
		draw_line(center - Vector2(0.0, 18.0), center + Vector2(0.0, 18.0), Color(color, 0.5), 2.0)
		var font: Font = ThemeDB.fallback_font
		if _blink:
			draw_circle(Vector2(left + 26.0, top + 30.0), 10.0, Color(1.0, 0.15, 0.15))
		var clock: String = "REC  %02d:%02d" % [floori(_seconds / 60.0), _seconds % 60]
		draw_string_outline(font, Vector2(left + 46.0, top + 40.0), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6,
			Color(0.0, 0.0, 0.0, 0.7))
		draw_string(font, Vector2(left + 46.0, top + 40.0), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
		var info: String = "%s   ×%.1f" % [UIKit.t(shot_name), zoom]
		draw_string_outline(font, Vector2(left + 16.0, bottom - 16.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6,
			Color(0.0, 0.0, 0.0, 0.7))
		draw_string(font, Vector2(left + 16.0, bottom - 16.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
