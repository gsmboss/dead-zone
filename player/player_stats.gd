class_name PlayerStats
extends Resource
## Базовые параметры игрока и улучшения «Выжившего» в оружейной.

@export var base_health: float = 100.0
@export_range(1, 10) var max_level: int = 5

@export_group("Health")
## +доля здоровья за уровень
@export_range(0.0, 1.0, 0.01) var health_per_level: float = 0.2
@export var health_cost_base: int = 150
@export_range(1.0, 3.0, 0.05) var health_cost_growth: float = 1.6

@export_group("Armor")
## Доля поглощаемого урона за уровень
@export_range(0.0, 0.2, 0.01) var armor_per_level: float = 0.06
@export var armor_cost_base: int = 200
@export_range(1.0, 3.0, 0.05) var armor_cost_growth: float = 1.7


## Цена следующего уровня; -1 — уровень максимальный
func get_cost(stat: String, level: int) -> int:
	if level >= max_level:
		return -1
	match stat:
		"health":
			return roundi(health_cost_base * pow(health_cost_growth, level))
		"armor":
			return roundi(armor_cost_base * pow(armor_cost_growth, level))
	return -1


func get_max_health(level: int) -> float:
	return base_health * (1.0 + health_per_level * clampi(level, 0, max_level))


func get_armor(level: int) -> float:
	return clampf(armor_per_level * clampi(level, 0, max_level), 0.0, 0.9)
