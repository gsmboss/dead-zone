class_name HubCamp
extends Node3D
## Лагерь выживших во дворе убежища (модели Kenney Survival Kit): палатка, костёр с огнём,
## спальник, ящики, бочки, инструменты. Создаётся кодом (hub.gd), коллизии — в одном теле.
## Выжившие болтают у костра (смешные и познавательные диалоги); у костра кнопка «ПОГОВОРИТЬ» —
## игрок может пошутить или попросить рассказать что-нибудь умное.

const DIR: String = "res://models/survival/"
## Модели Kenney маленькие: палатка 0.56 → ~1.9 м
const PROP_SCALE: float = 3.4
const FIRE_COLOR: Color = Color(1.0, 0.6, 0.25)

## [модель, позиция, поворот в градусах, коллизия]
const LAYOUT: Array = [
	["tent-canvas", Vector3(-6.7, 0.0, 1.4), 90.0, true],
	["campfire-pit", Vector3(-4.6, 0.0, 1.3), 0.0, false],
	["campfire-stand", Vector3(-4.6, 0.0, 1.3), 0.0, false],
	["bedroll", Vector3(-4.9, 0.0, 2.9), 80.0, false],
	["box-large", Vector3(-7.2, 0.0, -0.9), 0.0, true],
	["box", Vector3(-6.4, 0.0, -1.1), 25.0, true],
	["barrel-open", Vector3(-3.4, 0.0, 2.6), 0.0, true],
	["bucket", Vector3(-3.6, 0.0, 0.4), 0.0, false],
	["signpost", Vector3(-2.9, 0.0, -0.4), -30.0, true],
	["workbench", Vector3(2.9, 0.0, 0.6), 0.0, true],
	["tool-axe", Vector3(2.7, 1.0, 0.6), 0.0, false],
	["tool-hammer", Vector3(3.1, 1.0, 0.7), 30.0, false],
]


func _ready() -> void:
	var batch := PropBatch.new(self)
	for entry: Array in LAYOUT:
		var path: String = DIR + str(entry[0]) + ".glb"
		var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene == null:
			push_warning("HubCamp: нет модели %s" % path)
			continue
		var at: Vector3 = entry[1]
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(float(entry[2]))).scaled(Vector3.ONE * PROP_SCALE), at)
		batch.add(scene, xform, bool(entry[3]))
	batch.build()
	_build_fire(Vector3(-4.6, 0.0, 1.3))
	_build_survivors(Vector3(-4.6, 0.0, 1.3))
	_build_talk_zone(Vector3(-4.6, 0.0, 1.3))


## Спасённые в сюжете люди греются у костра (до MAX_SURVIVORS фигур); двое — всегда (первая группа)
const MAX_SURVIVORS: int = 6
const MIN_SURVIVORS: int = 2
var _survivors: Array[PlayerBody] = []

# Разговоры у костра: реплика — текст над головой (и голос, если игрок рядом)
const CHATTER_PATH: String = "res://hub/camp_chatter.tres"
const BUBBLE_HEIGHT: float = 2.35
const CHAT_PAUSE_MIN: float = 4.0
const CHAT_PAUSE_MAX: float = 9.0
const LINE_GAP: float = 0.5
const VOICE_DISTANCE: float = 6.0
const VOICE_RATE: float = 1.1
## Свой тон голоса у каждого — разговор звучит как разные люди (и смешно)
const VOICE_PITCHES: Array[float] = [0.7, 1.35, 1.0, 1.6, 0.55, 1.2]
## Зона «ПОГОВОРИТЬ» вокруг костра
const TALK_RADIUS: float = 4.2
## Голос игрока в разговоре
const PLAYER_PITCH: float = 1.0
var _chatter: CampChatter
var _bubbles: Array[Label3D] = []
var _base_yaw: Array[float] = []
var _dialogue := PackedStringArray()
## Кто говорит реплику: индекс выжившего или -1 — игрок (субтитр внизу экрана)
var _owners := PackedInt32Array()
var _talk_menu: CanvasLayer
var _player_line: Label
var _joke_index: int = 0
var _fact_index: int = 0
var _ask_index: int = 0
var _line: int = -1
var _line_left: float = 0.0
var _chat_wait: float = 2.5
var _dialogue_index: int = 0
var _rng := RandomNumberGenerator.new()


func _build_survivors(fire: Vector3) -> void:
	var count: int = clampi(GameState.get_rescued_count(), MIN_SURVIVORS, MAX_SURVIVORS)
	if count <= 0:
		return
	var skins: Array[PlayerSkin] = []
	for skin: PlayerSkin in GameState.skins:
		if skin.hide_weapon:
			skins.append(skin)
	if skins.is_empty():
		return
	for i in count:
		# Полукруг с восточной стороны костра (с запада — палатка)
		var angle: float = lerpf(-1.2, 1.2, float(i) / maxf(count - 1, 1.0))
		var at: Vector3 = fire + Vector3(cos(angle), 0.0, sin(angle)) * 1.9
		var body := PlayerBody.new()
		add_child(body)
		body.set_skin(skins[i % skins.size()])
		body.position = at
		body.rotation.y = atan2(at.x - fire.x, at.z - fire.z)  # лицом к огню
		_survivors.append(body)
		_base_yaw.append(body.rotation.y)
		_bubbles.append(_make_bubble(body))
	_rng.randomize()
	_chatter = load(CHATTER_PATH) as CampChatter if ResourceLoader.exists(CHATTER_PATH) else null
	if _chatter == null:
		push_warning("HubCamp: нет разговоров %s" % CHATTER_PATH)
	else:
		_dialogue_index = _rng.randi() % maxi(_chatter.get_dialogue_count(), 1)
		_joke_index = _rng.randi() % maxi(_chatter.get_joke_count(), 1)
		_fact_index = _rng.randi() % maxi(_chatter.get_fact_count(), 1)
	set_process(true)


func _process(delta: float) -> void:
	for body: PlayerBody in _survivors:
		body.update_motion(0.0, true, delta)
	_update_chatter(delta)


# ---------- Разговоры ----------

func _make_bubble(body: PlayerBody) -> Label3D:
	var bubble := Label3D.new()
	bubble.name = "Speech"
	bubble.position = Vector3.UP * BUBBLE_HEIGHT
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 40
	bubble.outline_size = 14
	bubble.pixel_size = 0.0035
	bubble.width = 620.0
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.modulate = Color(1.0, 0.96, 0.86)
	bubble.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	bubble.no_depth_test = true
	bubble.visible = false
	body.add_child(bubble)
	return bubble


func _update_chatter(delta: float) -> void:
	if _chatter == null or _survivors.is_empty():
		return
	if _line < 0:
		_chat_wait -= delta
		if _chat_wait <= 0.0:
			_start_dialogue()
		return
	_line_left -= delta
	if _line_left > 0.0:
		return
	_hide_bubble(_owners[_line])
	_line += 1
	if _line >= _dialogue.size():
		_end_dialogue()
	else:
		_say_line()


func _start_dialogue() -> void:
	if _survivors.size() >= 2:
		var first: int = _rng.randi() % _survivors.size()
		var second: int = (first + 1 + _rng.randi() % (_survivors.size() - 1)) % _survivors.size()
		_dialogue = _chatter.get_dialogue(_dialogue_index)
		_dialogue_index += 1
		_owners.resize(_dialogue.size())
		for i in _dialogue.size():
			_owners[i] = first if i % 2 == 0 else second
		# Повернуться друг к другу
		_face(first, _survivors[second].position)
		_face(second, _survivors[first].position)
	else:
		_dialogue = PackedStringArray([_chatter.get_solo_line(_dialogue_index)])
		_dialogue_index += 1
		_owners = PackedInt32Array([0])
	if _dialogue.is_empty():
		_chat_wait = CHAT_PAUSE_MAX
		return
	_line = 0
	_say_line()


func _say_line() -> void:
	var index: int = _owners[_line]
	var text: String = _dialogue[_line]
	_line_left = clampf(1.6 + text.length() * 0.06, 2.4, 8.0) + LINE_GAP
	if index < 0:
		# Реплика игрока — субтитром внизу экрана
		_show_player_line(text)
		if _should_voice(index):
			VoiceOver.speak(text, PLAYER_PITCH, VOICE_RATE)
			_line_left = maxf(_line_left, VoiceOver.estimate_duration(text, VOICE_RATE) + LINE_GAP)
		return
	var bubble: Label3D = _bubbles[index]
	bubble.text = text
	bubble.visible = true
	bubble.modulate.a = 0.0
	create_tween().tween_property(bubble, "modulate:a", 1.0, 0.25)
	# Ответ игроку — всегда с жестом (смеётся или объясняет)
	if _rng.randf() < 0.35 or (_line > 0 and _owners[_line - 1] < 0):
		_survivors[index].play_emote()
	if _should_voice(index):
		var pitch: float = VOICE_PITCHES[index % VOICE_PITCHES.size()]
		VoiceOver.speak(text, pitch, VOICE_RATE)
		_line_left = maxf(_line_left, VoiceOver.estimate_duration(text, VOICE_RATE) + LINE_GAP)


func _end_dialogue() -> void:
	_line = -1
	_chat_wait = _rng.randf_range(CHAT_PAUSE_MIN, CHAT_PAUSE_MAX)
	# Снова к огню
	for i in _survivors.size():
		create_tween().tween_property(_survivors[i], "rotation:y", _base_yaw[i], 0.6)


func _hide_bubble(index: int) -> void:
	if index < 0:
		if _player_line != null:
			_player_line.visible = false
		return
	var bubble: Label3D = _bubbles[index]
	var tween := create_tween()
	tween.tween_property(bubble, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void: bubble.visible = false)


func _face(index: int, target: Vector3) -> void:
	var body: PlayerBody = _survivors[index]
	# Тот же отсчёт угла, что и «лицом к огню» при расстановке
	var yaw: float = atan2(body.position.x - target.x, body.position.z - target.z)
	# Кратчайший поворот
	var current: float = body.rotation.y
	yaw = current + wrapf(yaw - current, -PI, PI)
	create_tween().tween_property(body, "rotation:y", yaw, 0.4)


## Голос — только если игрок рядом, свободно гуляет (не в окне) и не идёт кат-сцена
func _should_voice(index: int) -> bool:
	if not Settings.voice_camp or CutscenePlayer.active or not VoiceOver.is_available():
		return false
	if index < 0:
		return true  # сам игрок
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or not player.input_enabled:
		return false
	return player.global_position.distance_to(_survivors[index].global_position) <= VOICE_DISTANCE


func _build_fire(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = at + Vector3.UP * 0.8
	add_child(light)
	var flames := GraveyardBuilder.make_flames()
	flames.position = at + Vector3.UP * 0.25
	add_child(flames)


# ---------- Разговор с игроком ----------

func _build_talk_zone(fire: Vector3) -> void:
	if _survivors.is_empty():
		return
	var zone := Interactable.new()
	zone.name = "TalkZone"
	zone.prompt = "ПОГОВОРИТЬ"
	zone.action_id = &"talk"
	var sphere := SphereShape3D.new()
	sphere.radius = TALK_RADIUS
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	shape.position = Vector3.UP
	zone.add_child(shape)
	zone.position = fire
	add_child(zone)
	zone.interacted.connect(_open_talk_menu)
	zone.player_exited.connect(func(_zone: Interactable) -> void: _close_talk_menu())


## Меню у костра: пошутить, узнать факт, уйти
func _open_talk_menu() -> void:
	if _talk_menu != null or _chatter == null:
		return
	_talk_menu = CanvasLayer.new()
	_talk_menu.name = "TalkMenu"
	_talk_menu.layer = 5
	add_child(_talk_menu)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	_talk_menu.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var title := UIKit.label("У КОСТРА", 30, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.ACCENT
	var joke := UIKit.button("ПОШУТИТЬ", 28, 320.0)
	joke.pressed.connect(func() -> void:
		_close_talk_menu()
		_tell_joke())
	box.add_child(joke)
	var fact := UIKit.button("УЗНАТЬ ФАКТ", 28, 320.0)
	fact.pressed.connect(func() -> void:
		_close_talk_menu()
		_ask_fact())
	box.add_child(fact)
	var leave := UIKit.button("ПОКА", 24, 320.0)
	leave.pressed.connect(_close_talk_menu)
	box.add_child(leave)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_set_touch_blocked(true)
	Sfx.play_2d(Sfx.sounds.ui_confirm, -6.0, 1.1, 0.0)


func _close_talk_menu() -> void:
	if _talk_menu == null:
		return
	_talk_menu.queue_free()
	_talk_menu = null
	_set_touch_blocked(false)


## Пока открыто меню, касания не крутят камеру и не двигают игрока
func _set_touch_blocked(blocked: bool) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.touch_controls != null:
		player.touch_controls.input_blocked = blocked


func _tell_joke() -> void:
	var pair: PackedStringArray = _chatter.get_joke(_joke_index)
	_joke_index += 1
	if pair.size() >= 2:
		_talk_with_player(pair[0], pair[1])


func _ask_fact() -> void:
	var fact: String = _chatter.get_fact(_fact_index)
	_fact_index += 1
	var ask: String = _chatter.get_ask(_ask_index)
	_ask_index += 1
	if not fact.is_empty():
		_talk_with_player(ask, fact)


## Игрок говорит, ближайший выживший поворачивается и отвечает (прерывает их болтовню)
func _talk_with_player(player_text: String, reply: String) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or _survivors.is_empty():
		return
	_abort_dialogue()
	var player_local: Vector3 = to_local(player.global_position)
	var nearest: int = 0
	for i in _survivors.size():
		if _survivors[i].position.distance_to(player_local) < _survivors[nearest].position.distance_to(player_local):
			nearest = i
	_face(nearest, player_local)
	_dialogue = PackedStringArray([player_text, reply])
	_owners = PackedInt32Array([-1, nearest])
	_line = 0
	_say_line()


## Оборвать текущий разговор выживших (игрок вмешался)
func _abort_dialogue() -> void:
	if _line >= 0 and _line < _owners.size():
		_hide_bubble(_owners[_line])
	VoiceOver.stop()
	_line = -1


## Субтитр реплики игрока внизу экрана
func _show_player_line(text: String) -> void:
	if _player_line == null:
		var layer := CanvasLayer.new()
		layer.name = "PlayerLine"
		layer.layer = 4
		add_child(layer)
		_player_line = UIKit.label("", 30, layer)
		_player_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_player_line.add_theme_constant_override(&"outline_size", 10)
		_player_line.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_player_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_player_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_player_line.offset_left = -480.0
		_player_line.offset_right = 480.0
		_player_line.offset_top = -280.0
		_player_line.offset_bottom = -160.0
		_player_line.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_player_line.text = "ВЫ: %s" % text if VoiceOver.is_russian() else "YOU: %s" % text
	_player_line.modulate = Color(0.75, 0.95, 1.0, 0.0)
	_player_line.visible = true
	create_tween().tween_property(_player_line, "modulate:a", 1.0, 0.2)
