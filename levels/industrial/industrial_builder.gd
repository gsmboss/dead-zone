class_name IndustrialBuilder
extends LocationBuilder
## «Промзона»: цеха и склады по краям (стена из зданий), цистерны, трубы, штабеля контейнеров
## как укрытия, водонапорная башня и ветряк для силуэта, бочки с огнём. Смог и оранжевое солнце.

const IND: String = "res://models/industrial/"
const ENV: String = "res://models/environment/"
const VEH: String = "res://models/vehicles/"
const BUILDINGS: Array[String] = ["res://models/industrial/building-a.glb", "res://models/industrial/building-c.glb",
	"res://models/industrial/building-e.glb", "res://models/industrial/building-f.glb",
	"res://models/industrial/building-l.glb", "res://models/industrial/building-m.glb",
	"res://models/industrial/building-q.glb", "res://models/industrial/building-r.glb"]
const CONTAINERS: Array[String] = ["res://models/industrial/shipping-container-a.glb",
	"res://models/industrial/shipping-container-b.glb", "res://models/industrial/shipping-container-c.glb"]
const COVER: Array[String] = ["res://models/environment/Pipes.gltf", "res://models/environment/CinderBlock.gltf",
	"res://models/environment/Pallet.gltf", "res://models/environment/TrafficBarrier_1.gltf",
	"res://models/environment/Barrel.gltf", "res://models/environment/Wheels_Stack.gltf"]
const WRECKS: Array[String] = ["res://models/vehicles/Vehicle_Truck.gltf", "res://models/vehicles/Vehicle_Pickup.gltf"]
## Модели Kenney Industrial маленькие: контейнер 0.82 → ~6 м
const KIT_SCALE: float = 7.0


func _init() -> void:
	fog_color = Color(0.45, 0.33, 0.24)
	fog_density = 0.022
	sun_color = Color(1.0, 0.72, 0.45)
	sun_energy = 0.85
	ground_color = Color(0.27, 0.26, 0.25)


func _build_location() -> void:
	# Цеха вдоль двух сторон — стена из зданий; с двух других — ограда из барьеров
	for side in [0, 2]:
		var yaw: float = side * PI * 0.5
		var along: float = -half_size + 6.0
		while along < half_size - 6.0:
			var path: String = BUILDINGS[_rng.randi() % BUILDINGS.size()]
			# За стенами уровня (Bounds), поэтому без коллизии — просто стена из цехов
			var at: Vector3 = Vector3(along, 0.0, half_size + 9.0).rotated(Vector3.UP, yaw)
			_place(path, at, yaw + PI, KIT_SCALE, false)
			along += 14.0 + _rng.randf_range(0.0, 3.0)
	for side in [1, 3]:
		var yaw: float = side * PI * 0.5
		var along: float = -half_size
		while along < half_size:
			var at: Vector3 = Vector3(along, 0.0, half_size + 0.8).rotated(Vector3.UP, yaw)
			_place(ENV + ("TrafficBarrier_2.gltf" if _rng.randf() < 0.5 else "PlasticBarrier.gltf"), at, yaw, 1.0, false)
			along += 2.2

	# Силуэты над крышами (за стенами — без коллизии)
	_place(IND + "water-tower.glb", Vector3(-half_size - 8.0, 0.0, -half_size + 10.0), 0.0, KIT_SCALE, false)
	_place(IND + "windmill.glb", Vector3(half_size + 10.0, 0.0, half_size - 12.0), 0.8, KIT_SCALE, false)
	_place(IND + "chimney-large.glb", Vector3(half_size + 6.0, 0.0, -half_size + 4.0), 0.0, KIT_SCALE, false)

	# Цистерны и штабеля контейнеров — крупные укрытия
	for i in 3:
		var at := Vector3(_rng.randf_range(-14.0, 14.0), 0.0, _rng.randf_range(-14.0, 14.0))
		if _is_free(at, 6.0):
			_place(IND + "detail-tank-large.glb", at, _rng.randf() * TAU, KIT_SCALE * 0.55, true, Vector3.ZERO, 5.0)
			_keep_clear.append(at)
	for i in 5:
		var at := Vector3(_rng.randf_range(-18.0, 18.0), 0.0, _rng.randf_range(-18.0, 18.0))
		if not _is_free(at, 4.5):
			continue
		var yaw: float = _rng.randf() * TAU
		var container: String = CONTAINERS[_rng.randi() % CONTAINERS.size()]
		_place(container, at, yaw, KIT_SCALE, true, Vector3.ZERO, 3.5)
		if _rng.randf() < 0.5:
			# Второй ярус — на крышу не залезть, но силуэт интереснее
			_place(CONTAINERS[_rng.randi() % CONTAINERS.size()], at + Vector3.UP * 2.45, yaw + 0.1, KIT_SCALE, false)
		_keep_clear.append(at)

	_scatter(COVER, 24, Vector2(1.0, 1.3), 1.8)
	_scatter(WRECKS, 3, Vector2(1.0, 1.0), 4.0)
	_scatter([IND + "detail-tank.glb"], 4, Vector2(KIT_SCALE * 0.6, KIT_SCALE * 0.7), 2.5)
	# Бочки с огнём — свет в смоге
	for i in 4:
		var at := Vector3(_rng.randf_range(-20.0, 20.0), 0.0, _rng.randf_range(-20.0, 20.0))
		if _is_free(at, 1.0):
			_place(ENV + "Barrel.gltf", at, 0.0, 1.0)
			_fire(at, 1.0, 8.0)
			_keep_clear.append(at)
