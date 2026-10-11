class_name ShelterConfig
extends Resource
## Параметры развития убежища: уровни (расширение двора, места для людей, касса лагеря),
## провизия и настроение жильцов, доход лагеря, новые жильцы по радио. Логика — ShelterState.

@export_group("Уровни")
## Названия уровней (1-й — стартовый)
@export var level_titles: PackedStringArray = ["ЛАГЕРЬ", "ДВОР", "ФОРТ", "БАЗА", "КРЕПОСТЬ"]
## Что даёт уровень (для окна БАЗА)
@export var level_descriptions: PackedStringArray = []
## Цена перехода на уровень (монеты; 1-й — бесплатно)
@export var level_prices: PackedInt32Array = [0, 1500, 3500, 7000, 12000]
## Лом на стройку уровня
@export var level_scrap: PackedInt32Array = [0, 3, 6, 10, 15]
## Полуразмер двора (стены Room/Bounds), м
@export var level_half_sizes: PackedFloat32Array = [16.0, 20.0, 20.0, 22.8, 22.8]
## Мест для жильцов: больше — тесно (настроение ниже)
@export var level_capacity: PackedInt32Array = [10, 20, 35, 55, 90]
## Сколько часов копится касса лагеря
@export var level_income_hours: PackedFloat32Array = [4.0, 6.0, 8.0, 10.0, 12.0]

@export_group("Провизия")
## Один ящик провизии кормит столько людей (со столовой — canteen_people_per_crate)
@export var people_per_crate: int = 5
@export var canteen_people_per_crate: int = 8
## Наборы провизии в окне БАЗА: ящики и цена
@export var food_pack_crates: PackedInt32Array = [5, 15, 40]
@export var food_pack_prices: PackedInt32Array = [100, 270, 650]
## Победа в миссии: ящиков = food_per_win + звёзды
@export var food_per_win: int = 1
## Огород: ящиков в день
@export var garden_food_per_day: int = 4
@export var max_food: int = 300
## Провизия у нового игрока
@export var start_food: int = 5

@export_group("Настроение")
@export var morale_start: float = 60.0
## Обед: +настроение (не выше максимума)
@export var morale_meal: float = 25.0
## День без обеда: −настроение
@export var morale_hungry_day: float = 20.0
## Потолок настроения без обустройства; уют (comfort построек и обустройства) поднимает его до 100
@export var morale_base_max: float = 50.0
## Тесно (людей больше мест): потолок ниже на столько
@export var crowding_penalty: float = 20.0
## Высокое настроение — бонус к монетам за миссии
@export var morale_reward_threshold: float = 75.0
@export var morale_reward_bonus: float = 0.1

@export_group("Касса лагеря")
## Монет в час: (база + люди × за человека) × настроение (от 30% до 100%) × генератор
@export var income_base: float = 15.0
@export var income_per_person: float = 1.5
@export var income_min_factor: float = 0.3
@export var generator_bonus: float = 0.25

@export_group("Новые жильцы (радио)")
@export var recruit_price: int = 200
@export var recruit_food: int = 3
@export var recruits_per_day: int = 3

@export_group("Вышка")
## Набег на убежище с вышкой: дополнительно в сумку
@export var tower_raid_kit: Dictionary = {"turret": 1, "land_mine": 2}


func get_level_count() -> int:
	return level_titles.size()


func get_title(level: int) -> String:
	return level_titles[clampi(level - 1, 0, level_titles.size() - 1)] if not level_titles.is_empty() else ""


func get_description(level: int) -> String:
	var index: int = level - 1
	return level_descriptions[index] if index >= 0 and index < level_descriptions.size() else ""


func _pick_int(values: PackedInt32Array, level: int, fallback: int) -> int:
	return values[clampi(level - 1, 0, values.size() - 1)] if not values.is_empty() else fallback


func _pick_float(values: PackedFloat32Array, level: int, fallback: float) -> float:
	return values[clampi(level - 1, 0, values.size() - 1)] if not values.is_empty() else fallback


func get_price(level: int) -> int:
	return _pick_int(level_prices, level, 0)


func get_scrap(level: int) -> int:
	return _pick_int(level_scrap, level, 0)


func get_half_size(level: int) -> float:
	return _pick_float(level_half_sizes, level, 16.0)


func get_capacity(level: int) -> int:
	return _pick_int(level_capacity, level, 10)


func get_income_hours(level: int) -> float:
	return _pick_float(level_income_hours, level, 4.0)
