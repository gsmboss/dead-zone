class_name HubBase
extends Node3D
## Развитие убежища во дворе (создаёт hub.gd): постройки со сборщиком (огород, вышка, радио, генератор,
## столовая) и купленное обустройство (HubDecor), жильцы сверх лагеря — на местах у построек и двое
## гуляют по двору, кухня «НАКОРМИТЬ» (обед раз в день), касса лагеря «ЗАБРАТЬ» (монеты копятся по часам),
## ящики провизии у кухни, котёл на костре после обеда, гирлянды над двором с генератором.
## Пересобирается при покупках (GameState.shelter_changed / progress_changed).

## Кухня дяди Гоши (стол с кофемашиной, HubCamp.KITCHEN) и касса у входа в лагерь
const KITCHEN: Vector3 = Vector3(-9.0, 0.0, 13.3)
const CASH_BOX: Vector3 = Vector3(-6.3, 0.0, 6.2)
const CRATES: Vector3 = Vector3(-13.8, 0.0, 15.2)
const ZONE_SIZE: Vector3 = Vector3(2.6, 2.0, 2.6)
## Ящиков в штабеле (ящик ≈ 5 ящиков провизии)
const CRATES_MAX: int = 8
const FOOD_PER_CRATE_MODEL: int = 6
## Жильцов на местах у построек — по ступени графики (каждый — анимированный скелет)
const EXTRA_BY_TIER: Array[int] = [6, 10, 14]
## Гуляющие по двору (если людей хватает)
const STROLLERS: int = 2
const STROLL_SPEED: float = 1.3
## Маршрут прогулки по свободным местам двора (по кругу)
const STROLL_PATH: Array[Vector3] = [Vector3(-1.5, 0, 9.5), Vector3(-5.4, 0, 1.0), Vector3(-5.4, 0, -8.5),
	Vector3(2.5, 0, -8.5), Vector3(9.0, 0, -8.5), Vector3(9.0, 0, 3.0), Vector3(3.0, 0, 9.5)]
## Гирлянды генератора: пары точек над двором
const GENERATOR_GARLANDS: Array = [[Vector3(-7.5, 4.6, -7.5), Vector3(7.5, 4.6, 7.5)],
	[Vector3(7.5, 4.6, -7.5), Vector3(-7.5, 4.6, 7.5)], [Vector3(-7.5, 4.6, -7.5), Vector3(7.5, 4.6, -7.5)]]
const EMOTE_INTERVAL: float = 6.0
const IDLE_REFRESH: float = 0.5

var _built: Node3D
var _crates: Node3D
var _signature: String = ""
var _food_shown: int = -1
var _residents: Array[PlayerBody] = []
var _strollers: Array[PlayerBody] = []
var _stroll_target: Array[int] = []
var _kitchen_zone: Interactable
var _cash_zone: Interactable
var _cash_label: Label3D
var _pot: Node3D
var _idle_left: float = 0.0
var _emote_left: float = EMOTE_INTERVAL
var _cash_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_kitchen_zone()
	_build_cash_box()
	_rebuild()
	GameState.shelter_changed.connect(_on_changed)
	GameState.progress_changed.connect(_on_changed)


func _on_changed() -> void:
	# Пересборка — только если поменялся набор построек/обустройства/людей (не на каждый ящик еды)
	if _signature != _make_signature():
		_rebuild()
	_update_crates()
	_update_kitchen()
	_update_cash()


func _make_signature() -> String:
	var shelter: ShelterState = GameState.shelter
	var owned := PackedStringArray()
	for building: BuildingData in GameState.buildings:
		if building.builder != &"" and GameState.has_building(building.id):
			owned.append(building.id)
	owned.append_array(PackedStringArray(shelter.decor_owned))
	return "%d|%d|%s" % [shelter.level, shelter.get_population(), ",".join(owned)]


func _rebuild() -> void:
	_signature = _make_signature()
	if _built != null:
		_built.queue_free()
	_residents.clear()
	_strollers.clear()
	_stroll_target.clear()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built)
	var batch := PropBatch.new(_built)
	var spots: Array[Dictionary] = []
	for building: BuildingData in GameState.buildings:
		if building.builder == &"" or not GameState.has_building(building.id):
			continue
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(building.hub_yaw_degrees)), building.hub_position)
		spots.append_array(HubDecor.build(building.builder, _built, batch, xform))
	for item: DecorData in GameState.shelter.decor_list.decor:
		if item == null or not GameState.shelter.owns_decor(item.id):
			continue
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(item.yaw_degrees)), item.position)
		spots.append_array(HubDecor.build(item.builder, _built, batch, xform))
	batch.build()
	if GameState.has_building("generator"):
		for pair: Array in GENERATOR_GARLANDS:
			HubDecor._bulbs(_built, pair[0], pair[1], 0.7, 22)
	_place_residents(spots)
	_update_crates()
	_update_kitchen()
	_update_cash()


# ---------- Жильцы ----------

func _camp_skins() -> Array[PlayerSkin]:
	var skins: Array[PlayerSkin] = []
	for skin: PlayerSkin in GameState.skins:
		if skin.hide_weapon:
			skins.append(skin)
	return skins


## Люди сверх лагеря (костёр и диван) — на места у построек, и двое гуляют
func _place_residents(spots: Array[Dictionary]) -> void:
	var skins: Array[PlayerSkin] = _camp_skins()
	if skins.is_empty():
		return
	var extra: int = GameState.shelter.get_population() - HubCamp.SHOWN_IN_CAMP
	if extra <= 0:
		return
	var tier: int = clampi(Settings.get_detail_tier(), 0, EXTRA_BY_TIER.size() - 1)
	var limit: int = mini(extra, EXTRA_BY_TIER[tier])
	var walkers: int = mini(STROLLERS, limit)
	for i in walkers:
		var body := _spawn_body(skins[(i + 3) % skins.size()])
		var start: int = (i * 4) % STROLL_PATH.size()
		body.position = STROLL_PATH[start]
		_strollers.append(body)
		_stroll_target.append((start + 1) % STROLL_PATH.size())
	for i in mini(limit - walkers, spots.size()):
		var spot: Dictionary = spots[i]
		var body := _spawn_body(skins[(i + 5) % skins.size()])
		body.position = spot["pos"]
		body.rotation.y = float(spot["yaw"])
		if bool(spot["seated"]):
			body.set_seated(true)
		else:
			_residents.append(body)


func _spawn_body(skin: PlayerSkin) -> PlayerBody:
	var body := PlayerBody.new()
	_built.add_child(body)
	body.set_skin(skin)
	return body


func _process(delta: float) -> void:
	for i in _strollers.size():
		_walk(i, delta)
	_idle_left -= delta
	if _idle_left <= 0.0:
		_idle_left = IDLE_REFRESH
		for body: PlayerBody in _residents:
			body.update_motion(0.0, true, IDLE_REFRESH)
	_emote_left -= delta
	if _emote_left <= 0.0 and not _residents.is_empty():
		_emote_left = EMOTE_INTERVAL * _rng.randf_range(0.6, 1.4)
		_residents[_rng.randi() % _residents.size()].play_emote()
	_cash_left -= delta
	if _cash_left <= 0.0:
		_cash_left = 1.0
		_update_cash()


func _walk(index: int, delta: float) -> void:
	var body: PlayerBody = _strollers[index]
	var target: Vector3 = STROLL_PATH[_stroll_target[index]]
	var to_target: Vector3 = target - body.position
	to_target.y = 0.0
	if to_target.length() < 0.2:
		_stroll_target[index] = (_stroll_target[index] + 1) % STROLL_PATH.size()
		return
	var step: Vector3 = to_target.normalized() * minf(STROLL_SPEED * delta, to_target.length())
	body.position += step
	# Тело смотрит в −Z (как у костра: yaw = atan2 от цели к телу)
	var yaw: float = atan2(-step.x, -step.z)
	body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(delta * 6.0, 1.0))
	body.update_motion(STROLL_SPEED, true, delta)


# ---------- Кухня: обед ----------

func _build_kitchen_zone() -> void:
	_kitchen_zone = _make_zone("Kitchen", KITCHEN, &"feed")
	_kitchen_zone.interacted.connect(_on_feed)
	_crates = Node3D.new()
	_crates.name = "FoodCrates"
	add_child(_crates)


func _make_zone(zone_name: String, at: Vector3, action: StringName) -> Interactable:
	var zone := Interactable.new()
	zone.name = zone_name
	zone.action_id = action
	var box := BoxShape3D.new()
	box.size = ZONE_SIZE
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3.UP
	zone.add_child(shape)
	zone.position = at
	add_child(zone)
	return zone


func _update_kitchen() -> void:
	var shelter: ShelterState = GameState.shelter
	if _kitchen_zone != null:
		if shelter.is_fed_today():
			_kitchen_zone.set_prompt("ОБЕД БЫЛ ✓")
		else:
			_kitchen_zone.set_prompt(UIKit.t("НАКОРМИТЬ (%d)") % shelter.get_meal_cost())
	# Котёл на костре — после обеда
	var fed: bool = shelter.is_fed_today()
	if fed and _pot == null:
		_pot = Node3D.new()
		_pot.name = "StewPot"
		add_child(_pot)
		var pot_scene: PackedScene = load(HubDecor.FOOD + "pot-stew.glb") as PackedScene \
			if ResourceLoader.exists(HubDecor.FOOD + "pot-stew.glb") else null
		if pot_scene != null:
			var pot := pot_scene.instantiate() as Node3D
			pot.scale = Vector3.ONE * 0.8
			pot.position = HubCamp.FIRE + Vector3(0.0, 0.62, 0.0)
			_pot.add_child(pot)
	elif not fed and _pot != null:
		_pot.queue_free()
		_pot = null


func _on_feed() -> void:
	var shelter: ShelterState = GameState.shelter
	if shelter.is_fed_today():
		_float_text(KITCHEN, "СЕГОДНЯ УЖЕ ОБЕДАЛИ", UIKit.DIM)
		return
	if not shelter.feed():
		_float_text(KITCHEN, UIKit.t("НУЖНО ПРОВИЗИИ: %d (ЕСТЬ %d) — КУПИ В ОКНЕ БАЗА") % [shelter.get_meal_cost(),
			shelter.food], Color(1.0, 0.55, 0.45))
		Sfx.error()
		return
	Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.2, 0.0)
	_float_text(KITCHEN, UIKit.t("ОБЕД! НАСТРОЕНИЕ +%d") % roundi(shelter.config.morale_meal), UIKit.GOOD)
	var camp := get_parent().get_node_or_null(^"Camp") as HubCamp
	if camp != null:
		camp.cheer()
	for body: PlayerBody in _residents:
		body.play_emote()


## Штабель ящиков у кухни — сколько провизии в запасе
func _update_crates() -> void:
	var count: int = clampi(ceili(float(GameState.shelter.food) / FOOD_PER_CRATE_MODEL), 0, CRATES_MAX)
	if count == _food_shown or _crates == null:
		return
	_food_shown = count
	for child: Node in _crates.get_children():
		child.queue_free()
	var path: String = HubCamp.DIR + "box-large.glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		return
	for i in count:
		var crate := scene.instantiate() as Node3D
		var column: int = i % 4
		var layer: int = floori(i / 4.0)
		crate.scale = Vector3.ONE * HubCamp.PROP_SCALE * 0.5
		crate.position = CRATES + Vector3(float(column) * 0.6, float(layer) * 0.42, 0.0)
		crate.rotation.y = float(i % 3) * 0.15
		_crates.add_child(crate)


# ---------- Касса лагеря ----------

func _build_cash_box() -> void:
	_cash_zone = _make_zone("CashBox", CASH_BOX, &"collect")
	_cash_zone.prompt = "ЗАБРАТЬ"
	_cash_zone.interacted.connect(_on_collect)
	var path: String = HubCamp.DIR + "chest.glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var chest := scene.instantiate() as Node3D
		chest.scale = Vector3.ONE * HubCamp.PROP_SCALE
		chest.position = CASH_BOX
		chest.rotation.y = -PI * 0.5
		add_child(chest)
	_cash_label = Label3D.new()
	_cash_label.font_size = 44
	_cash_label.outline_size = 12
	_cash_label.pixel_size = 0.005
	_cash_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cash_label.modulate = UIKit.ACCENT
	_cash_label.position = CASH_BOX + Vector3(0.0, 1.5, 0.0)
	add_child(_cash_label)


func _update_cash() -> void:
	if _cash_label == null:
		return
	var shelter: ShelterState = GameState.shelter
	var pending: int = floori(shelter.get_pending_income())
	var full: bool = pending >= floori(shelter.get_income_cap())
	_cash_label.text = UIKit.t("КАССА ЛАГЕРЯ") + "\n+%d" % pending + (UIKit.t("  (ПОЛНАЯ)") if full else "")
	_cash_label.modulate = Color(1.0, 0.55, 0.35) if full else UIKit.ACCENT
	if _cash_zone != null:
		_cash_zone.set_prompt(UIKit.t("ЗАБРАТЬ +%d") % pending)


func _on_collect() -> void:
	var amount: int = GameState.shelter.collect_income()
	if amount <= 0:
		_float_text(CASH_BOX, "КАССА ПУСТА — ЛЮДИ ЕЩЁ РАБОТАЮТ", UIKit.DIM)
		return
	Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	_float_text(CASH_BOX, "+%s" % UIKit.coins_text(amount), UIKit.ACCENT)
	_update_cash()


## Всплывающая надпись над точкой
func _float_text(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 12
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.position = at + Vector3(0.0, 2.2, 0.0)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.8)
	tween.chain().tween_callback(label.queue_free)
