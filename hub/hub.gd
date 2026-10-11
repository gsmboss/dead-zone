extends Node3D
## Убежище: игрок ходит между терминалами, оружие в хабе отключено.
## Окна миссий и оружейной открывает HubHUD. При первом запуске — вступительная кат-сцена.
## Размер двора — по уровню убежища (GameState.shelter): пол, невидимые стены и всё снаружи
## раздвигаются, ограда (HubYard) и лагерь (HubCamp) пересобираются при расширении.

const INTRO_PATH: String = "res://cutscene/hub_intro.tres"
## Стартовый полуразмер двора (по нему расставлено всё в hub.tscn)
const BASE_HALF: float = 16.0
const WALL_THICKNESS: float = 0.4
const WALL_HEIGHT: float = 40.0

var _level: int = 0


func _ready() -> void:
	GameState.end_raid()  # вернулись из набега (проигрыш) — бонус не тянется в следующую миссию
	# Ждём, пока игрок закончит свой _ready (он сам находит WeaponManager)
	_disable_player_weapons.call_deferred()
	GameState.shelter.tick()  # прошедшие дни: голод, урожай огорода
	_level = GameState.shelter.level
	_apply_shelter_size()
	_spawn_yard_and_camp()
	var base := HubBase.new()
	base.name = "ShelterBase"
	add_child(base)
	GameState.shelter_changed.connect(_on_shelter_changed)
	var lounge := HubLounge.new()
	lounge.name = "Lounge"
	add_child(lounge)
	var sky_title := HubSkyTitle.new()
	sky_title.name = "SkyTitle"
	add_child(sky_title)
	_play_intro.call_deferred()


func _spawn_yard_and_camp() -> void:
	var yard := HubYard.new()
	yard.name = "Yard"
	add_child(yard)
	var camp := HubCamp.new()
	camp.name = "Camp"
	add_child(camp)


## Расширили убежище — раздвинуть стены, пересобрать ограду и лагерь
func _on_shelter_changed() -> void:
	if GameState.shelter.level == _level:
		return
	_level = GameState.shelter.level
	for node_name: String in ["Yard", "Camp"]:
		var old: Node = get_node_or_null(node_name)
		if old != null:
			old.name = node_name + "_old"
			old.queue_free()
	_apply_shelter_size()
	_spawn_yard_and_camp()
	Sfx.play_2d(Sfx.sounds.purchase, -2.0, 0.8, 0.0)


## Пол, невидимые стены Room/Bounds и всё снаружи (Props/Outside) — по полуразмеру двора
func _apply_shelter_size() -> void:
	var half: float = GameState.shelter.get_half_size()
	var floor_box := get_node_or_null(^"Room/Floor") as CSGBox3D
	if floor_box != null:
		floor_box.size = Vector3(half * 2.0, floor_box.size.y, half * 2.0)
	else:
		push_warning("%s: нет Room/Floor — пол не расширен" % name)
	var walls: Dictionary = {"North": Vector3(0, 0, -1), "South": Vector3(0, 0, 1), "West": Vector3(-1, 0, 0),
		"East": Vector3(1, 0, 0)}
	for wall_name: String in walls:
		var wall := get_node_or_null("Room/Bounds/" + wall_name) as CollisionShape3D
		if wall == null:
			push_warning("%s: нет стены Room/Bounds/%s" % [name, wall_name])
			continue
		var direction: Vector3 = walls[wall_name]
		var box := BoxShape3D.new()
		var length: float = half * 2.0 + 0.8
		box.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, length) if direction.x != 0.0 \
			else Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
		wall.shape = box
		wall.position = Vector3(direction.x * half, wall.position.y, direction.z * half)
	# Снаружи (башня, знак, дорога) — отодвинуть на столько же, на сколько стены
	var outside: Node = get_node_or_null(^"Props/Outside")
	if outside == null:
		return
	var shift: float = half - BASE_HALF
	for child: Node in outside.get_children():
		var prop := child as Node3D
		if prop == null:
			continue
		if not prop.has_meta(&"base_position"):
			prop.set_meta(&"base_position", prop.position)
		var base: Vector3 = prop.get_meta(&"base_position")
		var offset := Vector3(signf(base.x) * shift if absf(base.x) > BASE_HALF else 0.0, 0.0,
			signf(base.z) * shift if absf(base.z) > BASE_HALF else 0.0)
		prop.position = base + offset


func _disable_player_weapons() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		push_warning("%s: игрок (группа \"player\") не найден" % name)
		return
	if player.weapon_manager == null:
		push_warning("%s: у игрока нет WeaponManager" % name)
		return
	# Выключает стрельбу, вью-модель и оружие в руке тела (вид от 3-го лица)
	player.set_weapons_enabled(false)


func _play_intro() -> void:
	if not Settings.cutscenes:
		_offer_tutorial()
		return
	# Первый вход: сначала фильм-пролог «каким был город и что с ним стало»
	var prologue: StoryFilm = GameState.campaign.prologue_film
	if prologue != null and not GameState.has_seen_cutscene("film_" + prologue.id):
		GameState.mark_cutscene_seen("film_" + prologue.id)
		await StoryCinema.play(get_tree(), prologue).finished
	if not GameState.has_seen_cutscene("hub_intro"):
		var intro := load(INTRO_PATH) as CutsceneData if ResourceLoader.exists(INTRO_PATH) else null
		if intro == null:
			push_warning("%s: не найдена кат-сцена %s" % [name, INTRO_PATH])
		else:
			await CutscenePlayer.play(get_tree(), intro).finished
	_offer_tutorial()


## После вступления — предложить обучение (один раз)
func _offer_tutorial() -> void:
	if not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group(&"hub_hud")
	if hud != null and hud.has_method(&"offer_tutorial"):
		hud.call(&"offer_tutorial")
