class_name ShelterState
extends RefCounted
## Развитие убежища (часть GameState, сохраняется в ключе "shelter"): уровень и расширение двора,
## провизия и обед лагеря раз в день, настроение жильцов, касса лагеря (монеты копятся по часам),
## новые жильцы по радио, обустройство (DecorData). Параметры — base/shelter_config.tres.
## Изменения: GameState.shelter_changed, монеты — через GameState.

const CONFIG_PATH: String = "res://base/shelter_config.tres"
const DECOR_PATH: String = "res://base/decor_list.tres"
## Минимум людей в лагере (с самого начала у костра двое)
const MIN_POPULATION: int = 2
## За сколько пропущенных дней максимум штраф (долго не заходил — не обнулять всё)
const MAX_MISSED_DAYS: int = 7
const SECONDS_PER_HOUR: float = 3600.0

var config: ShelterConfig
var decor_list: DecorList

var level: int = 1
var food: int = 0
var morale: float = 60.0
var recruited: int = 0
var decor_owned: Array[String] = []
var last_meal_day: int = -1
## Последний учтённый день (голод и огород)
var day: int = -1
## Касса: накоплено до income_time (монеты, дробные) и с какого времени копится дальше
var income_bank: float = 0.0
var income_time: int = 0
var recruit_day: int = -1
var recruits_today: int = 0


func _init() -> void:
	config = load(CONFIG_PATH) as ShelterConfig if ResourceLoader.exists(CONFIG_PATH) else null
	if config == null:
		push_warning("ShelterState: нет %s, параметры по умолчанию" % CONFIG_PATH)
		config = ShelterConfig.new()
	decor_list = load(DECOR_PATH) as DecorList if ResourceLoader.exists(DECOR_PATH) else null
	if decor_list == null:
		push_warning("ShelterState: нет %s, обустройства не будет" % DECOR_PATH)
		decor_list = DecorList.new()
	reset()


func reset() -> void:
	level = 1
	food = config.start_food
	morale = config.morale_start
	recruited = 0
	decor_owned.clear()
	last_meal_day = -1
	day = -1
	income_bank = 0.0
	income_time = 0
	recruit_day = -1
	recruits_today = 0


# ---------- Время: голод, огород ----------

static func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Учесть прошедшие дни: день без обеда — настроение ниже; огород приносит провизию
func tick() -> void:
	var today: int = GameState.get_today()
	if income_time <= 0 or income_time > _now():
		income_time = _now()  # первый запуск или часы перевели назад
	if day < 0 or day > today:
		day = today
		return
	if today == day:
		return
	_bank_income()
	var days: int = mini(today - day, MAX_MISSED_DAYS)
	for i in days:
		var ended: int = today - days + i  # закончившийся день
		if last_meal_day != ended and ended >= day:
			morale -= config.morale_hungry_day
		if GameState.has_building("garden"):
			food += config.garden_food_per_day
	morale = clampf(morale, 0.0, get_max_morale())
	food = mini(food, config.max_food)
	day = today
	GameState.save_game()
	GameState.shelter_changed.emit()


# ---------- Люди ----------

## Спасённые в сюжете (не меньше первых двоих) + позванные по радио
func get_population() -> int:
	return maxi(GameState.get_rescued_count(), MIN_POPULATION) + recruited


func get_capacity() -> int:
	return config.get_capacity(level)


func is_crowded() -> bool:
	return get_population() > get_capacity()


func can_recruit() -> bool:
	return get_recruit_block().is_empty()


## Почему нельзя позвать выжившего ("" — можно)
func get_recruit_block() -> String:
	if not GameState.has_building("radio"):
		return "НУЖНА РАДИОСТАНЦИЯ"
	if get_population() >= get_capacity():
		return "НЕТ МЕСТ — РАСШИРЬ УБЕЖИЩЕ"
	if _recruits_left() <= 0:
		return "НА СЕГОДНЯ ЭФИР ЗАКОНЧЕН"
	if food < config.recruit_food:
		return "МАЛО ПРОВИЗИИ"
	if GameState.coins < config.recruit_price:
		return "МАЛО МОНЕТ"
	return ""


func _recruits_left() -> int:
	return config.recruits_per_day - (recruits_today if recruit_day == GameState.get_today() else 0)


func get_recruits_left() -> int:
	return maxi(_recruits_left(), 0)


func recruit() -> bool:
	tick()
	if not can_recruit():
		return false
	_bank_income()
	var today: int = GameState.get_today()
	if recruit_day != today:
		recruit_day = today
		recruits_today = 0
	recruits_today += 1
	recruited += 1
	food -= config.recruit_food
	morale = minf(morale, get_max_morale())
	GameState.spend_coins(config.recruit_price)
	GameState.report_event(&"camp_recruit")
	_changed()
	return true


# ---------- Провизия и настроение ----------

func get_meal_cost() -> int:
	var per_crate: int = config.canteen_people_per_crate if GameState.has_building("canteen") \
		else config.people_per_crate
	return ceili(float(get_population()) / float(maxi(per_crate, 1)))


func is_fed_today() -> bool:
	return last_meal_day == GameState.get_today()


func can_feed() -> bool:
	return not is_fed_today() and food >= get_meal_cost()


## Обед лагеря (раз в день): провизия −, настроение +
func feed() -> bool:
	tick()
	if not can_feed():
		return false
	_bank_income()
	food -= get_meal_cost()
	last_meal_day = GameState.get_today()
	morale = minf(morale + config.morale_meal, get_max_morale())
	GameState.report_event(&"camp_meal")
	_changed()
	return true


func buy_food(pack: int) -> bool:
	if pack < 0 or pack >= config.food_pack_crates.size() or pack >= config.food_pack_prices.size():
		return false
	var price: int = config.food_pack_prices[pack]
	if GameState.coins < price or food >= config.max_food:
		return false
	food = mini(food + config.food_pack_crates[pack], config.max_food)
	GameState.spend_coins(price)
	_changed()
	return true


## Провизия за победу (MissionManager): ящиков = food_per_win + звёзды
func add_mission_food(stars: int) -> int:
	var amount: int = config.food_per_win + clampi(stars, 0, 3)
	var before: int = food
	food = mini(food + amount, config.max_food)
	if food != before:
		GameState.shelter_changed.emit()
	return food - before


func get_comfort() -> int:
	var total: int = 0
	for item: DecorData in decor_list.decor:
		if item != null and owns_decor(item.id):
			total += item.comfort
	for building: BuildingData in GameState.buildings:
		if GameState.has_building(building.id):
			total += building.comfort
	return total


func get_max_morale() -> float:
	var top: float = config.morale_base_max + float(get_comfort())
	if is_crowded():
		top -= config.crowding_penalty
	return clampf(top, 20.0, 100.0)


func get_morale() -> float:
	return clampf(morale, 0.0, get_max_morale())


## Бонус к монетам за миссии при высоком настроении (множитель ≥ 1)
func get_reward_bonus() -> float:
	return 1.0 + config.morale_reward_bonus if get_morale() >= config.morale_reward_threshold else 1.0


## Настроение словами (для окна и таблички)
func get_mood_text() -> String:
	var value: float = get_morale()
	if value >= 80.0:
		return "СЧАСТЛИВЫ"
	if value >= 60.0:
		return "ДОВОЛЬНЫ"
	if value >= 40.0:
		return "СПОКОЙНЫ"
	if value >= 20.0:
		return "ГРУСТЯТ"
	return "ГОЛОДАЮТ"


func get_mood_color() -> Color:
	var value: float = get_morale() / 100.0
	return Color(1.0, 0.35, 0.3).lerp(Color(0.5, 1.0, 0.45), clampf(value, 0.0, 1.0))


# ---------- Касса лагеря ----------

## Монет в час сейчас
func get_income_rate() -> float:
	var factor: float = lerpf(config.income_min_factor, 1.0, get_morale() / 100.0)
	var bonus: float = 1.0 + (config.generator_bonus if GameState.has_building("generator") else 0.0)
	return (config.income_base + config.income_per_person * get_population()) * factor * bonus


func get_income_cap() -> float:
	return get_income_rate() * config.get_income_hours(level)


func get_pending_income() -> float:
	var hours: float = maxf(float(_now() - income_time), 0.0) / SECONDS_PER_HOUR
	return minf(income_bank + get_income_rate() * hours, get_income_cap())


## Перед сменой скорости дохода — зафиксировать накопленное по старой скорости
func _bank_income() -> void:
	if income_time > 0:
		income_bank = get_pending_income()
	income_time = _now()


## Забрать кассу: монеты игроку
func collect_income() -> int:
	tick()
	var amount: int = floori(get_pending_income())
	if amount <= 0:
		return 0
	income_bank = 0.0
	income_time = _now()
	GameState.add_coins(amount)
	GameState.report_event(&"camp_income", amount)
	_changed()
	return amount


# ---------- Уровень ----------

func is_max_level() -> bool:
	return level >= config.get_level_count()


func get_half_size() -> float:
	return config.get_half_size(level)


func get_next_price() -> int:
	return config.get_price(level + 1)


func get_next_scrap() -> int:
	return config.get_scrap(level + 1)


func can_upgrade() -> bool:
	return not is_max_level() and GameState.coins >= get_next_price() \
		and GameState.get_item_count(GameState.SCRAP_ID) >= get_next_scrap()


func upgrade() -> bool:
	if not can_upgrade():
		return false
	_bank_income()
	var scrap: int = get_next_scrap()
	if scrap > 0 and not GameState.remove_item(GameState.SCRAP_ID, scrap):
		return false
	GameState.spend_coins(get_next_price())
	level += 1
	GameState.report_record(&"shelter_level", level)
	_changed()
	return true


# ---------- Обустройство ----------

func owns_decor(decor_id: String) -> bool:
	return decor_id in decor_owned


func get_decor(decor_id: String) -> DecorData:
	return decor_list.find(decor_id)


func buy_decor(decor_id: String) -> bool:
	var item: DecorData = get_decor(decor_id)
	if item == null or owns_decor(decor_id) or level < item.required_level or GameState.coins < item.price:
		return false
	_bank_income()
	decor_owned.append(decor_id)
	GameState.spend_coins(item.price)
	GameState.report_event(&"decor_buy")
	_changed()
	return true


## Есть что сделать в убежище (подсветка плитки БАЗА)
func needs_attention() -> bool:
	return can_feed() or (get_pending_income() >= get_income_cap() * 0.5 and get_pending_income() >= 1.0)


func _changed() -> void:
	GameState.save_game()
	GameState.shelter_changed.emit()


# ---------- Сохранение ----------

func to_dict() -> Dictionary:
	return {
		"level": level,
		"food": food,
		"morale": morale,
		"recruited": recruited,
		"decor": decor_owned,
		"last_meal_day": last_meal_day,
		"day": day,
		"income_bank": income_bank,
		"income_time": income_time,
		"recruit_day": recruit_day,
		"recruits_today": recruits_today,
	}


func from_dict(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var source: Dictionary = data
	level = clampi(int(source.get("level", 1)), 1, maxi(config.get_level_count(), 1))
	food = clampi(int(source.get("food", config.start_food)), 0, config.max_food)
	morale = clampf(float(source.get("morale", config.morale_start)), 0.0, 100.0)
	recruited = maxi(int(source.get("recruited", 0)), 0)
	var decor: Variant = source.get("decor", [])
	if decor is Array:
		for decor_id: Variant in decor:
			if get_decor(str(decor_id)) != null and not owns_decor(str(decor_id)):
				decor_owned.append(str(decor_id))
	last_meal_day = int(source.get("last_meal_day", -1))
	day = int(source.get("day", -1))
	income_bank = maxf(float(source.get("income_bank", 0.0)), 0.0)
	income_time = maxi(int(source.get("income_time", 0)), 0)
	recruit_day = int(source.get("recruit_day", -1))
	recruits_today = maxi(int(source.get("recruits_today", 0)), 0)
