extends Node
## Автозагрузка "GameState": монеты, купленное оружие, улучшения, рекорды и звёзды миссий,
## улучшения игрока, ежедневная награда и задания.
## Сохраняется в user://save.json, запись атомарная через временный файл.

signal coins_changed(coins: int)
signal weapons_changed
## Изменились задания, ежедневная награда или улучшения игрока
signal progress_changed
signal inventory_changed

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const BROKEN_PATH: String = "user://save.json.bad"
const SAVE_VERSION: int = 1
const CATALOG_PATH: String = "res://weapons/data/weapon_catalog.tres"
const UPGRADE_STATS: Array[String] = ["damage", "magazine", "reload"]
const DEBUG_COINS: int = 1000
const PLAYER_STATS_PATH: String = "res://player/player_stats.tres"
const QUEST_POOL_PATH: String = "res://quests/quest_pool.tres"
const PLAYER_UPGRADES: Array[String] = ["health", "armor"]
## Каждое прохождение миссии: зомби сильнее на 15% (до x3), награда больше на 10% (до x2)
const DIFFICULTY_PER_CLEAR: float = 0.15
const MAX_DIFFICULTY: float = 3.0
const REWARD_PER_CLEAR: float = 0.1
const MAX_REWARD_MULTIPLIER: float = 2.0
const SECONDS_PER_DAY: int = 86400
## Предметы инвентаря (порядок = порядок в сумке и оружейной)
const ITEM_PATHS: Array[String] = ["res://items/medkit.tres", "res://items/ammo_pack.tres",
	"res://items/grenade.tres", "res://items/molotov.tres", "res://items/scrap.tres"]
const SCRAP_ID: String = "scrap"
## Постройки базы (порядок = порядок в окне БАЗА и во дворе убежища)
const BUILDING_PATHS: Array[String] = ["res://base/workshop.tres", "res://base/medbay.tres",
	"res://base/armory.tres", "res://base/garage.tres"]
## Улучшения машин (гараж): таран — урон сбивания, двигатель — скорость
const CAR_UPGRADES: Array[String] = ["ram", "engine"]
const CAR_UPGRADE_MAX: int = 5
const CAR_UPGRADE_BASE_COST: int = 150
const CAR_UPGRADE_GROWTH: float = 1.6
## Бонус склада патронов к максимальному запасу
const ARMORY_AMMO_BONUS: float = 0.3

var coins: int = 0
var catalog: WeaponCatalog
## Миссия, выбранная в убежище (её читает MissionManager)
var selected_mission: MissionData
var player_stats: PlayerStats
var quest_pool: QuestPool
var items: Array[ItemData] = []
var buildings: Array[BuildingData] = []

var _owned: Array[String] = []
var _upgrades: Dictionary = {}     # id оружия -> {"damage": int, "magazine": int, "reload": int}
var _best_scores: Dictionary = {}  # id миссии -> лучший счёт (наличие ключа = пройдена)
var _mission_stars: Dictionary = {}  # id миссии -> лучшие звёзды (1..3)
var _mission_clears: Dictionary = {}  # id миссии -> число побед
var _player_upgrades: Dictionary = {}  # "health"/"armor" -> уровень
var _daily_last_day: int = -1
var _daily_streak: int = 0
var _quest_day: int = -1
var _quests: Array[Dictionary] = []  # {"id": String, "progress": int, "claimed": bool}
var _inventory: Dictionary = {}  # id предмета -> количество
var _buildings_owned: Array[String] = []
var _car_upgrades: Dictionary = {}  # "ram"/"engine" -> уровень


func _ready() -> void:
	if ResourceLoader.exists(CATALOG_PATH):
		catalog = load(CATALOG_PATH) as WeaponCatalog
	if catalog == null:
		push_error("GameState: не найден каталог оружия %s" % CATALOG_PATH)
		catalog = WeaponCatalog.new()
	if ResourceLoader.exists(PLAYER_STATS_PATH):
		player_stats = load(PLAYER_STATS_PATH) as PlayerStats
	if player_stats == null:
		push_warning("GameState: не найден %s, параметры игрока по умолчанию" % PLAYER_STATS_PATH)
		player_stats = PlayerStats.new()
	if ResourceLoader.exists(QUEST_POOL_PATH):
		quest_pool = load(QUEST_POOL_PATH) as QuestPool
	if quest_pool == null:
		push_warning("GameState: не найден %s, заданий не будет" % QUEST_POOL_PATH)
		quest_pool = QuestPool.new()
	for path: String in ITEM_PATHS:
		var item: ItemData = load(path) as ItemData if ResourceLoader.exists(path) else null
		if item == null or item.id.is_empty():
			push_warning("GameState: не найден предмет %s" % path)
			continue
		items.append(item)
	for path: String in BUILDING_PATHS:
		var building: BuildingData = load(path) as BuildingData if ResourceLoader.exists(path) else null
		if building == null or building.id.is_empty():
			push_warning("GameState: не найдена постройка %s" % path)
			continue
		buildings.append(building)
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
	var upgraded: WeaponData = weapon.make_upgraded(_upgrades.get(weapon.id, {}))
	if upgraded.max_reserve_ammo > 0 and get_ammo_bonus() > 0.0:
		upgraded.max_reserve_ammo = roundi(upgraded.max_reserve_ammo * (1.0 + get_ammo_bonus()))
	return upgraded


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


func complete_mission(mission: MissionData, score: int, stars: int = 1) -> void:
	if mission == null or mission.id.is_empty():
		return
	var best: int = int(_best_scores.get(mission.id, -1))
	if score > best:
		_best_scores[mission.id] = maxi(score, 0)
	_mission_stars[mission.id] = maxi(int(_mission_stars.get(mission.id, 0)), clampi(stars, 1, 3))
	_mission_clears[mission.id] = int(_mission_clears.get(mission.id, 0)) + 1
	save_game()


## Рекорд без засчитанной победы (бесконечный режим: число волн)
func record_score(mission: MissionData, score: int) -> void:
	if mission == null or mission.id.is_empty():
		return
	if score > int(_best_scores.get(mission.id, -1)):
		_best_scores[mission.id] = maxi(score, 0)
		save_game()


func get_mission_stars(mission_id: String) -> int:
	return int(_mission_stars.get(mission_id, 0))


## Уровень миссии = число побед + 1 (с ним растут сложность и награда)
func get_mission_level(mission_id: String) -> int:
	return int(_mission_clears.get(mission_id, 0)) + 1


func get_difficulty_multiplier(mission_id: String) -> float:
	return minf(1.0 + DIFFICULTY_PER_CLEAR * (get_mission_level(mission_id) - 1), MAX_DIFFICULTY)


func get_reward_multiplier(mission_id: String) -> float:
	return minf(1.0 + REWARD_PER_CLEAR * (get_mission_level(mission_id) - 1), MAX_REWARD_MULTIPLIER)


# ---------- Инвентарь ----------

func get_item(item_id: String) -> ItemData:
	for item: ItemData in items:
		if item.id == item_id:
			return item
	return null


func get_item_count(item_id: String) -> int:
	return int(_inventory.get(item_id, 0))


## Положить в сумку. false — нет такого предмета или стопка полна.
## Не сохраняет сразу (подборы частые) — сохранение в конце миссии
func add_item(item_id: String, count: int = 1) -> bool:
	var item: ItemData = get_item(item_id)
	if item == null or count <= 0:
		return false
	var current: int = get_item_count(item_id)
	if current >= item.max_stack:
		return false
	_inventory[item_id] = mini(current + count, item.max_stack)
	inventory_changed.emit()
	return true


## Использовать предмет на игроке; тратится, только если подействовал
func use_item(item_id: String, player: Player) -> bool:
	var item: ItemData = get_item(item_id)
	if item == null or get_item_count(item_id) <= 0:
		return false
	if not item.apply(player):
		return false
	_inventory[item_id] = get_item_count(item_id) - 1
	inventory_changed.emit()
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	if get_item_count(item_id) < count or count <= 0:
		return false
	_inventory[item_id] = get_item_count(item_id) - count
	inventory_changed.emit()
	return true


## Первый имеющийся метательный предмет (сначала граната, потом коктейль)
func get_throwable() -> ItemData:
	for item: ItemData in items:
		if item.is_throwable() and get_item_count(item.id) > 0:
			return item
	return null


func get_throwable_count() -> int:
	var total: int = 0
	for item: ItemData in items:
		if item.is_throwable():
			total += get_item_count(item.id)
	return total


## Сборка в мастерской из лома
func craft_item(item_id: String) -> bool:
	var item: ItemData = get_item(item_id)
	if item == null or item.craft_cost <= 0 or not has_building("workshop"):
		return false
	if get_item_count(SCRAP_ID) < item.craft_cost or get_item_count(item_id) >= item.max_stack:
		return false
	remove_item(SCRAP_ID, item.craft_cost)
	add_item(item_id)
	save_game()
	return true


func buy_item(item_id: String) -> bool:
	var item: ItemData = get_item(item_id)
	if item == null or item.price <= 0 or coins < item.price:
		return false
	if not add_item(item_id):
		return false
	coins -= item.price
	coins_changed.emit(coins)
	save_game()
	return true


# ---------- База и гараж ----------

func has_building(building_id: String) -> bool:
	return building_id in _buildings_owned


func get_building(building_id: String) -> BuildingData:
	for building: BuildingData in buildings:
		if building.id == building_id:
			return building
	return null


func buy_building(building_id: String) -> bool:
	var building: BuildingData = get_building(building_id)
	if building == null or has_building(building_id) or coins < building.price:
		return false
	coins -= building.price
	_buildings_owned.append(building_id)
	coins_changed.emit(coins)
	progress_changed.emit()
	save_game()
	return true


## Медпункт: аптечка перед миссией, если её нет. Вызывает MissionManager
func on_mission_started() -> void:
	if has_building("medbay") and get_item_count("medkit") <= 0:
		add_item("medkit")


func get_ammo_bonus() -> float:
	return ARMORY_AMMO_BONUS if has_building("armory") else 0.0


func get_car_upgrade_level(stat: String) -> int:
	return int(_car_upgrades.get(stat, 0))


func get_car_upgrade_cost(stat: String) -> int:
	var level: int = get_car_upgrade_level(stat)
	if level >= CAR_UPGRADE_MAX:
		return -1
	return roundi(CAR_UPGRADE_BASE_COST * pow(CAR_UPGRADE_GROWTH, level))


func upgrade_car(stat: String) -> bool:
	if not stat in CAR_UPGRADES or not has_building("garage"):
		return false
	var cost: int = get_car_upgrade_cost(stat)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	_car_upgrades[stat] = get_car_upgrade_level(stat) + 1
	coins_changed.emit(coins)
	progress_changed.emit()
	save_game()
	return true


# ---------- Улучшения игрока ----------

func get_player_upgrade_level(stat: String) -> int:
	return int(_player_upgrades.get(stat, 0))


func get_player_upgrade_cost(stat: String) -> int:
	return player_stats.get_cost(stat, get_player_upgrade_level(stat))


func upgrade_player(stat: String) -> bool:
	if not stat in PLAYER_UPGRADES:
		return false
	var cost: int = get_player_upgrade_cost(stat)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	_player_upgrades[stat] = get_player_upgrade_level(stat) + 1
	coins_changed.emit(coins)
	progress_changed.emit()
	save_game()
	return true


func get_player_max_health() -> float:
	return player_stats.get_max_health(get_player_upgrade_level("health"))


func get_player_armor() -> float:
	return player_stats.get_armor(get_player_upgrade_level("armor"))


# ---------- Ежедневная награда ----------

func get_today() -> int:
	return floori(Time.get_unix_time_from_system() / SECONDS_PER_DAY)


func can_claim_daily() -> bool:
	return _daily_last_day != get_today()


## День серии, который будет засчитан при получении награды сегодня
func get_next_streak() -> int:
	var today: int = get_today()
	if _daily_last_day == today:
		return _daily_streak
	if _daily_last_day == today - 1:
		return mini(_daily_streak + 1, quest_pool.max_streak)
	return 1


func get_daily_reward() -> int:
	return quest_pool.daily_reward_base * get_next_streak()


## Возвращает выданные монеты (0 — сегодня уже получено)
func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	var reward: int = get_daily_reward()
	_daily_streak = get_next_streak()
	_daily_last_day = get_today()
	coins += reward
	coins_changed.emit(coins)
	progress_changed.emit()
	save_game()
	return reward


# ---------- Ежедневные задания ----------

## Задания на сегодня (при смене дня выбираются новые)
func get_quests() -> Array[Dictionary]:
	_ensure_today_quests()
	return _quests


## Событие для заданий: kill, headshot_kill, tank_kill, boss_kill, mission_win, item_collect.
## Не сохраняет сразу (вызывается часто) — сохранение в конце миссии
func report_event(event: StringName, amount: int = 1) -> void:
	_ensure_today_quests()
	for entry: Dictionary in _quests:
		if bool(entry.get("claimed", false)):
			continue
		var quest: QuestData = quest_pool.find(str(entry.get("id", "")))
		if quest == null or quest.event != event:
			continue
		entry["progress"] = mini(int(entry.get("progress", 0)) + amount, quest.target)


func is_quest_complete(entry: Dictionary) -> bool:
	var quest: QuestData = quest_pool.find(str(entry.get("id", "")))
	return quest != null and int(entry.get("progress", 0)) >= quest.target


func claim_quest(index: int) -> bool:
	_ensure_today_quests()
	if index < 0 or index >= _quests.size():
		return false
	var entry: Dictionary = _quests[index]
	if bool(entry.get("claimed", false)) or not is_quest_complete(entry):
		return false
	var quest: QuestData = quest_pool.find(str(entry.get("id", "")))
	entry["claimed"] = true
	coins += quest.reward_coins
	coins_changed.emit(coins)
	progress_changed.emit()
	save_game()
	return true


## Есть что забрать (для значка на кнопке в убежище)
func has_unclaimed_rewards() -> bool:
	if can_claim_daily():
		return true
	for entry: Dictionary in get_quests():
		if not bool(entry.get("claimed", false)) and is_quest_complete(entry):
			return true
	return false


func _ensure_today_quests() -> void:
	var today: int = get_today()
	if _quest_day == today and not _quests.is_empty():
		return
	_quest_day = today
	_quests.clear()
	var pool: Array[QuestData] = []
	for quest: QuestData in quest_pool.quests:
		if quest != null and not quest.id.is_empty():
			pool.append(quest)
	# Одинаковый набор на весь день: генератор с зерном от номера дня
	var rng := RandomNumberGenerator.new()
	rng.seed = today
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: QuestData = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in mini(quest_pool.daily_count, pool.size()):
		_quests.append({"id": pool[i].id, "progress": 0, "claimed": false})


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
	_mission_stars.clear()
	_mission_clears.clear()
	_player_upgrades.clear()
	_daily_last_day = -1
	_daily_streak = 0
	_quest_day = -1
	_quests.clear()
	_inventory.clear()
	_buildings_owned.clear()
	_car_upgrades.clear()
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
		"mission_stars": _mission_stars,
		"mission_clears": _mission_clears,
		"player_upgrades": _player_upgrades,
		"daily_last_day": _daily_last_day,
		"daily_streak": _daily_streak,
		"quest_day": _quest_day,
		"quests": _quests,
		"inventory": _inventory,
		"buildings": _buildings_owned,
		"car_upgrades": _car_upgrades,
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

	_mission_stars = _load_int_dictionary(data.get("mission_stars", {}), 0, 3)
	_mission_clears = _load_int_dictionary(data.get("mission_clears", {}), 0, 100000)
	_player_upgrades.clear()
	var upgrades_player: Dictionary = _load_int_dictionary(data.get("player_upgrades", {}), 0, player_stats.max_level)
	for stat: String in PLAYER_UPGRADES:
		if upgrades_player.has(stat):
			_player_upgrades[stat] = upgrades_player[stat]

	_daily_last_day = int(data.get("daily_last_day", -1))
	_daily_streak = clampi(int(data.get("daily_streak", 0)), 0, quest_pool.max_streak)
	_quest_day = int(data.get("quest_day", -1))
	_quests.clear()
	var quests: Variant = data.get("quests", [])
	if quests is Array:
		for entry: Variant in quests:
			if not entry is Dictionary:
				continue
			var quest_id: String = str((entry as Dictionary).get("id", ""))
			if quest_pool.find(quest_id) == null:
				continue
			_quests.append({
				"id": quest_id,
				"progress": maxi(int((entry as Dictionary).get("progress", 0)), 0),
				"claimed": bool((entry as Dictionary).get("claimed", false)),
			})

	_buildings_owned.clear()
	var owned_buildings: Variant = data.get("buildings", [])
	if owned_buildings is Array:
		for building_id: Variant in owned_buildings:
			if get_building(str(building_id)) != null and not has_building(str(building_id)):
				_buildings_owned.append(str(building_id))
	_car_upgrades.clear()
	var stored_car: Dictionary = _load_int_dictionary(data.get("car_upgrades", {}), 0, CAR_UPGRADE_MAX)
	for stat: String in CAR_UPGRADES:
		if stored_car.has(stat):
			_car_upgrades[stat] = stored_car[stat]

	_inventory.clear()
	var stored: Dictionary = _load_int_dictionary(data.get("inventory", {}), 0, 99)
	for item_id: String in stored:
		var item: ItemData = get_item(item_id)
		if item != null:
			_inventory[item_id] = mini(int(stored[item_id]), item.max_stack)


## Словарь {строка: int} из JSON с ограничением значений
func _load_int_dictionary(source: Variant, min_value: int, max_value: int) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		for key: Variant in source:
			result[str(key)] = clampi(int((source as Dictionary)[key]), min_value, max_value)
	return result


## Выдаёт бесплатные стволы (price = 0). Возвращает true, если что-то выдано
func _grant_free_weapons() -> bool:
	var changed: bool = false
	for weapon: WeaponData in catalog.weapons:
		if weapon != null and weapon.price <= 0 and not weapon.id.is_empty() and not owns(weapon.id):
			_owned.append(weapon.id)
			changed = true
	return changed
