class_name CarData
extends Resource
## Машина автосалона: класс (D — простая, C, B, A — лучшая), цена, модель и ходовые качества.
## Тюнинг (двигатель, газ, управление, таран), покраска и неон — в GameState по id машины.

const CLASSES: PackedStringArray = ["D", "C", "B", "A"]
const CLASS_COLORS: Array[Color] = [Color(0.7, 0.72, 0.75), Color(0.45, 0.85, 0.4), Color(0.4, 0.7, 1.0),
	Color(1.0, 0.72, 0.2)]

@export var id: String = ""
@export var title: String = ""
## 0 — D, 1 — C, 2 — B, 3 — A
@export_enum("D", "C", "B", "A") var car_class: int = 0
@export_multiline var description: String = ""
@export var price: int = 0
@export var model_scene: PackedScene
@export var model_scale: float = 1.0

@export_group("Driving")
## Максимальная скорость, м/с (20 м/с = 72 км/ч)
@export var max_speed: float = 20.0
@export var max_reverse_speed: float = 7.0
@export var acceleration: float = 9.0
@export var brake_power: float = 22.0
@export var steer_rate: float = 1.9
## Сцепление шин: как быстро гасится занос (больше — «на рельсах»)
@export var grip: float = 8.0
## Сцепление на ручнике и в резком повороте на скорости (меньше — длиннее дрифт)
@export var drift_grip: float = 2.0
## Урон сбитому зомби = скорость (м/с) × множитель
@export var run_over_damage_factor: float = 14.0
## Прочность кузова: столько урона от зомби выдержит до поломки
@export var durability: float = 300.0

@export_group("Tuning")
## Цена первого уровня тюнинга; дальше растёт в GameState.CAR_TUNING_GROWTH раз за уровень
@export var tuning_base_cost: int = 120


func get_class_letter() -> String:
	return CLASSES[clampi(car_class, 0, CLASSES.size() - 1)]


func get_class_color() -> Color:
	return CLASS_COLORS[clampi(car_class, 0, CLASS_COLORS.size() - 1)]


## Характеристика для полосок в автосалоне, 0..1
func get_rating(stat: String) -> float:
	match stat:
		"speed":
			return clampf(max_speed / 34.0, 0.0, 1.0)
		"acceleration":
			return clampf(acceleration / 16.0, 0.0, 1.0)
		"handling":
			return clampf(steer_rate / 2.6, 0.0, 1.0)
		"ram":
			return clampf(run_over_damage_factor / 30.0, 0.0, 1.0)
	return 0.0
