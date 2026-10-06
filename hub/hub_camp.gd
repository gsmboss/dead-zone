class_name HubCamp
extends Node3D
## Лагерь выживших во дворе убежища (модели Kenney Survival Kit): палатка, костёр с огнём,
## спальник, ящики, бочки, инструменты. Создаётся кодом (hub.gd), коллизии — в одном теле.

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
var _chatter: CampChatter
var _bubbles: Array[Label3D] = []
var _base_yaw: Array[float] = []
var _dialogue := PackedStringArray()
var _speakers: Array[int] = [0, 0]
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
	_hide_bubble(_speakers[_line % 2])
	_line += 1
	if _line >= _dialogue.size():
		_end_dialogue()
	else:
		_say_line()


func _start_dialogue() -> void:
	if _survivors.size() >= 2:
		var first: int = _rng.randi() % _survivors.size()
		var second: int = (first + 1 + _rng.randi() % (_survivors.size() - 1)) % _survivors.size()
		_speakers = [first, second]
		_dialogue = _chatter.get_dialogue(_dialogue_index)
		_dialogue_index += 1
		# Повернуться друг к другу
		_face(first, _survivors[second].position)
		_face(second, _survivors[first].position)
	else:
		_speakers = [0, 0]
		_dialogue = PackedStringArray([_chatter.get_solo_line(_dialogue_index)])
		_dialogue_index += 1
	if _dialogue.is_empty():
		_chat_wait = CHAT_PAUSE_MAX
		return
	_line = 0
	_say_line()


func _say_line() -> void:
	var index: int = _speakers[_line % 2]
	var text: String = _dialogue[_line]
	var bubble: Label3D = _bubbles[index]
	bubble.text = text
	bubble.visible = true
	bubble.modulate.a = 0.0
	create_tween().tween_property(bubble, "modulate:a", 1.0, 0.25)
	if _rng.randf() < 0.35:
		_survivors[index].play_emote()
	_line_left = clampf(1.6 + text.length() * 0.06, 2.4, 7.0) + LINE_GAP
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
