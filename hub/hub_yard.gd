class_name HubYard
extends Node3D
## Большой двор убежища (32×32): видимая ограда из контейнеров за невидимыми стенами Room/Bounds,
## ворота-грузовик, кучи хлама в углах, склад у северной стены, фонари. Создаётся кодом (hub.gd).
## Всё через PropBatch: одинаковые модели — один MultiMesh.

const ENV: String = "res://models/environment/"
## Полуразмер двора — как стены Room/Bounds в hub.tscn
const HALF: float = 16.0
## Контейнеры стоят снаружи стен на столько
const FENCE_OFFSET: float = 1.28
## Длина контейнера Quaternius
const CONTAINER_STEP: float = 5.71
const STREET_LIGHT_BOX: Vector3 = Vector3(0.4, 6.6, 0.4)

var _batch: PropBatch
var _scenes: Dictionary = {}


func _ready() -> void:
	_batch = PropBatch.new(self)
	_build_perimeter()
	_build_corners()
	_build_storage()
	_build_gate()
	_batch.build()


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


## Контейнеры по трём сторонам (6 в ряд) и по бокам ворот на юге; сверху — второй ярус местами
func _build_perimeter() -> void:
	var line: float = HALF + FENCE_OFFSET
	for i in 6:
		var along: float = (float(i) - 2.5) * CONTAINER_STEP
		var color: String = "Container_Red" if i % 2 == 0 else "Container_Green"
		var other: String = "Container_Green" if i % 2 == 0 else "Container_Red"
		_add(color, Vector3(along, 0.0, -line), 0.0, false)
		_add(other, Vector3(-line, 0.0, along), 90.0, false)
		_add(color, Vector3(line, 0.0, along), -90.0, false)
	# Юг: ворота посередине (грузовик), контейнеры по бокам
	for x: float in [-8.565, -14.275, 8.565, 14.275]:
		_add("Container_Red" if absf(x) < 10.0 else "Container_Green", Vector3(x, 0.0, line), 180.0, false)
	# Второй ярус — чуть повёрнутые контейнеры
	_add("Container_Green", Vector3(-2.4, 2.6, -line), 3.0, false)
	_add("Container_Red", Vector3(9.0, 2.6, -line), -2.0, false)
	_add("Container_Red", Vector3(-line, 2.6, 1.2), 92.0, false)
	_add("Container_Green", Vector3(line, 2.6, -6.0), -88.0, false)
	_add("Container_Green", Vector3(-12.0, 2.6, line), 182.0, false)


## В углах снаружи — бочки и покрышки (закрывают щели между рядами контейнеров)
func _build_corners() -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * (HALF + 1.6), 0.0, sz * (HALF + 1.6))
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
		_batch.add(truck, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.0, HALF + 1.7)), false)
	else:
		push_warning("HubYard: нет модели %s" % path)
	_add("TrafficBarrier_1", Vector3(-4.3, 0.0, HALF - 0.9))
	_add("TrafficBarrier_2", Vector3(4.3, 0.0, HALF - 0.9))
	_add("TrafficCone_1", Vector3(-2.9, 0.0, HALF - 1.4), 0.0, false)
	_add("TrafficCone_2", Vector3(2.9, 0.0, HALF - 1.4), 0.0, false)
