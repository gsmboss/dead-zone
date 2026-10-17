class_name CityConfig
extends Resource
## Параметры генерации большого города (levels/city/city_generator.gd).

@export_group("Layout")
## Кварталов по каждой стороне (город = blocks × block_size метров)
@export_range(3, 9) var blocks: int = 7
## Шаг сетки дорог, метры; должен делиться на 8 (длина тайла дороги)
@export var block_size: float = 48.0
## Кварталы в центре (расстояние от центра в кварталах) — деловой район
@export_range(0, 4) var downtown_radius: int = 1
## Доля пустых участков (парковки, дворы)
@export_range(0.0, 0.6, 0.05) var empty_lot_chance: float = 0.15
## Широкие проспекты (24 м): кольцо по краю города и бульвар вокруг делового центра
@export var wide_avenues: bool = true
## Квартал за бульваром — пустая асфальтовая дрифт-площадь
@export var drift_plaza: bool = true
## Зерно генерации: один и тот же город при каждом запуске (0 — случайный)
@export var generation_seed: int = 1337

@export_group("Models")
@export var road_straight: PackedScene
@export var road_cross: PackedScene
@export var commercial: Array[PackedScene] = []
@export var skyscrapers: Array[PackedScene] = []
@export var houses: Array[PackedScene] = []
@export var trees: Array[PackedScene] = []
## Брошенные машины (статичные) и машины, на которых можно ездить
@export var wrecks: Array[PackedScene] = []
@export var drivable_cars: Array[PackedScene] = []
## Мелочи на тротуарах и во дворах (бочки, барьеры, мусор)
@export var props: Array[PackedScene] = []
@export var street_light: PackedScene
## Модели выживших (Characters_* Quaternius)
@export var survivor_models: Array[PackedScene] = []

@export_group("Scale")
## Kenney: 1 единица ≈ ширина дороги; масштаб под метры игры
@export var commercial_scale: float = 8.5
@export var skyscraper_scale: float = 7.0
@export var house_scale: float = 7.0
@export var tree_scale: float = 10.0

@export_group("Content")
@export_range(0, 20) var drivable_car_count: int = 10
@export_range(0, 80) var wreck_count: int = 34
@export_range(0, 200) var prop_count: int = 140
@export_range(0, 40) var pickup_count: int = 20
@export_range(0, 12) var survivor_count: int = 4
## Выжившие не ближе этого к центру (точке эвакуации)
@export var survivor_min_distance: float = 45.0
## Доля зданий делового района с обыскиваемым входом (лут)
@export_range(0.0, 1.0, 0.05) var loot_spot_chance: float = 0.25
## Фонари вдоль дорог через столько метров (0 — без фонарей)
@export var street_light_spacing: float = 24.0
