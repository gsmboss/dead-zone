class_name CutscenePlayer
extends CanvasLayer
## Проигрывает CutsceneData: своя камера летит по планам, чёрные полосы, субтитры,
## кнопка «ПРОПУСТИТЬ». На время сцены: управление игрока выключено, HUD скрыт,
## игровое время можно замедлить (time_scale). Сама удаляется после finished.

signal finished

## Идёт кат-сцена (меню паузы её не прерывает)
static var active: bool = false
## Кадр окончания: в этот же кадр «пауза»/«пропуск» не должны открыть меню
static var _ended_frame: int = -10


## Кат-сцена идёт или только что закончилась (ввод паузы игнорируется)
static func is_blocking_input() -> bool:
	return active or Engine.get_process_frames() - _ended_frame <= 1

const BAR_SHARE: float = 0.11
const BAR_TIME: float = 0.4
const SUBTITLE_FADE: float = 0.3

var data: CutsceneData
var anchor: Node3D

var _camera: Camera3D
var _previous_camera: Camera3D
var _player: Player
var _hidden_hud: CanvasLayer
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _subtitle: Label
var _shot_index: int = -1
var _shot_time: float = 0.0
var _finishing: bool = false
var _anchor_position: Vector3 = Vector3.ZERO


## Запустить кат-сцену. anchor — относительно чего планы Space.ANCHOR (может быть null)
static func play(tree: SceneTree, cutscene: CutsceneData, anchor_node: Node3D = null) -> CutscenePlayer:
	var player := CutscenePlayer.new()
	player.data = cutscene
	player.anchor = anchor_node
	tree.current_scene.add_child(player)
	return player


func _ready() -> void:
	layer = 50
	process_mode = PROCESS_MODE_ALWAYS
	if data == null or data.shots.is_empty():
		_finish.call_deferred()
		return
	active = true
	if anchor != null and is_instance_valid(anchor):
		_anchor_position = anchor.global_position
	_take_control()
	_build_ui()
	Engine.time_scale = data.time_scale
	_next_shot()


func _process(delta: float) -> void:
	if _finishing or _shot_index < 0:
		return
	# Камера летит в реальном времени, даже если игра замедлена
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	_shot_time += real_delta
	var shot: CutsceneShot = data.shots[_shot_index]
	var t: float = smoothstep(0.0, 1.0, clampf(_shot_time / maxf(shot.duration, 0.05), 0.0, 1.0))
	var position_now: Vector3 = _point(shot, shot.from_position).lerp(_point(shot, shot.to_position), t)
	var look_now: Vector3 = _point(shot, shot.look_from).lerp(_point(shot, shot.look_to), t)
	_camera.global_position = position_now
	if position_now.distance_squared_to(look_now) > 0.01:
		_camera.look_at(look_now, Vector3.UP)
	if _shot_time >= shot.duration:
		_next_shot()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		skip()


func skip() -> void:
	_finish()


func _point(shot: CutsceneShot, value: Vector3) -> Vector3:
	return value + _anchor_position if shot.relative_to == CutsceneShot.Space.ANCHOR else value


func _next_shot() -> void:
	_shot_index += 1
	_shot_time = 0.0
	if _shot_index >= data.shots.size():
		_finish()
		return
	_show_subtitle(data.shots[_shot_index].subtitle)


func _take_control() -> void:
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.far = 300.0
	add_child(_camera)
	var first: CutsceneShot = data.shots[0]
	_camera.global_position = _point(first, first.from_position)
	_camera.make_current()

	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_player.input_enabled = false
		if _player.touch_controls != null:
			_player.touch_controls.reset_all()
			_hidden_hud = _player.touch_controls.get_parent() as CanvasLayer
	if _hidden_hud != null:
		_hidden_hud.visible = false


func _exit_tree() -> void:
	# Сцену сменили посреди ролика (старт матча по сети, выход) — общее состояние не должно залипнуть
	if not _finishing:
		Engine.time_scale = 1.0
		active = false
		_ended_frame = Engine.get_process_frames()


func _release_control() -> void:
	Engine.time_scale = 1.0
	active = false
	_ended_frame = Engine.get_process_frames()
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if _hidden_hud != null and is_instance_valid(_hidden_hud):
		_hidden_hud.visible = true
	if _player != null and is_instance_valid(_player):
		var dead: bool = _player.health != null and _player.health.is_dead
		var driving: bool = not _player.visible  # за рулём управление у DriveController
		if not dead and not driving:
			_player.input_enabled = true
		if _player.touch_controls != null:
			_player.touch_controls.consume_look_delta()


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	if data != null and data.once and not data.id.is_empty():
		GameState.mark_cutscene_seen(data.id)
	_release_control()
	if _top_bar != null:
		var tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
		tween.tween_property(_top_bar, "anchor_bottom", 0.0, BAR_TIME)
		tween.tween_property(_bottom_bar, "anchor_top", 1.0, BAR_TIME)
		tween.tween_property(_subtitle, "modulate:a", 0.0, BAR_TIME)
		tween.chain().tween_callback(_done)
	else:
		_done()


func _done() -> void:
	finished.emit()
	queue_free()


# ---------- Интерфейс ----------

func _build_ui() -> void:
	_top_bar = _make_bar()
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_bottom = 0.0
	_bottom_bar = _make_bar()
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	var tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tween.tween_property(_top_bar, "anchor_bottom", BAR_SHARE, BAR_TIME)
	tween.tween_property(_bottom_bar, "anchor_top", 1.0 - BAR_SHARE, BAR_TIME)

	_subtitle = UIKit.label("", 30)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_subtitle)
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.anchor_top = 1.0 - BAR_SHARE - 0.12
	_subtitle.anchor_bottom = 1.0 - BAR_SHARE * 0.2
	_subtitle.modulate.a = 0.0

	var skip_button := UIKit.button("ПРОПУСТИТЬ  ▸", 22, 240.0)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -270.0
	skip_button.offset_right = -24.0
	skip_button.offset_top = 16.0
	skip_button.offset_bottom = 16.0 + UIKit.BUTTON_HEIGHT


func _make_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar


func _show_subtitle(text: String) -> void:
	if _subtitle == null:
		return
	_subtitle.text = text
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_subtitle, "modulate:a", 0.0 if text.is_empty() else 1.0, SUBTITLE_FADE).from(0.0)
