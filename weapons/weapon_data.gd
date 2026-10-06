class_name WeaponData
extends Resource
## Параметры оружия. Каждый ствол — отдельный .tres файл.

@export var display_name: String = "WEAPON"

@export_group("Damage")
@export var damage: float = 20.0
## Количество дробин за выстрел (1 = обычная пуля)
@export_range(1, 20) var pellets: int = 1
@export var max_range: float = 60.0
@export_range(0.0, 15.0, 0.1) var spread_degrees: float = 1.0

@export_group("Fire")
## Выстрелов (ударов) в секунду
@export_range(0.5, 20.0, 0.1) var fire_rate: float = 4.0

@export_group("Flamethrower")
## Огнемёт: урон всем зомби в конусе на max_range каждый «выстрел», струя пламени
@export var is_flamethrower: bool = false
@export_range(5.0, 60.0, 1.0) var flame_cone_degrees: float = 20.0

@export_group("Melee")
## Оружие ближнего боя: без патронов, удар на max_range веером лучей
@export var is_melee: bool = false
## Ширина веера удара, градусы (лучи: центр и края)
@export_range(0.0, 60.0, 1.0) var melee_arc_degrees: float = 30.0
## Поворот модели при замахе, градусы
@export var swing_rotation_degrees: Vector3 = Vector3(-55.0, 0.0, 25.0)

@export_group("Ammo")
@export_range(1, 200) var magazine_size: int = 12
## Максимальный запас патронов. -1 = бесконечный
@export var max_reserve_ammo: int = -1
@export_range(0.1, 5.0, 0.05) var reload_time: float = 1.2

@export_group("Aim")
## Приближение при прицеливании: FOV × множитель (меньше — сильнее зум)
@export_range(0.1, 1.0, 0.05) var ads_fov_multiplier: float = 0.75
## Разброс при прицеливании × множитель
@export_range(0.0, 1.0, 0.05) var ads_spread_multiplier: float = 0.35
## Расхождение прицела за выстрел (доля от spread_degrees) и максимум
@export_range(0.0, 2.0, 0.05) var bloom_per_shot: float = 0.35
@export_range(0.0, 5.0, 0.1) var max_bloom_factor: float = 2.0
## Оптический прицел (снайперская): в прицеле — круг оптики на весь экран, модель оружия скрыта
@export var has_scope: bool = false

@export_group("Recoil")
## Подброс камеры вверх за выстрел, градусы
@export var recoil_pitch: float = 1.5
## Максимальный случайный сдвиг вбок, градусы
@export var recoil_yaw: float = 0.4
## Откат модели оружия назад, метры
@export var gun_kick: float = 0.05

@export_group("Audio")
@export var fire_sound: AudioStream
## Звук перезарядки (обрывается, если перезарядка закончилась раньше)
@export var reload_sound: AudioStream
## Звук в конце перезарядки (например, передёргивание дробовика)
@export var reload_end_sound: AudioStream
## Затвор после каждого выстрела (болтовая винтовка): звучит через bolt_delay секунд
@export var bolt_sound: AudioStream
@export_range(0.0, 2.0, 0.05) var bolt_delay: float = 0.35
@export_range(-30.0, 10.0, 0.5) var fire_volume_db: float = -4.0
@export_range(0.5, 2.0, 0.05) var fire_pitch: float = 1.0

@export_group("View Model")
## Модель оружия в руках (.gltf / .tscn). Пусто → серый брусок Gun
@export var view_model: PackedScene
## Положение модели относительно камеры
@export var model_position: Vector3 = Vector3(0.18, -0.2, -0.45)
@export var model_rotation_degrees: Vector3 = Vector3.ZERO
@export_range(0.01, 10.0, 0.01) var model_scale: float = 1.0
## Срез ствола в локальных координатах модели (для вспышки)
@export var muzzle_position: Vector3 = Vector3(0.0, 0.05, -0.3)

@export_group("Shop")
## Уникальный id для сохранений, латиницей: pistol, shotgun, rifle
@export var id: String = ""
## Цена покупки. 0 = выдаётся бесплатно с начала игры
@export var price: int = 0
@export_range(0, 10) var max_upgrade_level: int = 5
## Цена первого уровня улучшения и множитель роста цены за уровень
@export var upgrade_base_cost: int = 100
@export_range(1.0, 3.0, 0.05) var upgrade_cost_growth: float = 1.6
## Прирост за уровень: урон +%, магазин +%, время перезарядки −%
@export_range(0.0, 1.0, 0.01) var damage_per_level: float = 0.15
@export_range(0.0, 1.0, 0.01) var magazine_per_level: float = 0.2
@export_range(0.0, 0.2, 0.01) var reload_per_level: float = 0.08


func get_fire_interval() -> float:
	return 1.0 / maxf(fire_rate, 0.01)


func has_infinite_reserve() -> bool:
	return is_melee or max_reserve_ammo < 0


## Какие улучшения доступны в оружейной (у ближнего боя только урон)
func get_upgrade_stats() -> Array[String]:
	if is_melee:
		return ["damage"]
	return ["damage", "magazine", "reload"]


## Цена следующего уровня; -1, если уровень максимальный
func get_upgrade_cost(current_level: int) -> int:
	if current_level >= max_upgrade_level:
		return -1
	return roundi(upgrade_base_cost * pow(upgrade_cost_growth, current_level))


## Копия оружия с применёнными улучшениями. levels: {"damage": 2, "magazine": 1, ...}
func make_upgraded(levels: Dictionary) -> WeaponData:
	var copy := duplicate() as WeaponData
	var damage_level: int = clampi(int(levels.get("damage", 0)), 0, max_upgrade_level)
	var magazine_level: int = clampi(int(levels.get("magazine", 0)), 0, max_upgrade_level)
	var reload_level: int = clampi(int(levels.get("reload", 0)), 0, max_upgrade_level)

	copy.damage = damage * (1.0 + damage_per_level * damage_level)
	copy.magazine_size = maxi(1, roundi(magazine_size * (1.0 + magazine_per_level * magazine_level)))
	copy.reload_time = maxf(0.2, reload_time * (1.0 - reload_per_level * reload_level))
	return copy
