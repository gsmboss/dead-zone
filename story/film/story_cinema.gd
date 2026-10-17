class_name StoryCinema
extends CanvasLayer
## Проигрывает сюжетный фильм (StoryFilm) поверх игры: своя 3D-сцена StoryStage в SubViewport
## (отдельный мир), чёрные полосы, надпись места/времени, реплика снизу с голосом (синтез речи),
## крупные титры, вспышки и тряска, затемнение при смене настроения, «ПРОПУСТИТЬ».
## Пока идёт фильм — управление игрока выключено, пауза не открывается (CutscenePlayer.active).

signal finished

const BAR_SHARE: float = 0.12
## Субтитры — над нижней полосой, на тёмной подложке-градиенте (не налезают на край полосы)
const SUBTITLE_SHARE: float = 0.22
const FADE_TIME: float = 0.45
const NARRATOR_PITCH: float = 0.85
const VOICE_RATE: float = 1.0
## План ждёт конца фразы, но не дольше этого сверх своей длительности
const MAX_VOICE_EXTRA: float = 6.0
const SPEAKER_COLOR: Color = Color(1.0, 0.8, 0.4)
const CAPTION_COLOR: Color = Color(0.85, 0.9, 1.0)

var film: StoryFilm

var _viewport: SubViewport
var _stage: StoryStage
var _camera: Camera3D
var _fade: ColorRect
var _caption: Label
var _subtitle: Label
var _subtitle_shade: TextureRect
var _title: Label
var _index: int = -1
var _time: float = 0.0
var _length: float = 0.0
var _shake: float = 0.0
var _finishing: bool = false
var _player: Player
var _saved_input: bool = true
var _saved_disable_3d: bool = false


## Показать фильм. Можно ждать: await StoryCinema.play(tree, film).finished
static func play(tree: SceneTree, story_film: StoryFilm) -> StoryCinema:
	var cinema := StoryCinema.new()
	cinema.film = story_film
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(cinema)
	return cinema


func _ready() -> void:
	layer = 65
	process_mode = PROCESS_MODE_ALWAYS
	if film == null or film.shots.is_empty():
		_done.call_deferred()
		return
	CutscenePlayer.active = true
	_take_control()
	_build()
	_next_shot()


func _process(delta: float) -> void:
	if _finishing or _index < 0:
		return
	_time += delta
	var shot: StoryShot = film.shots[_index]
	var camera: Array = StoryStage.get_camera(shot.camera)
	var t: float = smoothstep(0.0, 1.0, clampf(_time / maxf(_length, 0.05), 0.0, 1.0))
	var position_now: Vector3 = (camera[0] as Vector3).lerp(camera[1], t)
	var look_now: Vector3 = (camera[2] as Vector3).lerp(camera[3], t)
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		position_now += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.4
	_camera.position = position_now
	if position_now.distance_squared_to(look_now) > 0.01:
		_camera.look_at(look_now, Vector3.UP)
	if _time >= _length:
		_next_shot()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	_finish()


func _next_shot() -> void:
	_index += 1
	_time = 0.0
	if _index >= film.shots.size():
		_finish()
		return
	var shot: StoryShot = film.shots[_index]
	var previous: int = film.shots[_index - 1].mood if _index > 0 else -1
	if shot.mood != previous:
		_flash(Color.BLACK, 1.0)  # смена места/времени — через затемнение
		_stage.set_mood(shot.mood)
	match shot.effect:
		"flash":
			_flash(Color.WHITE, 0.9)
		"shake":
			_shake = 1.2
	_caption.text = shot.caption
	_title.text = shot.title
	_title.modulate.a = 0.0
	if not shot.title.is_empty():
		_title.create_tween().set_ignore_time_scale(true).tween_property(_title, "modulate:a", 1.0, 0.6)
	_length = shot.duration
	var line: String = VoiceOver.pick(shot.voice_ru, shot.voice_en)
	_subtitle_shade.visible = not line.is_empty()
	if line.is_empty():
		_subtitle.text = ""
		return
	if shot.speaker.is_empty():
		_subtitle.text = line
		_subtitle.modulate = Color.WHITE
	else:
		_subtitle.text = "%s: %s" % [UIKit.t(shot.speaker), line]
		_subtitle.modulate = SPEAKER_COLOR
	if Settings.voice_cutscenes and VoiceOver.is_available():
		var pitch: float = shot.pitch if shot.pitch > 0.0 else NARRATOR_PITCH
		VoiceOver.speak(line, pitch, VOICE_RATE)
		_length = clampf(VoiceOver.estimate_duration(line, VOICE_RATE) + 0.4, shot.duration,
			shot.duration + MAX_VOICE_EXTRA)
	else:
		# Без голоса — время прочитать текст
		_length = maxf(shot.duration, 1.5 + line.length() * 0.05)


func _flash(color: Color, strength: float) -> void:
	_fade.color = Color(color, strength)
	var tween := _fade.create_tween().set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME if color == Color.BLACK else 0.35)


func _take_control() -> void:
	# Игру под фильмом не рисуем — телефону хватит одной 3D-сцены
	_saved_disable_3d = get_viewport().disable_3d
	get_viewport().disable_3d = true
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_saved_input = _player.input_enabled
		_player.input_enabled = false
		if _player.touch_controls != null:
			_player.touch_controls.input_blocked = true


func _release_control() -> void:
	VoiceOver.stop()
	CutscenePlayer.active = false
	if get_viewport() != null:
		get_viewport().disable_3d = _saved_disable_3d
	if _player != null and is_instance_valid(_player):
		_player.input_enabled = _saved_input
		if _player.touch_controls != null:
			_player.touch_controls.input_blocked = false
			_player.touch_controls.consume_look_delta()


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_release_control()
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_fade, "color", Color(0.0, 0.0, 0.0, 1.0), FADE_TIME)
	tween.tween_callback(_done)


func _done() -> void:
	if not _finishing:
		_release_control()
		_finishing = true
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if not _finishing:
		_release_control()


# ---------- Интерфейс ----------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.mouse_filter = Control.MOUSE_FILTER_STOP  # касания не уходят в игру под фильмом
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	container.add_child(_viewport)
	_stage = StoryStage.new()
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 400.0
	_viewport.add_child(_camera)
	_camera.make_current()

	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0 - BAR_SHARE
		bar.anchor_bottom = BAR_SHARE if top else 1.0
		add_child(bar)

	_caption = UIKit.label("", 24)
	_caption.add_theme_constant_override(&"outline_size", 6)
	_caption.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_caption.modulate = CAPTION_COLOR
	add_child(_caption)
	_caption.anchor_left = 0.04
	_caption.anchor_right = 0.7
	_caption.anchor_top = BAR_SHARE + 0.02
	_caption.anchor_bottom = BAR_SHARE + 0.1

	_title = UIKit.label("", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate = Color(1.0, 0.85, 0.5, 0.0)
	_title.add_theme_constant_override(&"outline_size", 14)
	_title.add_theme_color_override(&"font_outline_color", Color.BLACK)
	add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Затемнение низа кадра под субтитрами: от прозрачного к полупрозрачному чёрному у полосы
	var shade_gradient := Gradient.new()
	shade_gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	shade_gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.6))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade_gradient
	shade_texture.fill_from = Vector2(0.5, 0.0)
	shade_texture.fill_to = Vector2(0.5, 1.0)
	shade_texture.width = 4
	shade_texture.height = 64
	var shade := TextureRect.new()
	_subtitle_shade = shade
	shade.texture = shade_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.anchor_right = 1.0
	shade.anchor_top = 1.0 - BAR_SHARE - SUBTITLE_SHARE
	shade.anchor_bottom = 1.0 - BAR_SHARE

	_subtitle = UIKit.label("", 26)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_constant_override(&"outline_size", 8)
	_subtitle.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_subtitle.add_theme_constant_override(&"line_spacing", -2)
	add_child(_subtitle)
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.anchor_top = 1.0 - BAR_SHARE - SUBTITLE_SHARE
	_subtitle.anchor_bottom = 1.0 - BAR_SHARE
	_subtitle.offset_bottom = -10.0

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	var skip_button := UIKit.button("ПРОПУСТИТЬ  ▸", 22, 240.0)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -270.0
	skip_button.offset_right = -24.0
	skip_button.offset_top = 4.0
	skip_button.offset_bottom = 4.0 + UIKit.BUTTON_HEIGHT
	skip_button.modulate.a = 0.85
