class_name HubYard
extends Node3D
## Двор убежища: видимая ограда из контейнеров за невидимыми стенами Room/Bounds, ворота-грузовик,
## кучи хлама в углах, склад у северной стены, фонари. Создаётся кодом (hub.gd), пересоздаётся при
## расширении убежища: размер — GameState.shelter.get_half_size() (контейнеров на сторону — сколько
## влезает), с уровня ФОРТ — второй ярус, с КРЕПОСТИ — прожекторы и флаги на стенах.
## Всё через PropBatch: одинаковые модели — один MultiMesh.

const ENV: String = "res://models/environment/"
## Полуразмер стартового двора (склад и фонари стоят по нему)
const BASE_HALF: float = 16.0
## Уровни убежища, с которых ограда богаче
const SECOND_TIER_LEVEL: int = 3
const FORTRESS_LEVEL: int = 5
## Контейнеры стоят снаружи стен на столько
const FENCE_OFFSET: float = 1.28
## Длина контейнера Quaternius
const CONTAINER_STEP: float = 5.71
const STREET_LIGHT_BOX: Vector3 = Vector3(0.4, 6.6, 0.4)

## Полуразмер двора — как стены Room/Bounds (hub.gd ставит их по уровню убежища)
var half: float = BASE_HALF
var level: int = 1

var _batch: PropBatch
var _scenes: Dictionary = {}


func _ready() -> void:
	half = GameState.shelter.get_half_size()
	level = GameState.shelter.level
	_batch = PropBatch.new(self)
	_build_perimeter()
	_build_corners()
	_build_storage()
	_build_gate()
	_batch.build()
	if level >= FORTRESS_LEVEL:
		_build_fortress()


func _scene(file: String) -> PackedScene:
	if _scenes.has(file):
		return _scenes[file]
	var path: String = ENV + file + ".gltf"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("HubYard: нет модели %s" % path)
	_scenes[file] = scene
	return scene


func _add(file: String, at: Vector3, yaw_deg: float = 0.0, collide: bool = true, box: Vector3 = Vector3.ZERO) -> void:
	var scene: PackedScene = _scene(file)
	if scene != null:
		_batch.add(scene, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at), collide, box)


## Контейнеры по сторонам (сколько влезает по длине стены), на юге — ворота посередине;
## сверху — второй ярус местами (с уровня ФОРТ — через один)
func _build_perimeter() -> void:
	var line: float = half + FENCE_OFFSET
	var count: int = maxi(roundi(half * 2.0 / CONTAINER_STEP), 2)
	var tier_step: int = 2 if level >= SECOND_TIER_LEVEL else 3
	for i in count:
		var along: float = (float(i) - float(count - 1) * 0.5) * CONTAINER_STEP
		var color: String = "Container_Red" if i % 2 == 0 else "Container_Green"
		var other: String = "Container_Green" if i % 2 == 0 else "Container_Red"
		_add(color, Vector3(along, 0.0, -line), 0.0, false)
		_add(other, Vector3(-line, 0.0, along), 90.0, false)
		_add(color, Vector3(line, 0.0, along), -90.0, false)
		# Юг: ворота посередине (грузовик) — без средних контейнеров
		var gate: bool = absf(along) < (CONTAINER_STEP if count % 2 == 0 else CONTAINER_STEP * 0.5)
		if not gate:
			_add(other, Vector3(along, 0.0, line), 180.0, false)
		# Второй ярус — чуть повёрнутые контейнеры
		if i % tier_step == 1:
			var tilt: float = 3.0 if i % 4 == 1 else -2.0
			_add(other, Vector3(along, 2.6, -line), tilt, false)
			_add(color, Vector3(-line, 2.6, along), 90.0 + tilt, false)
			_add(other, Vector3(line, 2.6, along), -90.0 - tilt, false)
			if not gate and level >= SECOND_TIER_LEVEL:
				_add(color, Vector3(along, 2.6, line), 180.0 + tilt, false)


## В углах снаружи — бочки и покрышки (закрывают щели между рядами контейнеров)
func _build_corners() -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * (half + 1.6), 0.0, sz * (half + 1.6))
			_add("Barrel", corner + Vector3(-sx * 0.6, 0.0, 0.0), 0.0, false)
			_add("Barrel", corner + Vector3(0.0, 0.0, -sz * 0.6), 40.0, false)
			_add("Wheels_Stack", corner + Vector3(sx * 0.4, 0.0, sz * 0.4), 0.0, false)


## Склад у северной стены: поддоны, ящики, бочки, покрышки; фонари по углам двора
func _build_storage() -> void:
	_add("Pallet", Vector3(-12.5, 0.0, -14.6), 0.0)
	_add("Pallet", Vector3(-10.6, 0.0, -14.6), 0.0)
	_add("Chest", Vector3(-12.5, 0.14, -14.6), 10.0)
	_add("Chest_Special", Vector3(-10.6, 0.14, -14.6), -6.0)
	_add("Pallet_Broken", Vector3(-8.4, 0.0, -14.8), 20.0)
	_add("Barrel", Vector3(-14.6, 0.0, -12.2))
	_add("Barrel", Vector3(-14.9, 0.0, -11.4))
	_add("Wheels_Stack", Vector3(-14.8, 0.0, -10.2))
	_add("CinderBlock", Vector3(-7.0, 0.0, -14.9), 15.0)
	_add("TrashBag_1", Vector3(9.5, 0.0, -14.9), 0.0, false)
	_add("TrashBag_2", Vector3(10.2, 0.0, -15.0), 60.0, false)
	_add("Pallet", Vector3(13.5, 0.0, -14.6), 90.0)
	_add("Wheel", Vector3(12.0, 0.0, -14.9), 0.0)
	for at: Vector3 in [Vector3(-14.8, 0.0, -14.8), Vector3(14.8, 0.0, 14.8), Vector3(-14.8, 0.0, 14.8),
			Vector3(14.8, 0.0, -9.0)]:
		_add("StreetLights", at, 45.0 if at.x < 0.0 else -135.0, true, STREET_LIGHT_BOX)


## Ворота на юге: бронированный грузовик снаружи и заграждения по бокам изнутри
func _build_gate() -> void:
	var path: String = "res://models/vehicles/Vehicle_Truck_Armored.gltf"
	var truck: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if truck != null:
		_batch.add(truck, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.0, half + 1.7)), false)
	else:
		push_warning("HubYard: нет модели %s" % path)
	_add("TrafficBarrier_1", Vector3(-4.3, 0.0, half - 0.9))
	_add("TrafficBarrier_2", Vector3(4.3, 0.0, half - 0.9))
	_add("TrafficCone_1", Vector3(-2.9, 0.0, half - 1.4), 0.0, false)
	_add("TrafficCone_2", Vector3(2.9, 0.0, half - 1.4), 0.0, false)


## Крепость: прожекторы на углах стен и флаги над воротами и по сторонам
func _build_fortress() -> void:
	var line: float = half + FENCE_OFFSET
	var steel := HubDecor.material(Color(0.3, 0.3, 0.33))
	var glow := HubDecor.material(Color(1.0, 0.95, 0.75), 3.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base := Vector3(sx * line, 0.0, sz * line)
			HubDecor._cylinder(self, Transform3D.IDENTITY, base + Vector3.UP * 4.0, 0.12, 8.0, steel)
			var lamp := HubDecor._sphere(self, Transform3D.IDENTITY, base + Vector3.UP * 8.1, 0.35, glow)
			lamp.scale = Vector3(1.0, 0.6, 1.0)
	var cloth := HubDecor.material(Color(0.85, 0.2, 0.18))
	for at: Vector3 in [Vector3(-3.4, 0.0, line), Vector3(3.4, 0.0, line), Vector3(0.0, 2.6, -line),
			Vector3(-line, 2.6, 0.0), Vector3(line, 2.6, 0.0)]:
		HubDecor._cylinder(self, Transform3D.IDENTITY, at + Vector3.UP * 4.5, 0.05, 4.0, steel)
		var flag := HubDecor._box(self, _batch, Transform3D.IDENTITY, at + Vector3(0.0, 5.9, 0.0) + Vector3(0.6, 0.0, 0.0),
			Vector3(1.2, 0.75, 0.03), cloth)
		flag.rotation.y = atan2(at.x, at.z)
