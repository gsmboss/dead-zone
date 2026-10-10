extends Node
## Автозагрузка "GameState": монеты, купленное оружие, улучшения, рекорды и звёзды миссий,
## улучшения игрока, ежедневная награда и задания.
## Сохраняется в user://save.json, запись атомарная через временный файл.

signal coins_changed(coins: int)
signal weapons_changed
## Изменились задания, ежедневная награда или улучшения игрока
signal progress_changed
signal inventory_changed
signal skin_changed(skin: PlayerSkin)
signal gear_changed
signal campaign_changed
## Куплена, выбрана, покрашена или затюнингована машина
signal cars_changed
## Получено достижение (награда уже начислена)
signal achievement_unlocked(achievement: AchievementData)
## Убежище: уровень, провизия, настроение, касса, обустройство (shelter)
signal shelter_changed

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const BROKEN_PATH: String = "user://save.json.bad"
const SAVE_VERSION: int = 1
const CATALOG_PATH: String = "res://weapons/data/weapon_catalog.tres"
const UPGRADE_STATS: Array[String] = ["damage", "magazine", "reload"]
const DEBUG_COINS: int = 1000
const PLAYER_STATS_PATH: String = "res://player/player_stats.tres"
const QUEST_POOL_PATH: String = "res://quests/quest_pool.tres"
const ACHIEVEMENTS_PATH: String = "res://quests/achievements.tres"
const WEEKLY_EVENTS_PATH: String = "res://quests/weekly_events.tres"
## Код сохранения (перенос на другое устройство): "DZ1-<md5[:8]>-<base64 gzip JSON>"
const SAVE_CODE_PREFIX: String = "DZ1"
const SAVE_CODE_MAX_SIZE: int = 4 * 1024 * 1024
const CAMPAIGN_PATH: String = "res://story/campaign.tres"
const PLAYER_UPGRADES: Array[String] = ["health", "armor"]
## Каждое прохождение миссии: зомби сильнее на 15% (до x3), награда больше на 10% (до x2)
const DIFFICULTY_PER_CLEAR: float = 0.15
const MAX_DIFFICULTY: float = 3.0
const REWARD_PER_CLEAR: float = 0.1
const MAX_REWARD_MULTIPLIER: float = 2.0
const SECONDS_PER_DAY: int = 86400
## Предметы инвентаря (порядок = порядок в сумке и оружейной)
const ITEM_PATHS: Array[String] = ["res://items/medkit.tres", "res://items/ammo_pack.tres",
	"res://items/grenade.tres", "res://items/molotov.tres", "res://items/scrap.tres",
	"res://items/turret.tres", "res://items/bear_trap.tres", "res://items/land_mine.tres"]
const SCRAP_ID: String = "scrap"
## Постройки базы (порядок = порядок в окне БАЗА и во дворе убежища)
## Набег на убежище: раз в RAID_INTERVAL секунд «ОРДА У ВОРОТ!» (HubHUD) — миссия обороны
## с набором ловушек RAID_KIT и наградой ×RAID_REWARD
const RAID_MISSION_PATH: String = "res://missions/data/mission_shelter.tres"
const RAID_INTERVAL: int = 20 * 3600
## Первый набег — через столько секунд после первой победы
const RAID_FIRST_DELAY: int = 20 * 60
const RAID_REWARD: float = 2.0
const RAID_KIT: Dictionary = {"turret": 1, "bear_trap": 2, "land_mine": 2}
## Обвесы оружия (порядок = порядок в оружейной)
const ATTACHMENT_PATHS: Array[String] = ["res://weapons/attachments/silencer.tres",
	"res://weapons/attachments/compensator.tres", "res://weapons/attachments/red_dot.tres",
	"res://weapons/attachments/extended_mag.tres", "res://weapons/attachments/fast_mag.tres",
	"res://weapons/attachments/laser.tres", "res://weapons/attachments/grip.tres"]
## Снаряжение (покупается один раз)
const GEAR_PATHS: Array[String] = ["res://items/torch.tres"]
## Скины игрока (вид от 3-го лица и мультиплеер). Первый — по умолчанию
const SKIN_PATHS: Array[String] = [
	"res://player/skins/shaun.tres", "res://player/skins/lis.tres", "res://player/skins/matt.tres",
	"res://player/skins/sam.tres", "res://player/skins/kenney_male_a.tres",
	"res://player/skins/kenney_female_a.tres", "res://player/skins/kenney_male_c.tres",
	"res://player/skins/kenney_female_c.tres", "res://player/skins/kenney_male_e.tres",
	"res://player/skins/kenney_female_e.tres", "res://player/skins/kenney_male_b.tres",
	"res://player/skins/kenney_female_b.tres", "res://player/skins/kenney_male_d.tres",
	"res://player/skins/kenney_female_d.tres", "res://player/skins/kenney_male_f.tres",
	"res://player/skins/kenney_female_f.tres", "res://player/skins/zombie_cosplay.tres",
	"res://player/skins/zombie_chubby.tres",
]
const BUILDING_PATHS: Array[String] = ["res://base/workshop.tres", "res://base/medbay.tres",
	"res://base/armory.tres", "res://base/garage.tres", "res://base/garden.tres", "res://base/watchtower.tres",
	"res://base/radio.tres", "res://base/generator.tres", "res://base/canteen.tres"]
## Улучшения машин (гараж): таран — урон сбивания, двигатель — скорость
const CAR_UPGRADES: Array[String] = ["ram", "engine"]
const CAR_UPGRADE_MAX: int = 5
const CAR_UPGRADE_BASE_COST: int = 150
const CAR_UPGRADE_GROWTH: float = 1.6
## Автосалон: машины классов D/C/B/A (первая — бесплатная)
const CAR_PATHS: Array[String] = ["res://vehicles/cars/pickup.tres", "res://vehicles/cars/truck.tres",
	"res://vehicles/cars/pickup_armored.tres", "res://vehicles/cars/sports.tres",
	"res://vehicles/cars/truck_armored.tres", "res://vehicles/cars/sports_armored.tres",
	"res://vehicles/cars/bike.tres"]
## Тюнинг машины: двигатель — макс. скорость, газ — разгон, управление — руль и сцепление, таран — урон
const CAR_TUNING: Array[String] = ["engine", "turbo", "handling", "ram", "armor", "spikes"]
const CAR_TUNING_MAX: int = 5
const CAR_TUNING_GROWTH: float = 1.55
## Покраска (индекс 0 — заводской цвет, бесплатно) и неон под днищем
const CAR_PAINTS: Array[Color] = [Color.WHITE, Color(0.95, 0.25, 0.2), Color(0.3, 0.55, 1.0),
	Color(0.35, 0.85, 0.35), Color(1.0, 0.85, 0.25), Color(0.32, 0.32, 0.36), Color(0.75, 0.4, 1.0),
	Color(1.0, 0.55, 0.15), Color(0.55, 0.95, 0.95)]
const CAR_PAINT_NAMES: PackedStringArray = ["ЗАВОДСКОЙ", "КРАСНЫЙ", "СИНИЙ", "ЗЕЛЁНЫЙ", "ЖЁЛТЫЙ",
	"ГРАФИТ", "ФИОЛЕТОВЫЙ", "ОРАНЖЕВЫЙ", "БИРЮЗОВЫЙ"]
const CAR_PAINT_PRICE: int = 150
const CAR_NEONS: Array[Color] = [Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(0.3, 1.0, 0.3),
	Color(1.0, 0.5, 0.1), Color(0.6, 0.3, 1.0)]
const CAR_NEON_PRICE: int = 400
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
## Развитие убежища (base/shelter_state.gd)
var shelter: ShelterState

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
var cars: Array[CarData] = []
var _cars_owned: Array[String] = []
var _car_id: String = ""
var _car_tuning: Dictionary = {}  # id машины -> {"engine": int, ...}
var _car_paint: Dictionary = {}   # id машины -> индекс CAR_PAINTS
var _car_neon: Dictionary = {}    # id машины -> индекс CAR_NEONS (нет ключа — неона нет)
var _cutscenes_seen: Array[String] = []
var skins: Array[PlayerSkin] = []
var gear: Array[GearData] = []
var campaign: CampaignData
var _chapters_done: Array[String] = []
## Рассказ, который покажется в убежище: id главы (концовка) или "epilogue"
var _pending_story: String = ""
var _gear_owned: Array[String] = []
var _skins_owned: Array[String] = []
var _skin_id: String = ""
## Время следующего набега (unix, 0 — ещё не назначен)
var _next_raid: int = 0
## Идёт миссия-набег (награда ×RAID_REWARD); не сохраняется
var raid_active: bool = false
var attachments: Array[AttachmentData] = []
var _race_best: Dictionary = {}  # id трассы -> лучшее время, с
var achievement_list: AchievementList
var weekly_events: WeeklyEventList
var _stats: Dictionary = {}          # событие -> счётчик за всю игру (или рекорд)
var _achievements_done: Array[String] = []
var _weekly: Dictionary = {}         # {"week": int, "progress": int, "claimed": bool}
var _attachments_owned: Dictionary = {}  # id ствола -> Array[String] купленных обвесов
var _attachments_on: Dictionary = {}     # id ствола -> Array[String] поставленных (по одному на слот)


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
	if ResourceLoader.exists(ACHIEVEMENTS_PATH):
		achievement_list = load(ACHIEVEMENTS_PATH) as AchievementList
	if achievement_list == null:
		push_warning("GameState: не найден %s, достижений не будет" % ACHIEVEMENTS_PATH)
		achievement_list = AchievementList.new()
	if ResourceLoader.exists(WEEKLY_EVENTS_PATH):
		weekly_events = load(WEEKLY_EVENTS_PATH) as WeeklyEventList
	if weekly_events == null:
		weekly_events = WeeklyEventList.new()
	if ResourceLoader.exists(QUEST_POOL_PATH):
		quest_pool = load(QUEST_POOL_PATH) as QuestPool
	if quest_pool == null:
		push_warning("GameState: не найден %s, заданий не будет" % QUEST_POOL_PATH)
		quest_pool = QuestPool.new()
	for path: String in ATTACHMENT_PATHS:
		var attachment := load(path) as AttachmentData if ResourceLoader.exists(path) else null
		if attachment != null and not attachment.id.is_empty():
			attachments.append(attachment)
		else:
			push_warning("GameState: не найден обвес %s" % path)
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
	if ResourceLoader.exists(CAMPAIGN_PATH):
		campaign = load(CAMPAIGN_PATH) as CampaignData
	if campaign == null:
		push_warning("GameState: не найдена кампания %s" % CAMPAIGN_PATH)
		campaign = CampaignData.new()
	for path: String in GEAR_PATHS:
		var gear_item: GearData = load(path) as GearData if ResourceLoader.exists(path) else null
		if gear_item == null or gear_item.id.is_empty():
			push_warning("GameState: не найдено снаряжение %s" % path)
			continue
		gear.append(gear_item)
	for path: String in SKIN_PATHS:
		var skin: PlayerSkin = load(path) as PlayerSkin if ResourceLoader.exists(path) else null
		if skin == null or skin.id.is_empty():
			push_warning("GameState: не найден скин %s" % path)
			continue
		skins.append(skin)
	for path: String in CAR_PATHS:
		var car: CarData = load(path) as CarData if ResourceLoader.exists(path) else null
		if car == null or car.id.is_empty():
			push_warning("GameState: не найдена машина %s" % path)
			continue
		cars.append(car)
	shelter = ShelterState.new()
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
	elif key != null and key.pressed and not key.echo and key.keycode == KEY_F10:
		debug_max_shelter()


## Только для отладки (F10): убежище на максимум — все постройки, обустройство, провизия
func debug_max_shelter() -> void:
	shelter.level = shelter.config.get_level_count()
	for building: BuildingData in buildings:
		if not has_building(building.id):
			_buildings_owned.append(building.id)
	for item: DecorData in shelter.decor_list.decor:
		if not shelter.owns_decor(item.id):
			shelter.decor_owned.append(item.id)
	shelter.food = shelter.config.max_food
	shelter.recruited = maxi(shelter.recruited, 20)
	progress_changed.emit()
	shelter_changed.emit()
	save_game()
	print("GameState: убежище на максимум (отладка)")


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
	for attachment: AttachmentData in get_attachments_on(weapon):
		attachment.apply(upgraded)
	if upgraded.max_reserve_ammo > 0 and get_ammo_bonus() > 0.0:
		upgraded.max_reserve_ammo = roundi(upgraded.max_reserve_ammo * (1.0 + get_ammo_bonus()))
	return upgraded


# ---------- Заезды (город) ----------

func get_race_best(route_id: String) -> float:
	return float(_race_best.get(route_id, 0.0))


## Записать время заезда; true — новый рекорд
func record_race(route_id: String, seconds: float) -> bool:
	var best: float = get_race_best(route_id)
	if best > 0.0 and seconds >= best:
		return false
	_race_best[route_id] = snappedf(seconds, 0.1)
	save_game()
	return true


# ---------- Обвесы ----------

func get_attachment(attachment_id: String) -> AttachmentData:
	for attachment: AttachmentData in attachments:
		if attachment.id == attachment_id:
			return attachment
	return null


## Обвесы, которые подходят к стволу
func get_attachments_for(weapon: WeaponData) -> Array[AttachmentData]:
	var result: Array[AttachmentData] = []
	for attachment: AttachmentData in attachments:
		if attachment.fits(weapon):
			result.append(attachment)
	return result


func owns_attachment(weapon_id: String, attachment_id: String) -> bool:
	return attachment_id in (_attachments_owned.get(weapon_id, []) as Array)


func is_attachment_on(weapon_id: String, attachment_id: String) -> bool:
	return attachment_id in (_attachments_on.get(weapon_id, []) as Array)


## Поставленные на ствол обвесы (только подходящие и купленные)
func get_attachments_on(weapon: WeaponData) -> Array[AttachmentData]:
	var result: Array[AttachmentData] = []
	if weapon == null:
		return result
	for attachment_id: Variant in (_attachments_on.get(weapon.id, []) as Array):
		var attachment: AttachmentData = get_attachment(str(attachment_id))
		if attachment != null and attachment.fits(weapon) and owns_attachment(weapon.id, attachment.id):
			result.append(attachment)
	return result


## Купить обвес для ствола — сразу ставится (заменяя другой в том же слоте)
func buy_attachment(weapon: WeaponData, attachment: AttachmentData) -> bool:
	if weapon == null or attachment == null or not owns(weapon.id) or not attachment.fits(weapon) \
			or owns_attachment(weapon.id, attachment.id):
		return false
	var cost: int = attachment.get_price(weapon)
	if coins < cost:
		return false
	coins -= cost
	var owned: Array = _attachments_owned.get(weapon.id, [])
	owned.append(attachment.id)
	report_event(&"attachment_buy")
	_attachments_owned[weapon.id] = owned
	_put_on(weapon.id, attachment)
	coins_changed.emit(coins)
	weapons_changed.emit()
	save_game()
	return true


## Поставить / снять купленный обвес
func toggle_attachment(weapon: WeaponData, attachment: AttachmentData) -> bool:
	if weapon == null or attachment == null or not owns_attachment(weapon.id, attachment.id):
		return false
	if is_attachment_on(weapon.id, attachment.id):
		var on: Array = _attachments_on.get(weapon.id, [])
		on.erase(attachment.id)
		_attachments_on[weapon.id] = on
	else:
		_put_on(weapon.id, attachment)
	weapons_changed.emit()
	save_game()
	return true


## Поставить обвес, сняв другой с того же слота
func _put_on(weapon_id: String, attachment: AttachmentData) -> void:
	var on: Array = _attachments_on.get(weapon_id, [])
	for other_id: Variant in on.duplicate():
		var other: AttachmentData = get_attachment(str(other_id))
		if other == null or other.slot == attachment.slot:
			on.erase(other_id)
	on.append(attachment.id)
	_attachments_on[weapon_id] = on


func _load_attachments(source: Variant, check_owned: bool) -> Dictionary:
	var result: Dictionary = {}
	if not source is Dictionary:
		return result
	for weapon_id: Variant in source:
		var list: Variant = (source as Dictionary)[weapon_id]
		if not list is Array:
			continue
		var clean: Array = []
		for attachment_id: Variant in list:
			var id_text: String = str(attachment_id)
			if get_attachment(id_text) == null or id_text in clean:
				continue
			if check_owned and not owns_attachment(str(weapon_id), id_text):
				continue
			clean.append(id_text)
		if not clean.is_empty():
			result[str(weapon_id)] = clean
	return result


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
	report_event(&"weapon_buy")
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
	if amount > 0:
		report_event(&"coins_earned", amount)
	save_game()


## Списать монеты (покупки в убежище); сохраняет вызывающий
func spend_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins = maxi(coins - amount, 0)
	coins_changed.emit(coins)


func complete_mission(mission: MissionData, score: int, stars: int = 1) -> void:
	if mission == null or mission.id.is_empty():
		return
	var best: int = int(_best_scores.get(mission.id, -1))
	if score > best:
		_best_scores[mission.id] = maxi(score, 0)
	_mission_stars[mission.id] = maxi(int(_mission_stars.get(mission.id, 0)), clampi(stars, 1, 3))
	_mission_clears[mission.id] = int(_mission_clears.get(mission.id, 0)) + 1
	_on_story_mission_won(mission)
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
	# Довольные жильцы убежища — бонус к награде
	return minf(1.0 + REWARD_PER_CLEAR * (get_mission_level(mission_id) - 1), MAX_REWARD_MULTIPLIER) \
		* shelter.get_reward_bonus()


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


## Первая имеющаяся ловушка (турель, капкан, мина) — для кнопки «ЛОВУШКА»
func get_deployable() -> ItemData:
	for item: ItemData in items:
		if item.is_deployable() and get_item_count(item.id) > 0:
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
	report_event(&"craft")
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


# ---------- Сюжетная кампания ----------

func is_chapter_done(chapter_id: String) -> bool:
	return chapter_id in _chapters_done


## Глава открыта, если пройдена предыдущая
func is_chapter_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index >= campaign.chapters.size():
		return false
	var previous: ChapterData = campaign.chapters[index - 1]
	return previous != null and is_chapter_done(previous.id)


## Доля пройденных глав 0..1
func get_campaign_progress() -> float:
	var total: int = campaign.chapters.size()
	return float(_chapters_done.size()) / float(total) if total > 0 else 0.0


func get_rescued_count() -> int:
	var total: int = 0
	for chapter: ChapterData in campaign.chapters:
		if chapter != null and is_chapter_done(chapter.id):
			total += chapter.rescued
	return total


func get_house_count() -> int:
	var total: int = 0
	for chapter: ChapterData in campaign.chapters:
		if chapter != null and chapter.unlock_house and is_chapter_done(chapter.id):
			total += 1
	return total


## Свои машины (модели), полученные в главах
func get_owned_cars() -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for chapter: ChapterData in campaign.chapters:
		if chapter != null and chapter.unlock_car != null and is_chapter_done(chapter.id):
			result.append(chapter.unlock_car)
	return result


## Рассказ для показа в убежище (и сбросить его)
func pop_pending_story() -> String:
	var story: String = _pending_story
	_pending_story = ""
	if not story.is_empty():
		save_game()
	return story


func _on_story_mission_won(mission: MissionData) -> void:
	var chapter: ChapterData = campaign.find_by_mission(mission.id)
	if chapter == null or is_chapter_done(chapter.id):
		return
	_chapters_done.append(chapter.id)
	report_event(&"chapter")
	_pending_story = chapter.id
	if _chapters_done.size() >= campaign.chapters.size():
		_pending_story = chapter.id + "|epilogue"
	campaign_changed.emit()


# ---------- Снаряжение ----------

func get_gear(gear_id: String) -> GearData:
	for item: GearData in gear:
		if item.id == gear_id:
			return item
	return null


func owns_gear(gear_id: String) -> bool:
	return gear_id in _gear_owned


func buy_gear(gear_id: String) -> bool:
	var item: GearData = get_gear(gear_id)
	if item == null or owns_gear(gear_id) or coins < item.price:
		return false
	coins -= item.price
	_gear_owned.append(gear_id)
	coins_changed.emit(coins)
	gear_changed.emit()
	save_game()
	return true


# ---------- Скины ----------

func get_skin(skin_id: String) -> PlayerSkin:
	for skin: PlayerSkin in skins:
		if skin.id == skin_id:
			return skin
	return null


## Выбранный скин (или первый доступный)
func get_selected_skin() -> PlayerSkin:
	var skin: PlayerSkin = get_skin(_skin_id)
	if skin != null and owns_skin(skin.id):
		return skin
	return skins[0] if not skins.is_empty() else null


func owns_skin(skin_id: String) -> bool:
	var skin: PlayerSkin = get_skin(skin_id)
	return skin != null and (skin.price <= 0 or skin_id in _skins_owned)


func buy_skin(skin_id: String) -> bool:
	var skin: PlayerSkin = get_skin(skin_id)
	if skin == null or owns_skin(skin_id) or coins < skin.price:
		return false
	coins -= skin.price
	_skins_owned.append(skin_id)
	coins_changed.emit(coins)
	select_skin(skin_id)
	return true


func select_skin(skin_id: String) -> void:
	if not owns_skin(skin_id):
		return
	_skin_id = skin_id
	save_game()
	skin_changed.emit(get_skin(skin_id))


# ---------- Кат-сцены ----------

func has_seen_cutscene(cutscene_id: String) -> bool:
	return cutscene_id in _cutscenes_seen


func mark_cutscene_seen(cutscene_id: String) -> void:
	if cutscene_id.is_empty() or has_seen_cutscene(cutscene_id):
		return
	_cutscenes_seen.append(cutscene_id)
	save_game()


## Показать вступление и интро миссий заново
func reset_cutscenes() -> void:
	_cutscenes_seen.clear()
	save_game()


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
	if building == null or has_building(building_id) or coins < building.price \
			or shelter.level < building.required_level:
		return false
	coins -= building.price
	_buildings_owned.append(building_id)
	coins_changed.emit(coins)
	progress_changed.emit()
	shelter_changed.emit()  # уют и доход зависят от построек
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


# ---------- Автосалон ----------

func get_car(car_id: String) -> CarData:
	for car: CarData in cars:
		if car.id == car_id:
			return car
	return null


## Своя: бесплатная, купленная или полученная в сюжете (та же модель)
func owns_car(car_id: String) -> bool:
	var car: CarData = get_car(car_id)
	if car == null:
		return false
	if car.price <= 0 or car_id in _cars_owned:
		return true
	if car.model_scene != null:
		for owned: PackedScene in get_owned_cars():
			if owned != null and owned.resource_path == car.model_scene.resource_path:
				return true
	return false


func buy_car(car_id: String) -> bool:
	var car: CarData = get_car(car_id)
	if car == null or owns_car(car_id) or coins < car.price:
		return false
	coins -= car.price
	_cars_owned.append(car_id)
	_car_id = car_id
	coins_changed.emit(coins)
	cars_changed.emit()
	save_game()
	return true


func select_car(car_id: String) -> void:
	if not owns_car(car_id) or _car_id == car_id:
		return
	_car_id = car_id
	cars_changed.emit()
	save_game()


## Выбранная машина (её ставит город у старта)
func get_selected_car() -> CarData:
	var car: CarData = get_car(_car_id)
	if car != null and owns_car(car.id):
		return car
	return cars[0] if not cars.is_empty() else null


func get_car_tuning(car_id: String, stat: String) -> int:
	var levels: Variant = _car_tuning.get(car_id, {})
	return int((levels as Dictionary).get(stat, 0)) if levels is Dictionary else 0


## Цена следующего уровня тюнинга, -1 — максимум
func get_car_tuning_cost(car_id: String, stat: String) -> int:
	var car: CarData = get_car(car_id)
	var level: int = get_car_tuning(car_id, stat)
	if car == null or level >= CAR_TUNING_MAX:
		return -1
	return roundi(car.tuning_base_cost * pow(CAR_TUNING_GROWTH, level))


func tune_car(car_id: String, stat: String) -> bool:
	if not stat in CAR_TUNING or not owns_car(car_id):
		return false
	var cost: int = get_car_tuning_cost(car_id, stat)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	var levels: Dictionary = _car_tuning.get(car_id, {})
	levels[stat] = get_car_tuning(car_id, stat) + 1
	_car_tuning[car_id] = levels
	coins_changed.emit(coins)
	cars_changed.emit()
	save_game()
	return true


func get_car_paint_index(car_id: String) -> int:
	return clampi(int(_car_paint.get(car_id, 0)), 0, CAR_PAINTS.size() - 1)


## Перекраска: заводской цвет бесплатно, остальные — CAR_PAINT_PRICE
func paint_car(car_id: String, paint: int) -> bool:
	if not owns_car(car_id) or paint < 0 or paint >= CAR_PAINTS.size() or paint == get_car_paint_index(car_id):
		return false
	var cost: int = 0 if paint == 0 else CAR_PAINT_PRICE
	if coins < cost:
		return false
	coins -= cost
	_car_paint[car_id] = paint
	coins_changed.emit(coins)
	cars_changed.emit()
	save_game()
	return true


## Индекс неона или -1 (не куплен или выключен)
func get_car_neon_index(car_id: String) -> int:
	return clampi(int(_car_neon.get(car_id, -1)), -1, CAR_NEONS.size() - 1)


## Неон: первая установка — CAR_NEON_PRICE, смена цвета и выключение (-1) — бесплатно
func set_car_neon(car_id: String, neon: int) -> bool:
	if not owns_car(car_id) or neon < -1 or neon >= CAR_NEONS.size():
		return false
	if not has_car_neon_installed(car_id) and neon < 0:
		return false
	var cost: int = 0 if has_car_neon_installed(car_id) else CAR_NEON_PRICE
	if coins < cost:
		return false
	coins -= cost
	_car_neon[car_id] = neon  # -1 — куплен, но выключен
	coins_changed.emit(coins)
	cars_changed.emit()
	save_game()
	return true


func has_car_neon_installed(car_id: String) -> bool:
	return _car_neon.has(car_id)


## Всё о машине одной строкой — для сети: "id|краска|неон|двигатель|газ|управление|таран"
func get_car_net_info() -> String:
	var car: CarData = get_selected_car()
	if car == null:
		return ""
	var parts := PackedStringArray([car.id, str(get_car_paint_index(car.id)), str(get_car_neon_index(car.id))])
	for stat: String in CAR_TUNING:
		parts.append(str(get_car_tuning(car.id, stat)))
	return "|".join(parts)


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


## Событие сегодняшнего дня (одинаковое весь день); null — событий нет
func get_daily_event() -> DailyEventData:
	if quest_pool.events.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = get_today() * 7919 + 17
	return quest_pool.events[rng.randi() % quest_pool.events.size()]


# ---------- Статистика и достижения ----------

## Рекорд (не сумма): лучшая волна бесконечного режима, серия дней
func report_record(event: StringName, value: int) -> void:
	var key: String = String(event)
	if value <= int(_stats.get(key, 0)):
		return
	_stats[key] = value
	_check_achievements(event)


func get_stat(event: StringName) -> int:
	return int(_stats.get(String(event), 0))


func is_achievement_done(achievement_id: String) -> bool:
	return achievement_id in _achievements_done


func get_achievement_count() -> int:
	return _achievements_done.size()


## Проверить все достижения (вход в убежище: счётчики из старого сохранения или загруженного кода)
func check_all_achievements() -> void:
	_check_achievements(&"")


## Достижения с этим событием (пустое — все): дошли до цели — открыть, начислить награду, показать
func _check_achievements(event: StringName) -> void:
	if achievement_list == null:
		return
	for achievement: AchievementData in achievement_list.achievements:
		if achievement == null or (event != &"" and achievement.event != event) \
				or get_stat(achievement.event) < achievement.target or is_achievement_done(achievement.id):
			continue
		_achievements_done.append(achievement.id)
		coins += achievement.reward
		coins_changed.emit(coins)
		achievement_unlocked.emit(achievement)
		AchievementToast.show_achievement(get_tree(), achievement)
		save_game.call_deferred()


# ---------- Событие недели ----------

## Номер недели (с понедельника)
func get_week() -> int:
	return floori((get_today() + 3) / 7.0)


## Сколько дней до смены события недели
func get_week_days_left() -> int:
	return 7 - posmod(get_today() + 3, 7)


func get_weekly_event() -> WeeklyEventData:
	if weekly_events == null or weekly_events.events.is_empty():
		return null
	return weekly_events.events[posmod(get_week(), weekly_events.events.size())]


func get_weekly_progress() -> int:
	_ensure_week()
	return int(_weekly.get("progress", 0))


func is_weekly_claimed() -> bool:
	_ensure_week()
	return bool(_weekly.get("claimed", false))


func can_claim_weekly() -> bool:
	var event: WeeklyEventData = get_weekly_event()
	return event != null and not is_weekly_claimed() and get_weekly_progress() >= event.challenge_target


## Забрать награду недельного испытания; возвращает монеты (0 — нельзя)
func claim_weekly() -> int:
	if not can_claim_weekly():
		return 0
	var reward: int = get_weekly_event().challenge_reward
	_weekly["claimed"] = true
	coins += reward
	coins_changed.emit(coins)
	report_event(&"weekly_done")
	progress_changed.emit()
	save_game()
	return reward


func _ensure_week() -> void:
	if int(_weekly.get("week", -1)) != get_week():
		_weekly = {"week": get_week(), "progress": 0, "claimed": false}


func _report_weekly(event: StringName, amount: int) -> void:
	var weekly: WeeklyEventData = get_weekly_event()
	if weekly == null or weekly.challenge_event != event:
		return
	_ensure_week()
	if bool(_weekly.get("claimed", false)):
		return
	_weekly["progress"] = mini(int(_weekly.get("progress", 0)) + amount, weekly.challenge_target)


# ---------- Код сохранения (перенос прогресса) ----------

## Весь прогресс одной строкой (сжатый JSON сохранения) — скопировать на другое устройство
func export_save_code() -> String:
	save_game()
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return ""
	var packed: PackedByteArray = text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return "%s-%s-%s" % [SAVE_CODE_PREFIX, text.md5_text().substr(0, 8), Marshalls.raw_to_base64(packed)]


## Загрузить прогресс из кода. false — код повреждён или не от этой игры (текущий прогресс не трогается)
func import_save_code(code: String) -> bool:
	var parts: PackedStringArray = code.strip_edges().split("-", false, 2)
	if parts.size() != 3 or parts[0] != SAVE_CODE_PREFIX:
		return false
	var packed: PackedByteArray = Marshalls.base64_to_raw(parts[2])
	if packed.is_empty():
		return false
	var raw: PackedByteArray = packed.decompress_dynamic(SAVE_CODE_MAX_SIZE, FileAccess.COMPRESSION_GZIP)
	var text: String = raw.get_string_from_utf8()
	if text.is_empty() or text.md5_text().substr(0, 8) != parts[1]:
		return false
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not (data as Dictionary).has("coins"):
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: не удалось записать сохранение из кода")
		return false
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),
			ProjectSettings.globalize_path(SAVE_PATH)) != OK:
		return false
	load_game()
	coins_changed.emit(coins)
	weapons_changed.emit()
	progress_changed.emit()
	inventory_changed.emit()
	gear_changed.emit()
	campaign_changed.emit()
	cars_changed.emit()
	skin_changed.emit(get_selected_skin())
	shelter_changed.emit()
	return true


## Возвращает выданные монеты (0 — сегодня уже получено)
func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	var reward: int = get_daily_reward()
	_daily_streak = get_next_streak()
	_daily_last_day = get_today()
	report_record(&"daily_streak", _daily_streak)
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
	if amount <= 0:
		return
	var key: String = String(event)
	_stats[key] = int(_stats.get(key, 0)) + amount
	_report_weekly(event, amount)
	_check_achievements(event)
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
	if can_claim_daily() or can_claim_weekly():
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


# ---------- Набег на убежище ----------

func is_raid_ready() -> bool:
	if _mission_clears.is_empty():
		return false  # сначала хоть одна победа
	var now: int = int(Time.get_unix_time_from_system())
	if _next_raid <= 0 or _next_raid > now + RAID_INTERVAL:
		# Не назначен или часы телефона перевели назад
		_next_raid = now + RAID_FIRST_DELAY
		save_game()
		return false
	return now >= _next_raid


func get_raid_mission() -> MissionData:
	if not ResourceLoader.exists(RAID_MISSION_PATH):
		push_warning("GameState: нет миссии набега %s" % RAID_MISSION_PATH)
		return null
	return load(RAID_MISSION_PATH) as MissionData


## Принять набег: набор ловушек в сумку, следующий — через RAID_INTERVAL, в бой
func start_raid() -> void:
	var mission: MissionData = get_raid_mission()
	if mission == null or not is_raid_ready():
		return
	for item_id: String in RAID_KIT:
		add_item(item_id, int(RAID_KIT[item_id]))
	# Сторожевая вышка: ещё турель и мины
	if has_building("watchtower"):
		for item_id: Variant in shelter.config.tower_raid_kit:
			add_item(str(item_id), int(shelter.config.tower_raid_kit[item_id]))
	_next_raid = int(Time.get_unix_time_from_system()) + RAID_INTERVAL
	raid_active = true
	save_game()
	start_mission(mission)


func is_raid_mission(mission: MissionData) -> bool:
	return raid_active and mission != null and mission.id == "shelter"


func end_raid() -> void:
	raid_active = false


## Обучение — миссия на полигоне (MissionData.tutorial)
const TUTORIAL_PATH: String = "res://missions/data/mission_tutorial.tres"


func start_tutorial() -> void:
	var tutorial := load(TUTORIAL_PATH) as MissionData if ResourceLoader.exists(TUTORIAL_PATH) else null
	if tutorial == null:
		push_warning("GameState: нет миссии обучения %s" % TUTORIAL_PATH)
		return
	start_mission(tutorial)


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
	_cars_owned.clear()
	_car_id = ""
	_car_tuning.clear()
	_car_paint.clear()
	_car_neon.clear()
	_skins_owned.clear()
	_skin_id = ""
	_gear_owned.clear()
	_chapters_done.clear()
	_pending_story = ""
	_next_raid = 0
	raid_active = false
	_attachments_owned.clear()
	_attachments_on.clear()
	_race_best.clear()
	_stats.clear()
	_achievements_done.clear()
	_weekly = {}
	shelter.reset()
	_grant_free_weapons()
	coins_changed.emit(coins)
	weapons_changed.emit()
	# Открытые окна и HUD обновляются сразу
	progress_changed.emit()
	inventory_changed.emit()
	gear_changed.emit()
	campaign_changed.emit()
	cars_changed.emit()
	skin_changed.emit(get_selected_skin())
	shelter_changed.emit()
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
		"cars_owned": _cars_owned,
		"car": _car_id,
		"car_tuning": _car_tuning,
		"car_paint": _car_paint,
		"car_neon": _car_neon,
		"cutscenes_seen": _cutscenes_seen,
		"skins_owned": _skins_owned,
		"gear": _gear_owned,
		"chapters_done": _chapters_done,
		"pending_story": _pending_story,
		"skin": _skin_id,
		"next_raid": _next_raid,
		"attachments": _attachments_owned,
		"attachments_on": _attachments_on,
		"race_best": _race_best,
		"stats": _stats,
		"achievements": _achievements_done,
		"weekly": _weekly,
		"shelter": shelter.to_dict(),
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

	_chapters_done.clear()
	var stored_chapters: Variant = data.get("chapters_done", [])
	if stored_chapters is Array:
		for chapter_id: Variant in stored_chapters:
			if campaign.find(str(chapter_id)) != null and not str(chapter_id) in _chapters_done:
				_chapters_done.append(str(chapter_id))
	_pending_story = str(data.get("pending_story", ""))

	_gear_owned.clear()
	var stored_gear: Variant = data.get("gear", [])
	if stored_gear is Array:
		for gear_id: Variant in stored_gear:
			if get_gear(str(gear_id)) != null and not str(gear_id) in _gear_owned:
				_gear_owned.append(str(gear_id))

	_skins_owned.clear()
	var stored_skins: Variant = data.get("skins_owned", [])
	if stored_skins is Array:
		for skin_id: Variant in stored_skins:
			if get_skin(str(skin_id)) != null and not str(skin_id) in _skins_owned:
				_skins_owned.append(str(skin_id))
	_skin_id = str(data.get("skin", ""))
	_next_raid = maxi(int(data.get("next_raid", 0)), 0)
	_attachments_owned = _load_attachments(data.get("attachments", {}), false)
	_attachments_on = _load_attachments(data.get("attachments_on", {}), true)
	_stats = _load_int_dictionary(data.get("stats", {}), 0, 2000000000)
	_achievements_done.clear()
	var stored_achievements: Variant = data.get("achievements", [])
	if stored_achievements is Array:
		for achievement_id: Variant in stored_achievements:
			if not str(achievement_id) in _achievements_done:
				_achievements_done.append(str(achievement_id))
	_weekly = {}
	var stored_weekly: Variant = data.get("weekly", {})
	if stored_weekly is Dictionary:
		_weekly = {"week": int((stored_weekly as Dictionary).get("week", -1)),
			"progress": maxi(int((stored_weekly as Dictionary).get("progress", 0)), 0),
			"claimed": bool((stored_weekly as Dictionary).get("claimed", false))}
	_race_best.clear()
	var stored_races: Variant = data.get("race_best", {})
	if stored_races is Dictionary:
		for route_id: Variant in stored_races:
			var seconds: float = float((stored_races as Dictionary)[route_id])
			if seconds > 0.0:
				_race_best[str(route_id)] = seconds

	_cutscenes_seen.clear()
	var seen: Variant = data.get("cutscenes_seen", [])
	if seen is Array:
		for cutscene_id: Variant in seen:
			_cutscenes_seen.append(str(cutscene_id))

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

	_load_cars(data)

	_inventory.clear()
	var stored: Dictionary = _load_int_dictionary(data.get("inventory", {}), 0, 99)
	for item_id: String in stored:
		var item: ItemData = get_item(item_id)
		if item != null:
			_inventory[item_id] = mini(int(stored[item_id]), item.max_stack)
	shelter.from_dict(data.get("shelter", {}))
	# Старое сохранение без статистики: счётчики по уже сделанному (достижения откроются при следующем событии)
	if not data.has("stats"):
		var wins: int = 0
		for mission_id: Variant in _mission_clears:
			wins += int(_mission_clears[mission_id])
		_stats["mission_win"] = wins
		_stats["chapter"] = _chapters_done.size()
		_stats["daily_streak"] = _daily_streak


## Машины автосалона из сохранения (неизвестные id отбрасываются)
func _load_cars(data: Dictionary) -> void:
	_cars_owned.clear()
	var stored_owned: Variant = data.get("cars_owned", [])
	if stored_owned is Array:
		for entry: Variant in stored_owned:
			var key: String = str(entry)
			if get_car(key) != null and not key in _cars_owned:
				_cars_owned.append(key)
	_car_id = str(data.get("car", ""))
	_car_tuning.clear()
	var stored_tuning: Variant = data.get("car_tuning", {})
	if stored_tuning is Dictionary:
		for car_id: Variant in stored_tuning:
			if get_car(str(car_id)) == null:
				continue
			var levels: Dictionary = _load_int_dictionary((stored_tuning as Dictionary)[car_id], 0, CAR_TUNING_MAX)
			var clean: Dictionary = {}
			for stat: String in CAR_TUNING:
				if levels.has(stat):
					clean[stat] = levels[stat]
			_car_tuning[str(car_id)] = clean
	_car_paint.clear()
	var paints: Dictionary = _load_int_dictionary(data.get("car_paint", {}), 0, CAR_PAINTS.size() - 1)
	for car_id: String in paints:
		if get_car(car_id) != null:
			_car_paint[car_id] = paints[car_id]
	_car_neon.clear()
	var neons: Dictionary = _load_int_dictionary(data.get("car_neon", {}), -1, CAR_NEONS.size() - 1)
	for car_id: String in neons:
		if get_car(car_id) != null:
			_car_neon[car_id] = neons[car_id]


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
