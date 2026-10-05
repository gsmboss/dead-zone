extends Node
## Автозагрузка "GameState": монеты, купленное оружие, улучшения, рекорды миссий.
## Сохраняется в user://save.json, запись атомарная через временный файл.

signal coins_changed(coins: int)
signal weapons_changed

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const BROKEN_PATH: String = "user://save.json.bad"
const SAVE_VERSION: int = 1
const CATALOG_PATH: String = "res://weapons/data/weapon_catalog.tres"
const UPGRADE_STATS: Array[String] = ["damage", "magazine", "reload"]
const DEBUG_COINS: int = 1000

var coins: int = 0
var catalog: WeaponCatalog
## Миссия, выбранная в убежище (её читает MissionManager)
var selected_mission: MissionData

var _owned: Array[String] = []
var _upgrades: Dictionary = {}     # id оружия -> {"damage": int, "magazine": int, "reload": int}
var _best_scores: Dictionary = {}  # id миссии -> лучший счёт (наличие ключа = пройдена)


func _ready() -> void:
	if ResourceLoader.exists(CATALOG_PATH):
		catalog = load(CATALOG_PATH) as WeaponCatalog
	if catalog == null:
		push_error("GameState: не найден каталог оружия %s" % CATALOG_PATH)
		catalog = WeaponCatalog.new()
	load_game()
	if _grant_free_weapons():
		save_game()


func _notification(what: int) -> void:
	# Игра свёрнута или закрывается — сохраняемся
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _unhandled_input(event: InputEvent) -> void:
	# Только для отладки: F9 = +1000 монет
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		add_coins(DEBUG_COINS)
		print("GameState: +%d монет (отладка)" % DEBUG_COINS)


# ---------- Оружие ----------

func owns(weapon_id: String) -> bool:
	return weapon_id in _owned


func get_upgrade_level(weapon_id: String, stat: String) -> int:
	var levels: Dictionary = _upgrades.get(weapon_id, {})
	return int(levels.get(stat, 0))


func get_upgrade_cost(weapon: WeaponData, stat: String) -> int:
	return weapon.get_upgrade_cost(get_upgrade_level(weapon.id, stat))


func get_upgraded(weapon: WeaponData) -> WeaponData:
	return weapon.make_upgraded(_upgrades.get(weapon.id, {}))


## Купленные стволы с улучшениями, в порядке каталога
func get_loadout() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon: WeaponData in catalog.weapons:
		if weapon != null and owns(weapon.id):
			result.append(get_upgraded(weapon))
	return result


func buy_weapon(weapon: WeaponData) -> bool:
	if weapon == null or weapon.id.is_empty() or owns(weapon.id) or coins < weapon.price:
		return false
	coins -= weapon.price
	_owned.append(weapon.id)
	coins_changed.emit(coins)
	weapons_changed.emit()
	save_game()
	return true


func upgrade_weapon(weapon: WeaponData, stat: String) -> bool:
	if weapon == null or not owns(weapon.id) or not stat in UPGRADE_STATS:
		return false
	var cost: int = get_upgrade_cost(weapon, stat)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	var levels: Dictionary = _upgrades.get(weapon.id, {})
	levels[stat] = int(levels.get(stat, 0)) + 1
	_upgrades[weapon.id] = levels
	coins_changed.emit(coins)
	weapons_changed.emit()
	save_game()
	return true


# ---------- Монеты и миссии ----------

func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)
	save_game()


func complete_mission(mission: MissionData, score: int) -> void:
	if mission == null or mission.id.is_empty():
		return
	var best: int = int(_best_scores.get(mission.id, -1))
	if score > best:
		_best_scores[mission.id] = maxi(score, 0)
		save_game()


func is_mission_completed(mission_id: String) -> bool:
	return _best_scores.has(mission_id)


func get_best_score(mission_id: String) -> int:
	return int(_best_scores.get(mission_id, 0))


func start_mission(mission: MissionData) -> void:
	if mission == null:
		return
	if not ResourceLoader.exists(mission.level_scene):
		push_error("GameState: не найдена сцена уровня %s" % mission.level_scene)
		return
	selected_mission = mission
	get_tree().change_scene_to_file(mission.level_scene)


func reset_progress() -> void:
	coins = 0
	_owned.clear()
	_upgrades.clear()
	_best_scores.clear()
	_grant_free_weapons()
	coins_changed.emit(coins)
	weapons_changed.emit()
	save_game()


# ---------- Сохранение ----------

func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"coins": coins,
		"owned": _owned,
		"upgrades": _upgrades,
		"best_scores": _best_scores,
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: не удалось записать сохранение: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Переименование атомарно: при сбое во время записи старое сохранение цело
	var err: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("GameState: ошибка сохранения: %s" % error_string(err))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: сохранение повреждено, начинаем заново")
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BROKEN_PATH))
		return
	var data: Dictionary = parsed

	coins = maxi(int(data.get("coins", 0)), 0)

	_owned.clear()
	var owned: Variant = data.get("owned", [])
	if owned is Array:
		for weapon_id: Variant in owned:
			var id_text: String = str(weapon_id)
			if catalog.find(id_text) != null and not owns(id_text):
				_owned.append(id_text)

	_upgrades.clear()
	var upgrades: Variant = data.get("upgrades", {})
	if upgrades is Dictionary:
		for weapon_id: Variant in upgrades:
			var weapon: WeaponData = catalog.find(str(weapon_id))
			var levels: Variant = upgrades[weapon_id]
			if weapon == null or not levels is Dictionary:
				continue
			var clean: Dictionary = {}
			for stat: String in UPGRADE_STATS:
				clean[stat] = clampi(int(levels.get(stat, 0)), 0, weapon.max_upgrade_level)
			_upgrades[weapon.id] = clean

	_best_scores.clear()
	var scores: Variant = data.get("best_scores", {})
	if scores is Dictionary:
		for mission_id: Variant in scores:
			_best_scores[str(mission_id)] = int(scores[mission_id])


## Выдаёт бесплатные стволы (price = 0). Возвращает true, если что-то выдано
func _grant_free_weapons() -> bool:
	var changed: bool = false
	for weapon: WeaponData in catalog.weapons:
		if weapon != null and weapon.price <= 0 and not weapon.id.is_empty() and not owns(weapon.id):
			_owned.append(weapon.id)
			changed = true
	return changed
