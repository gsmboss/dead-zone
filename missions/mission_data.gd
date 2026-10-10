class_name MissionData
extends Resource
## Описание миссии. Каждая миссия — отдельный .tres файл.

## DEFEND — удерживать точку (DefendPoint), COLLECT — собрать ящики (ItemSpawnPoint),
## ENDLESS — волны без конца (рекорд — волна), FREE_ROAM — свободная игра в городе без цели
enum Type { WAVES, KILL_COUNT, SURVIVE, DEFEND, COLLECT, ENDLESS, FREE_ROAM }

## Уникальный id для сохранений, латиницей: waves, kill, survive
@export var id: String = ""
@export var title: String = "ЗАЧИСТКА"
@export_multiline var description: String = ""
@export var type: Type = Type.WAVES
## Сцена уровня, где проходит миссия
@export_file("*.tscn") var level_scene: String = "res://levels/test_level.tscn"
## Своё название места в досье (пусто — по сцене уровня, LOCATIONS)
@export var location_name: String = ""

@export_group("Goal")
## WAVES: количество волн
@export_range(1, 50) var wave_count: int = 3
## KILL_COUNT: сколько зомби убить
@export_range(1, 500) var kill_target: int = 25
## SURVIVE: сколько секунд продержаться
@export var survive_time: float = 90.0
## DEFEND: сколько секунд нужно простоять на точке (время вне точки не считается)
@export var defend_time: float = 60.0
## DEFEND: радиус точки, метры
@export var defend_radius: float = 5.0
## COLLECT: сколько ящиков с припасами собрать
@export_range(1, 20) var collect_target: int = 5

@export_group("Zombie Types")
@export var walker: ZombieData
@export var runner: ZombieData
@export var tank: ZombieData
## Шансы на старте (остальные — обычные зомби)
@export_range(0.0, 1.0, 0.01) var runner_chance: float = 0.15
@export_range(0.0, 1.0, 0.01) var tank_chance: float = 0.0
## Рост шансов за каждую волну (в других режимах — каждые 30 секунд)
@export_range(0.0, 0.5, 0.01) var runner_chance_per_level: float = 0.08
@export_range(0.0, 0.5, 0.01) var tank_chance_per_level: float = 0.04
## Особые зомби (ползун, плевун, взрывной, собака): шанс на старте и рост за уровень
@export var specials: Array[ZombieData] = []
@export_range(0.0, 1.0, 0.01) var special_chance: float = 0.12
@export_range(0.0, 0.2, 0.01) var special_chance_per_level: float = 0.02
## Босс: в режиме волн появляется в начале последней волны, в ENDLESS — каждые boss_every_waves
## волн, в остальных — через boss_delay (в FREE_ROAM — каждые boss_delay секунд)
@export var boss: ZombieData
@export var boss_delay: float = 45.0
@export_range(1, 50) var boss_every_waves: int = 5

@export_group("Spawning")
@export var start_delay: float = 3.0
## WAVES: зомби в первой волне и прирост за каждую следующую
@export_range(1, 100) var first_wave_size: int = 6
@export_range(0, 50) var wave_size_growth: int = 3
@export var time_between_waves: float = 5.0
## Максимум живых зомби одновременно (важно для FPS на слабых телефонах)
@export_range(1, 40) var max_alive: int = 10
## Пауза между появлениями зомби, сек
@export var spawn_interval: float = 1.2
## KILL_COUNT / SURVIVE: пауза постепенно сокращается до этого значения
@export var min_spawn_interval: float = 0.5
## Зомби периодически узнают, где игрок (орда), вместо блуждания
@export var horde_mode: bool = true

@export_group("Drops")
## Шанс выпадения патронов и аптечки из убитого зомби
@export_range(0.0, 1.0, 0.01) var ammo_drop_chance: float = 0.12
@export_range(0.0, 1.0, 0.01) var health_drop_chance: float = 0.07
## Шанс выпадения лома (для мастерской)
@export_range(0.0, 1.0, 0.01) var scrap_drop_chance: float = 0.2
## Аптечка лечит столько очков
@export var health_drop_amount: float = 30.0

@export_group("Stars")
## Вторая звезда: здоровье в конце не ниже этой доли
@export_range(0.0, 1.0, 0.05) var star_health: float = 0.5
## Третья звезда: точность не ниже этой доли
@export_range(0.0, 1.0, 0.05) var star_accuracy: float = 0.5

## Обучение: подсказки по шагам (TutorialDirector), зомби появляются по ходу обучения
@export var tutorial: bool = false

@export_group("Reward")
## Монеты за победу (плюс очки за каждого убитого зомби)
@export var reward_coins: int = 100
## ENDLESS: монеты за каждую пройденную волну
@export var coins_per_wave: int = 25


# ---------- Тексты для досье и кат-сцен ----------

const TYPE_NAMES: Dictionary = {
	Type.WAVES: "ВОЛНЫ",
	Type.KILL_COUNT: "ОХОТА",
	Type.SURVIVE: "ВЫЖИВАНИЕ",
	Type.DEFEND: "ОБОРОНА ТОЧКИ",
	Type.COLLECT: "СБОР ПРИПАСОВ",
	Type.ENDLESS: "БЕСКОНЕЧНЫЙ РЕЖИМ",
	Type.FREE_ROAM: "ОТКРЫТЫЙ ГОРОД",
}
## Название локации по файлу сцены уровня
const LOCATIONS: Dictionary = {
	"test_level": "ПОЛИГОН",
	"street_level": "УЛИЦА",
	"yard_level": "СТОЯНКА КОНТЕЙНЕРОВ",
	"city_level": "ГОРОД",
	"graveyard_level": "КЛАДБИЩЕ",
	"forest_level": "ЛЕСНОЙ ЛАГЕРЬ",
	"industrial_level": "ПРОМЗОНА",
	"harbor_level": "ЮЖНЫЙ ПОРТ",
}


func get_type_name() -> String:
	return TYPE_NAMES.get(type, "МИССИЯ")


func get_location_name() -> String:
	if not location_name.is_empty():
		return location_name
	var path: String = level_scene
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			path = ResourceUID.get_id_path(uid)
	var file: String = path.get_file().get_basename()
	return LOCATIONS.get(file, file.to_upper())


func get_goal_text() -> String:
	match type:
		Type.WAVES:
			var text: String = UIKit.t("Отбей %s") % UIKit.count(wave_count, "волну", "волны", "волн")
			if boss != null:
				text += UIKit.t(", в последней — %s") % UIKit.t(boss.display_name)
			return text
		Type.KILL_COUNT:
			return UIKit.t("Убей %s") % UIKit.count(kill_target, "зомби", "зомби", "зомби")
		Type.SURVIVE:
			var total: int = maxi(ceili(survive_time), 0)
			return UIKit.t("Продержись %d:%02d") % [floori(total / 60.0), total % 60]
		Type.DEFEND:
			return UIKit.t("Продержись на точке %s") % UIKit.count(roundi(defend_time), "секунду", "секунды", "секунд")
		Type.COLLECT:
			return UIKit.t("Собери %s с припасами") % UIKit.count(collect_target, "ящик", "ящика", "ящиков")
		Type.ENDLESS:
			return "Держись как можно дольше: волны без конца"
		Type.FREE_ROAM:
			return "Исследуй город, спасай выживших, катайся и сбивай зомби"
	return ""
