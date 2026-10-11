class_name TutorialDirector
extends CanvasLayer
## Обучение на полигоне (MissionData.tutorial): подсказки по шагам сверху экрана, пульсирующее кольцо
## вокруг нужной кнопки. Шаг засчитывается, когда игрок его сделал: ходьба, обзор, бег, прыжок,
## смена оружия, стрельба, прицел, перезарядка, первый зомби. Потом спавн включается — добить ещё
## несколько, и миссия (KILL_COUNT) завершается как обычная. «ПРОПУСТИТЬ» — сразу к бою.

const DONE_FLAG: String = "tutorial_done"
## Пауза «✓ ОТЛИЧНО!» между шагами
const STEP_PAUSE: float = 0.9
## Кнопка шага не видна столько секунд (например, перезарядка у ножа) — шаг пропускается
const HIDDEN_SKIP_TIME: float = 2.5
const MOVE_DISTANCE: float = 3.0
const LOOK_ANGLE: float = 1.5
const SPRINT_TIME: float = 0.8
const AIM_TIME: float = 0.5
const SHOTS_NEEDED: int = 3
const FINAL_HINT_TIME: float = 5.0

enum Step { MOVE, LOOK, SPRINT, JUMP, SWITCH, FIRE, AIM, RELOAD, FIRST_KILL, FINAL }

## [текст на телефоне, текст на ПК, действие кнопки для подсветки]
const STEPS: Array = [
	["ДВИГАЙСЯ: ВЕДИ ДЖОЙСТИК СЛЕВА", "ДВИГАЙСЯ: КЛАВИШИ W A S D", &""],
	["ОСМОТРИСЬ: ВЕДИ ПАЛЬЦЕМ ПО ПРАВОЙ ЧАСТИ ЭКРАНА", "ОСМОТРИСЬ: ДВИГАЙ МЫШЬЮ", &""],
	["БЕГ: ДЖОЙСТИК ДО УПОРА ВПЕРЁД", "БЕГ: ЗАЖМИ SHIFT И ИДИ ВПЕРЁД", &""],
	["ПРЫЖОК: НАЖМИ КНОПКУ", "ПРЫЖОК: ПРОБЕЛ", &"jump"],
	["СМЕНИ ОРУЖИЕ: НОЖ ↔ ПИСТОЛЕТ", "СМЕНИ ОРУЖИЕ: КЛАВИША Q", &"switch_weapon"],
	["СТРЕЛЯЙ: ЗАЖМИ КНОПКУ ОГНЯ", "СТРЕЛЯЙ: КЛАВИША F", &"fire"],
	["ПРИЦЕЛ: ЗАЖМИ КНОПКУ — ТОЧНЕЕ И ДАЛЬШЕ", "ПРИЦЕЛ: ЗАЖМИ Z ИЛИ ПРАВУЮ КНОПКУ МЫШИ", &"aim"],
	["ПЕРЕЗАРЯДКА: НАЖМИ КНОПКУ", "ПЕРЕЗАРЯДКА: КЛАВИША R", &"reload"],
	["ЗОМБИ! УБЕЙ ЕГО. В ГОЛОВУ — ДВОЙНОЙ УРОН", "ЗОМБИ! УБЕЙ ЕГО. В ГОЛОВУ — ДВОЙНОЙ УРОН", &""],
	["ОТЛИЧНО! ДОБЕЙ ОСТАЛЬНЫХ — И ОБУЧЕНИЕ ПРОЙДЕНО", "ОТЛИЧНО! ДОБЕЙ ОСТАЛЬНЫХ — И ОБУЧЕНИЕ ПРОЙДЕНО", &""],
]

var manager: MissionManager

var _player: Player
var _step: int = -1
var _pause: float = 0.0
var _progress: float = 0.0
var _start_position: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0
var _shots: int = 0
var _hidden_time: float = 0.0
var _spawn_retry: float = 0.0
var _touch: bool = true
var _panel: PanelContainer
var _counter: Label
var _hint: Label
var _pointer: Pointer
var _skip: Button


func _ready() -> void:
	layer = 30
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if manager == null or _player == null:
		push_warning("TutorialDirector: нет MissionManager или игрока — обучение выключено")
		_finish_hints()
		return
	_touch = DisplayServer.is_touchscreen_available()
	if _player.weapon_manager != null:
		_player.weapon_manager.fired.connect(func(_weapon: WeaponData) -> void: _shots += 1)
	_build_ui()
	_next_step()


func _process(delta: float) -> void:
	if _step < 0 or _player == null or not is_instance_valid(_player):
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_next_step()
		return
	if _step == Step.FINAL:
		_progress += delta
		if _progress >= FINAL_HINT_TIME:
			_finish_hints()
		return
	if _check_step(delta):
		_complete_step()


## Сделал ли игрок текущий шаг
func _check_step(delta: float) -> bool:
	match _step:
		Step.MOVE:
			return _player.global_position.distance_to(_start_position) >= MOVE_DISTANCE
		Step.LOOK:
			_progress += absf(wrapf(_player.rotation.y - _last_yaw, -PI, PI))
			_last_yaw = _player.rotation.y
			return _progress >= LOOK_ANGLE
		Step.SPRINT:
			if _player.sprinting:
				_progress += delta
			return _progress >= SPRINT_TIME
		Step.JUMP:
			return Input.is_action_just_pressed(&"jump") or not _player.is_on_floor()
		Step.SWITCH:
			return Input.is_action_just_pressed(&"switch_weapon") or _skip_if_hidden(delta)
		Step.FIRE:
			return _shots >= SHOTS_NEEDED or _skip_if_hidden(delta)
		Step.AIM:
			if Input.is_action_pressed(&"aim"):
				_progress += delta
			return _progress >= AIM_TIME or _skip_if_hidden(delta)
		Step.RELOAD:
			return Input.is_action_just_pressed(&"reload") or _skip_if_hidden(delta)
		Step.FIRST_KILL:
			if manager.kills >= 1:
				return true
			if manager.get_alive_count() <= 0:
				_spawn_retry -= delta
				if _spawn_retry <= 0.0:
					_spawn_retry = 1.0
					manager.spawn_single()
	return false


## Кнопки шага нет на экране (например, у ножа нет перезарядки) — не держим игрока
func _skip_if_hidden(delta: float) -> bool:
	var button: Control = _pointer.target
	if button != null and is_instance_valid(button) and button.is_visible_in_tree():
		_hidden_time = 0.0
		return false
	_hidden_time += delta
	return _hidden_time >= HIDDEN_SKIP_TIME


func _complete_step() -> void:
	Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.1, 0.0)
	_hint.text = "✓ ОТЛИЧНО!"
	_hint.modulate = UIKit.GOOD
	_pointer.target = null
	_pointer.mode = Pointer.Mode.NONE
	_pause = STEP_PAUSE


func _next_step() -> void:
	_step += 1
	_progress = 0.0
	_hidden_time = 0.0
	_shots = 0
	_start_position = _player.global_position
	_last_yaw = _player.rotation.y
	var entry: Array = STEPS[_step]
	_hint.text = str(entry[0] if _touch else entry[1])
	_hint.modulate = Color.WHITE
	_counter.text = UIKit.t("ОБУЧЕНИЕ  %d / %d") % [mini(_step + 1, STEPS.size()), STEPS.size()]
	_panel.scale = Vector2.ONE * 0.85
	_panel.pivot_offset = _panel.size * 0.5
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var action: StringName = entry[2]
	_pointer.target = _find_button(action) if action != &"" else null
	_pointer.mode = Pointer.Mode.RING if _pointer.target != null else Pointer.Mode.NONE
	if _touch:
		match _step:
			Step.MOVE, Step.SPRINT:
				_pointer.mode = Pointer.Mode.JOYSTICK
			Step.LOOK:
				_pointer.mode = Pointer.Mode.SWIPE
	match _step:
		Step.FIRST_KILL:
			manager.spawn_single()
			_spawn_retry = 1.0
		Step.FINAL:
			manager.spawning_enabled = true
			GameState.mark_cutscene_seen(DONE_FLAG)
			_skip.visible = false


func _find_button(action: StringName) -> Control:
	if _player.touch_controls == null:
		return null
	for node: Node in _player.touch_controls.find_children("*", "TouchActionButton", true, false):
		var button := node as TouchActionButton
		if button != null and button.action == action:
			return button
	return null


## Пропустить обучение: сразу обычный бой, подсказки убираются
func _on_skip() -> void:
	GameState.mark_cutscene_seen(DONE_FLAG)
	if manager != null:
		manager.spawning_enabled = true
	_finish_hints()


func _finish_hints() -> void:
	_step = -1
	set_process(false)
	if _panel == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
	if _pointer != null:
		_pointer.mode = Pointer.Mode.NONE
	if _skip != null:
		_skip.visible = false


# ---------- Интерфейс ----------

func _build_ui() -> void:
	_pointer = Pointer.new()
	add_child(_pointer)
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.05, 0.06, 0.08, 0.85), 16, 16.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -360.0
	_panel.offset_right = 360.0
	_panel.offset_top = 96.0
	_panel.offset_bottom = 200.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_panel.add_child(box)
	_counter = UIKit.label("", 18, box)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.modulate = UIKit.ACCENT
	_hint = UIKit.label("", 30, box)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_skip = UIKit.button("ПРОПУСТИТЬ", 20, 200.0)
	_skip.pressed.connect(_on_skip)
	add_child(_skip)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -230.0
	_skip.offset_right = -20.0
	_skip.offset_top = 96.0
	_skip.offset_bottom = 96.0 + UIKit.BUTTON_HEIGHT


## Подсказка-указатель: кольцо вокруг кнопки, «джойстик» слева или стрелка свайпа справа
class Pointer extends Control:
	enum Mode { NONE, RING, JOYSTICK, SWIPE }

	const COLOR: Color = Color(1.0, 0.85, 0.3)

	var target: Control
	var mode: Mode = Mode.NONE:
		set(value):
			mode = value
			queue_redraw()
	var _time: float = 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if mode == Mode.NONE:
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		match mode:
			Mode.RING:
				if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
					return
				var rect: Rect2 = target.get_global_rect()
				var center: Vector2 = rect.get_center() - get_global_rect().position
				var radius: float = maxf(rect.size.x, rect.size.y) * 0.5 + 10.0 + pulse * 10.0
				draw_arc(center, radius, 0.0, TAU, 48, Color(COLOR, 0.5 + pulse * 0.5), 6.0)
				draw_arc(center, radius + 14.0, 0.0, TAU, 48, Color(COLOR, 0.25 * pulse), 3.0)
			Mode.JOYSTICK:
				# Круг джойстика внизу слева и точка, которая «тянется» вверх
				var base := Vector2(size.x * 0.17, size.y * 0.72)
				draw_arc(base, 70.0, 0.0, TAU, 48, Color(COLOR, 0.7), 5.0)
				var knob: Vector2 = base + Vector2(0.0, -55.0 * fmod(_time * 0.8, 1.0))
				draw_circle(knob, 26.0, Color(COLOR, 0.8))
			Mode.SWIPE:
				# Палец едет вправо-влево по правой половине экрана
				var t: float = fmod(_time * 0.6, 1.0)
				var y: float = size.y * 0.5
				var from := Vector2(size.x * 0.58, y)
				var to := Vector2(size.x * 0.86, y)
				draw_line(from, to, Color(COLOR, 0.35), 4.0)
				draw_circle(from.lerp(to, t), 24.0, Color(COLOR, 0.85))
				draw_line(to, to + Vector2(-22.0, -16.0), Color(COLOR, 0.6), 4.0)
				draw_line(to, to + Vector2(-22.0, 16.0), Color(COLOR, 0.6), 4.0)
