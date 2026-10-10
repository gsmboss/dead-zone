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
## Уголок спасённых — западная часть двора за забором; костёр в его середине
const FIRE: Vector3 = Vector3(-11.5, 0.0, 6.5)
## Забор уголка: линия x (вдоль Z, вход посередине) и линия z (вдоль X, со стороны двора)
const FENCE_X: float = -7.8
const FENCE_Z: float = 1.0
const FENCE_SEGMENT: float = 1.7
## Модель забора стоит на краю своей клетки — сдвиг до линии забора
const FENCE_EDGE: float = 0.78
const ENTRANCE: Vector3 = Vector3(-7.8, 0.0, 9.6)

## [модель, позиция относительно костра, поворот в градусах, коллизия]
const LAYOUT: Array = [
	["tent-canvas", Vector3(-2.9, 0.0, 0.1), 90.0, true],
	["campfire-pit", Vector3.ZERO, 0.0, false],
	["campfire-stand", Vector3.ZERO, 0.0, false],
	["bedroll", Vector3(-0.3, 0.0, 1.9), 80.0, false],
	["box-large", Vector3(-2.9, 0.0, -2.2), 0.0, true],
	["box", Vector3(-2.1, 0.0, -2.4), 25.0, true],
	["barrel-open", Vector3(2.2, 0.0, 2.6), 0.0, true],
	["bucket", Vector3(1.4, 0.0, 1.6), 0.0, false],
	["signpost", Vector3(3.2, 0.0, -3.6), -30.0, true],
	# Спальный ряд у западной стены
	["tent", Vector3(-2.9, 0.0, 4.0), 90.0, true],
	["tent-canvas", Vector3(-2.9, 0.0, 7.0), 90.0, true],
	["bedroll", Vector3(-0.6, 0.0, 4.2), 0.0, false],
	["bedroll", Vector3(-0.6, 0.0, 5.8), 0.0, false],
	["bedroll", Vector3(-0.6, 0.0, 7.4), 0.0, false],
	["box-open", Vector3(1.0, 0.0, 8.0), 15.0, true],
	["barrel", Vector3(2.9, 0.0, 8.0), 0.0, true],
]

## Мастерская во дворе (не в уголке): [модель, позиция, поворот, коллизия]
const WORKSHOP: Array = [
	["workbench", Vector3(2.9, 0.0, 0.6), 0.0, true],
	["tool-axe", Vector3(2.7, 1.0, 0.6), 0.0, false],
	["tool-hammer", Vector3(3.1, 1.0, 0.7), 30.0, false],
]

## Мебель Kenney Furniture Kit: модели маленькие — масштаб; центр по габаритам
const FURNITURE_DIR: String = "res://models/furniture/"
const FURNITURE_SCALE: float = 2.1
## «Кухня» дяди Гоши: стол, стулья, кофемашина (относительно костра)
const KITCHEN: Array = [
	["table", Vector3(2.1, 0.0, 7.1), 0.0, FURNITURE_SCALE, true],
	["chair", Vector3(2.1, 0.0, 6.1), 180.0, FURNITURE_SCALE, true],
	["chair", Vector3(2.1, 0.0, 8.1), 0.0, FURNITURE_SCALE, false],
	["kitchenCoffeeMachine", Vector3(1.8, 0.69, 7.1), 90.0, 1.3, false],
	["radio", Vector3(2.5, 0.69, 7.0), -70.0, 1.4, false],
]

## Диван со свалки (Quaternius Couch.gltf, метры) к северу от костра, лицом к огню
const COUCH_PATH: String = "res://models/environment/Couch.gltf"
const COUCH_OFFSET: Vector3 = Vector3(0.0, 0.0, -2.9)
## Места на диване (в его координатах): ноги тела — поза «сидя» сама поднимает таз
const COUCH_SEATS: Array[Vector3] = [Vector3(-0.9, 0.5, -0.07), Vector3(0.0, 0.5, -0.07), Vector3(0.9, 0.5, -0.07)]


func _ready() -> void:
	var batch := PropBatch.new(self)
	for entry: Array in LAYOUT:
		_add_survival(batch, str(entry[0]), FIRE + (entry[1] as Vector3), float(entry[2]), bool(entry[3]))
	for entry: Array in WORKSHOP:
		_add_survival(batch, str(entry[0]), entry[1], float(entry[2]), bool(entry[3]))
	for entry: Array in KITCHEN:
		_add_furniture(batch, str(entry[0]), FIRE + (entry[1] as Vector3), float(entry[2]), float(entry[3]),
			bool(entry[4]))
	_build_fence(batch)
	var couch: PackedScene = load(COUCH_PATH) as PackedScene if ResourceLoader.exists(COUCH_PATH) else null
	if couch != null:
		batch.add(couch, Transform3D(Basis.IDENTITY, FIRE + COUCH_OFFSET), true)
	else:
		push_warning("HubCamp: нет модели %s" % COUCH_PATH)
	batch.build()
	_build_fire(FIRE)
	_build_survivors(FIRE)
	_build_resting(couch != null)
	_build_sign()
	_build_talk_zone(FIRE)


func _add_survival(batch: PropBatch, model: String, at: Vector3, yaw_deg: float, collide: bool) -> void:
	var path: String = DIR + model + ".glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("HubCamp: нет модели %s" % path)
		return
	var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * PROP_SCALE), at)
	batch.add(scene, xform, collide)


## Модель Kenney Furniture: начало координат в углу — ставим центром габаритов в точку at
static func add_centered(batch: PropBatch, path: String, at: Vector3, yaw_deg: float, model_scale: float,
		collide: bool) -> void:
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("HubCamp: нет модели %s" % path)
		return
	var bounds: AABB = batch.get_bounds(scene)
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * model_scale)
	batch.add(scene, Transform3D(basis, at) * Transform3D(Basis.IDENTITY, -center), collide)


func _add_furniture(batch: PropBatch, model: String, at: Vector3, yaw_deg: float, model_scale: float,
		collide: bool) -> void:
	add_centered(batch, FURNITURE_DIR + model + ".glb", at, yaw_deg, model_scale, collide)


## Забор уголка: со стороны двора по x = FENCE_X (вход посередине) и по z = FENCE_Z
func _build_fence(batch: PropBatch) -> void:
	var path: String = DIR + "fence-fortified.glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("HubCamp: нет модели %s" % path)
		return
	var basis_x := Basis.IDENTITY.scaled(Vector3.ONE * PROP_SCALE)
	var basis_z := Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * PROP_SCALE)
	# Вдоль X (северная сторона уголка), от западной стены до угла
	# От западной стены (она отодвигается при расширении убежища)
	var x: float = -GameState.shelter.get_half_size() + 0.5 + FENCE_SEGMENT * 0.5
	while x < FENCE_X:
		batch.add(scene, Transform3D(basis_x, Vector3(x, 0.0, FENCE_Z + FENCE_EDGE)), true)
		x += FENCE_SEGMENT
	# Вдоль Z (восточная сторона), с проходом у входа
	var z: float = FENCE_Z + FENCE_SEGMENT * 0.5
	while z < 15.6:
		if absf(z - ENTRANCE.z) > FENCE_SEGMENT:
			batch.add(scene, Transform3D(basis_z, Vector3(FENCE_X + FENCE_EDGE, 0.0, z)), true)
		z += FENCE_SEGMENT


## Табличка над входом: «СПАСЁННЫЕ» и сколько людей в лагере
func _build_sign() -> void:
	var title := Label3D.new()
	title.text = "СПАСЁННЫЕ"
	title.font_size = 72
	title.outline_size = 18
	title.pixel_size = 0.005
	title.modulate = Color(1.0, 0.85, 0.5)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = ENTRANCE + Vector3(0.0, 2.9, 0.0)
	add_child(title)
	_sign_count = Label3D.new()
	_sign_count.font_size = 44
	_sign_count.outline_size = 12
	_sign_count.pixel_size = 0.005
	_sign_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign_count.position = ENTRANCE + Vector3(0.0, 2.45, 0.0)
	add_child(_sign_count)
	_sign_mood = Label3D.new()
	_sign_mood.font_size = 40
	_sign_mood.outline_size = 12
	_sign_mood.pixel_size = 0.005
	_sign_mood.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign_mood.position = ENTRANCE + Vector3(0.0, 2.08, 0.0)
	add_child(_sign_mood)
	_update_sign()
	GameState.shelter_changed.connect(_update_sign)


## Табличка: сколько людей и их настроение (обновляется после обеда, покупок)
func _update_sign() -> void:
	if _sign_count == null:
		return
	var shelter: ShelterState = GameState.shelter
	_sign_count.text = UIKit.t("В ЛАГЕРЕ: ") + UIKit.count(shelter.get_population(), "ЧЕЛОВЕК", "ЧЕЛОВЕКА", "ЧЕЛОВЕК")
	_sign_mood.text = UIKit.t("НАСТРОЕНИЕ: %s") % UIKit.t(shelter.get_mood_text())
	_sign_mood.modulate = shelter.get_mood_color()


## Обед: все у костра радуются и благодарят (HubBase после «НАКОРМИТЬ»)
func cheer() -> void:
	_abort_dialogue()
	for i in _survivors.size():
		_survivors[i].play_emote()
		var bubble: Label3D = _bubbles[i]
		bubble.text = UIKit.t(THANKS_LINES[(i + _rng.randi()) % THANKS_LINES.size()])
		bubble.visible = true
		bubble.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(2.6)
		tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: bubble.visible = false)
	_chat_wait = 4.0


## Жильцы убежища (спасённые в сюжете и позванные по радио) греются у костра (до MAX_SURVIVORS фигур);
## двое — всегда. Остальные отдыхают на диване (до трёх; один — всегда); дальше — у построек (HubBase)
const MAX_SURVIVORS: int = 5
const MIN_SURVIVORS: int = 2
## Сколько людей показывает лагерь (костёр + диван) — остальных расставляет HubBase
const SHOWN_IN_CAMP: int = MAX_SURVIVORS + 3
## Голодные жалобы (не обедали сегодня) и благодарность за обед
const HUNGRY_LINES: PackedStringArray = ["ЕСТЬ ХОЧЕТСЯ… ДАЖЕ ЗОМБИ ПАХНУТ КОТЛЕТОЙ.",
	"КТО-НИБУДЬ ВИДЕЛ ЕДУ? ХОТЬ КОНСЕРВУ?", "У МЕНЯ ЖИВОТ УРЧИТ ГРОМЧЕ ОРДЫ.",
	"ЕСЛИ НЕ ПООБЕДАЕМ, Я СЪЕМ ДИВАН.", "ДЯДЯ ГОША, А ЧТО НА ОБЕД? «НИЧЕГО»? ОПЯТЬ?"]
const THANKS_LINES: PackedStringArray = ["СПАСИБО! ВКУСНО!", "ВОТ ЭТО ОБЕД!", "ДОБАВКИ МОЖНО?",
	"ЖИЗНЬ НАЛАЖИВАЕТСЯ!", "ГОША, ТЫ ГЕНИЙ!"]
const HUNGRY_CHANCE: float = 0.4
var _survivors: Array[PlayerBody] = []
var _sign_count: Label3D
var _sign_mood: Label3D

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


## Отдыхающие на диване у костра — поза «сидя»
func _build_resting(has_couch: bool) -> void:
	if not has_couch:
		return
	var skins: Array[PlayerSkin] = _camp_skins()
	if skins.is_empty():
		return
	var at_fire: int = clampi(GameState.shelter.get_population(), MIN_SURVIVORS, MAX_SURVIVORS)
	var count: int = clampi(GameState.shelter.get_population() - at_fire, 1, COUCH_SEATS.size())
	var couch := Transform3D(Basis.IDENTITY, FIRE + COUCH_OFFSET)
	for i in count:
		var body := PlayerBody.new()
		add_child(body)
		# Другие лица, чем у костра
		body.set_skin(skins[(i + at_fire) % skins.size()])
		body.position = couch * COUCH_SEATS[(i + 1) % COUCH_SEATS.size()]
		body.rotation.y = PI  # лицом к огню (+Z дивана); тело смотрит в -Z
		body.set_seated(true)


## Скины людей лагеря (без оружия в руках)
func _camp_skins() -> Array[PlayerSkin]:
	var skins: Array[PlayerSkin] = []
	for skin: PlayerSkin in GameState.skins:
		if skin.hide_weapon:
			skins.append(skin)
	return skins


func _build_survivors(fire: Vector3) -> void:
	var count: int = clampi(GameState.shelter.get_population(), MIN_SURVIVORS, MAX_SURVIVORS)
	if count <= 0:
		return
	var skins: Array[PlayerSkin] = _camp_skins()
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
	# Не обедали — жалуются
	if not GameState.shelter.is_fed_today() and _rng.randf() < HUNGRY_CHANCE:
		_dialogue = PackedStringArray([UIKit.t(HUNGRY_LINES[_rng.randi() % HUNGRY_LINES.size()])])
		_owners = PackedInt32Array([_rng.randi() % _survivors.size()])
		_line = 0
		_say_line()
		return
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
	_player_line.text = UIKit.t("ВЫ: %s") % text if VoiceOver.is_russian() else "YOU: %s" % text
	_player_line.modulate = Color(0.75, 0.95, 1.0, 0.0)
	_player_line.visible = true
	create_tween().tween_property(_player_line, "modulate:a", 1.0, 0.2)
