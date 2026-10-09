class_name StoryStage
extends Node3D
## Сцена-диорама для сюжетных фильмов: улица города с перекрёстком, домами, фонарями и светофорами.
## Настроения (StoryShot.Mood): LIVING — живой город днём (люди гуляют, машины едут, светофоры работают),
## OUTBREAK — начало заражения (люди бегут, за ними зомби, мигалки, пожар), DEAD — мёртвый город ночью
## (обгоревшие машины, бродят зомби, туман), BANDITS — лагерь бандитов Барона у бочки с огнём,
## HOPE — рассвет, выжившие идут вместе, CAMP — ночной лагерь выживших: костёр, палатки, люди сидят у огня. Строится кодом в отдельном мире (SubViewport StoryCinema).

const ROAD_TILE: float = 8.0
const STREET_HALF: float = 64.0
const CROSS_HALF: float = 40.0
const SIDEWALK_Z: float = 6.5
const BUILDING_Z: float = 15.0
const TOWER_Z: float = 34.0

const ROAD_STRAIGHT: String = "res://models/environment/Street_Straight.gltf"
const ROAD_CROSS: String = "res://models/environment/Street_4Way.gltf"
const STREET_LIGHT: String = "res://models/environment/StreetLights.gltf"
const TRAFFIC_LIGHT: String = "res://models/environment/TrafficLight_1.gltf"
const BUILDINGS: Array[String] = [
	"res://models/city/commercial/building-a.glb", "res://models/city/commercial/building-b.glb",
	"res://models/city/commercial/building-c.glb", "res://models/city/commercial/building-d.glb",
	"res://models/city/commercial/building-e.glb", "res://models/city/commercial/building-f.glb",
	"res://models/city/commercial/building-g.glb", "res://models/city/commercial/building-h.glb",
	"res://models/city/commercial/building-k.glb", "res://models/city/commercial/building-l.glb",
]
const TOWERS: Array[String] = [
	"res://models/city/commercial/building-skyscraper-a.glb", "res://models/city/commercial/building-skyscraper-b.glb",
	"res://models/city/commercial/building-skyscraper-c.glb", "res://models/city/commercial/building-skyscraper-d.glb",
	"res://models/city/commercial/building-skyscraper-e.glb",
]
const TREE: String = "res://models/city/suburban/tree-large.glb"
## Жители: Kenney (анимации idle/walk/sprint) и Quaternius (Idle/Walk/Run/Wave)
const PEOPLE_KENNEY: Array[String] = [
	"res://models/characters/kenney/character-male-a.glb", "res://models/characters/kenney/character-female-a.glb",
	"res://models/characters/kenney/character-male-b.glb", "res://models/characters/kenney/character-female-b.glb",
	"res://models/characters/kenney/character-male-c.glb", "res://models/characters/kenney/character-female-c.glb",
	"res://models/characters/kenney/character-female-d.glb", "res://models/characters/kenney/character-female-e.glb",
	"res://models/characters/kenney/character-female-f.glb",
]
const PEOPLE_QUATERNIUS: Array[String] = [
	"res://models/zombies/Characters_Lis.gltf", "res://models/zombies/Characters_Matt.gltf",
	"res://models/zombies/Characters_Sam.gltf", "res://models/zombies/Characters_Shaun.gltf",
]
const ZOMBIES: Array[String] = [
	"res://models/zombies/Zombie_Basic.gltf", "res://models/zombies/Zombie_Arm.gltf",
	"res://models/zombies/Zombie_Chubby.gltf", "res://models/zombies/Zombie_Ribcage.gltf",
]
const DOG: String = "res://models/zombies/Characters_Pug.gltf"
const CARS: Array[String] = [
	"res://models/vehicles/kenney/sedan.glb", "res://models/vehicles/kenney/taxi.glb",
	"res://models/vehicles/kenney/van.glb", "res://models/vehicles/kenney/suv.glb",
	"res://models/vehicles/kenney/delivery.glb", "res://models/vehicles/kenney/hatchback-sports.glb",
	"res://models/vehicles/kenney/sedan-sports.glb", "res://models/vehicles/kenney/suv-luxury.glb",
	"res://models/vehicles/kenney/garbage-truck.glb",
]
const POLICE: String = "res://models/vehicles/kenney/police.glb"
const AMBULANCE: String = "res://models/vehicles/kenney/ambulance.glb"
const FIRETRUCK: String = "res://models/vehicles/kenney/firetruck.glb"
const ARMORED_TRUCK: String = "res://models/vehicles/Vehicle_Truck_Armored.gltf"
const ARMORED_PICKUP: String = "res://models/vehicles/Vehicle_Pickup_Armored.gltf"
const DEBRIS: Array[String] = [
	"res://models/vehicles/kenney/debris-bumper.glb", "res://models/vehicles/kenney/debris-door.glb",
	"res://models/vehicles/kenney/debris-tire.glb", "res://models/vehicles/kenney/debris-plate-a.glb",
	"res://models/environment/TrashBag_1.gltf", "res://models/environment/TrashBag_2.gltf",
	"res://models/environment/TrafficCone_1.gltf", "res://models/environment/TrafficBarrier_1.gltf",
]
const BLOOD: Array[String] = ["res://models/environment/Blood_1.gltf", "res://models/environment/Blood_2.gltf",
	"res://models/environment/Blood_3.gltf"]
const BARREL: String = "res://models/environment/Barrel.gltf"
## Лагерь (Kenney Survival Kit, модели маленькие — масштаб)
const CAMP_DIR: String = "res://models/survival/"
const CAMP_SCALE: float = 3.4

## Камеры: [откуда, куда, взгляд в начале, взгляд в конце]
const CAMERAS: Dictionary = {
	"aerial": [Vector3(-75, 40, 58), Vector3(25, 32, 48), Vector3(-15, 0, 0), Vector3(20, 0, 0)],
	"skyline": [Vector3(-6, 1.7, 9.0), Vector3(6, 1.7, 9.0), Vector3(-30, 24, -40), Vector3(30, 24, -40)],
	"sidewalk": [Vector3(-26, 1.7, 9.2), Vector3(-8, 1.7, 9.2), Vector3(-14, 1.3, 6.0), Vector3(4, 1.3, 6.0)],
	"crossroad": [Vector3(17, 7, 17), Vector3(11, 4.5, 11), Vector3(0, 1, 0), Vector3(0, 1, 0)],
	"road_low": [Vector3(38, 0.7, -0.6), Vector3(22, 0.7, -0.6), Vector3(0, 1.2, 0), Vector3(-20, 1.2, 0)],
	"close_up": [Vector3(-10, 1.6, 10.8), Vector3(-11.5, 1.6, 9.6), Vector3(-14, 1.3, 7.0), Vector3(-14, 1.3, 7.0)],
	"window": [Vector3(-22, 11, 13), Vector3(-18, 10, 12.5), Vector3(-20, 0, 2), Vector3(-14, 0, 0)],
	"chase": [Vector3(-6, 1.3, -1.2), Vector3(-30, 1.3, -1.2), Vector3(-20, 1.2, 0), Vector3(-45, 1.2, 0)],
	"zombie_low": [Vector3(7, 0.35, 3.2), Vector3(4.5, 0.45, 2.2), Vector3(-6, 1.4, 0), Vector3(-9, 1.4, 0)],
	"fire_wreck": [Vector3(13, 2.6, -10), Vector3(9, 2.0, -7.5), Vector3(4, 1, -2), Vector3(3, 1, -2)],
	"bandit_orbit": [Vector3(9, 2.4, 9), Vector3(-9, 2.4, 9), Vector3(0, 1.3, 0), Vector3(0, 1.3, 0)],
	"baron": [Vector3(4.0, 1.5, -6.5), Vector3(2.8, 1.5, -5.2), Vector3(0, 2.0, -3.0), Vector3(0, 2.0, -3.0)],
	"hope_walk": [Vector3(-34, 1.8, 0.4), Vector3(-26, 1.7, 0.4), Vector3(0, 1.4, 0), Vector3(-12, 1.4, 0)],
	"sky_up": [Vector3(0, 2, 12), Vector3(0, 2.5, 12), Vector3(0, 3, 0), Vector3(0, 45, -10)],
	"street_end": [Vector3(-58, 3.5, 2), Vector3(-50, 2.5, 1), Vector3(0, 2, 0), Vector3(0, 1.5, 0)],
	"camp_orbit": [Vector3(7.5, 3.2, 6.0), Vector3(-7.5, 3.2, 6.0), Vector3(0, 0.8, 0), Vector3(0, 0.8, 0)],
	"camp_fire": [Vector3(0.6, 0.5, 4.6), Vector3(0.2, 0.6, 3.8), Vector3(0, 0.7, 0), Vector3(0, 0.9, -1.5)],
	"camp_high": [Vector3(-14, 9, 14), Vector3(-9, 7, 10), Vector3(0, 0.5, 0), Vector3(0, 0.5, 0)],
}

## Настроение: небо (верх, горизонт), солнце (цвет, сила, высота°), окружение, туман
const MOODS: Dictionary = {
	StoryShot.Mood.LIVING: [Color(0.3, 0.55, 0.9), Color(0.75, 0.82, 0.9), Color(1.0, 0.96, 0.88), 1.3, 50.0, 1.0, 0.002],
	StoryShot.Mood.OUTBREAK: [Color(0.35, 0.2, 0.25), Color(1.0, 0.5, 0.25), Color(1.0, 0.55, 0.3), 1.0, 10.0, 0.6, 0.01],
	StoryShot.Mood.DEAD: [Color(0.02, 0.03, 0.07), Color(0.1, 0.12, 0.17), Color(0.45, 0.55, 0.85), 0.25, 35.0, 0.3, 0.02],
	StoryShot.Mood.BANDITS: [Color(0.03, 0.02, 0.05), Color(0.2, 0.08, 0.06), Color(0.5, 0.4, 0.6), 0.2, 30.0, 0.25, 0.018],
	StoryShot.Mood.HOPE: [Color(0.35, 0.45, 0.75), Color(1.0, 0.7, 0.5), Color(1.0, 0.78, 0.55), 0.9, 12.0, 0.75, 0.006],
	StoryShot.Mood.BLACK: [Color.BLACK, Color.BLACK, Color.BLACK, 0.0, 30.0, 0.0, 0.0],
	StoryShot.Mood.CAMP: [Color(0.02, 0.03, 0.09), Color(0.09, 0.11, 0.22), Color(0.5, 0.6, 0.95), 0.22, 35.0, 0.3, 0.014],
}

var mood: int = -1

var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _actors: Node3D
var _scenes: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _signal_materials: Array[StandardMaterial3D] = []  # красный, жёлтый, зелёный на всех светофорах
var _signal_time: float = 0.0
var _flames: Array[Node3D] = []


func _ready() -> void:
	_rng.seed = 2031
	_build_environment()
	_build_street()
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)


func _process(delta: float) -> void:
	_signal_time += delta
	_update_signals()


## Камера-заготовка: [откуда, куда, взгляд с, взгляд на]
static func get_camera(camera_name: String) -> Array:
	return CAMERAS.get(camera_name, CAMERAS["aerial"])


func set_mood(new_mood: int) -> void:
	if new_mood == mood:
		return
	mood = new_mood
	for child: Node in _actors.get_children():
		child.queue_free()
	_flames.clear()
	_apply_light(new_mood)
	match new_mood:
		StoryShot.Mood.LIVING:
			_build_living()
		StoryShot.Mood.OUTBREAK:
			_build_outbreak()
		StoryShot.Mood.DEAD:
			_build_dead()
		StoryShot.Mood.BANDITS:
			_build_dead(true)
			_build_bandits()
		StoryShot.Mood.HOPE:
			_build_hope()
		StoryShot.Mood.CAMP:
			_build_camp()
	visible = new_mood != StoryShot.Mood.BLACK


# ---------- Свет и небо ----------

func _build_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.fog_enabled = true
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	_sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	add_child(_sun)


func _apply_light(new_mood: int) -> void:
	var values: Array = MOODS.get(new_mood, MOODS[StoryShot.Mood.LIVING])
	_sky_material.sky_top_color = values[0]
	_sky_material.sky_horizon_color = values[1]
	_sky_material.ground_horizon_color = values[1]
	_sky_material.ground_bottom_color = (values[1] as Color).darkened(0.6)
	_sun.light_color = values[2]
	_sun.light_energy = values[3]
	_sun.rotation.x = deg_to_rad(-float(values[4]))
	_environment.ambient_light_energy = values[5]
	_environment.fog_density = values[6]
	_environment.fog_light_color = values[1]


# ---------- Улица ----------

func _build_street() -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.32, 0.3)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	plane.material = ground_material
	ground.mesh = plane
	ground.position.y = -0.02
	add_child(ground)

	var straight: PackedScene = _load(ROAD_STRAIGHT)
	var cross: PackedScene = _load(ROAD_CROSS)
	var tiles: int = roundi(STREET_HALF * 2.0 / ROAD_TILE)
	for k in tiles + 1:
		var x: float = -STREET_HALF + k * ROAD_TILE
		if absf(x) < 0.1:
			_place(cross, Vector3.ZERO, 0.0, 1.0)
		else:
			_place(straight, Vector3(x, 0.0, 0.0), PI * 0.5, 1.0)
	var cross_tiles: int = roundi(CROSS_HALF * 2.0 / ROAD_TILE)
	for k in cross_tiles + 1:
		var z: float = -CROSS_HALF + k * ROAD_TILE
		if absf(z) > 0.1:
			_place(straight, Vector3(0.0, 0.0, z), 0.0, 1.0)

	# Тротуары — светлые полосы вдоль улицы
	var walk_material := StandardMaterial3D.new()
	walk_material.albedo_color = Color(0.55, 0.55, 0.53)
	for side: float in [-1.0, 1.0]:
		for half: float in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(STREET_HALF - 4.0, 0.12, 4.5)
			box.material = walk_material
			var walk := MeshInstance3D.new()
			walk.mesh = box
			walk.position = Vector3(half * (STREET_HALF * 0.5 + 2.0), 0.06, side * (SIDEWALK_Z + 0.5))
			add_child(walk)

	# Дома вдоль улицы и небоскрёбы за ними
	var index: int = 0
	for side: float in [-1.0, 1.0]:
		var x: float = -STREET_HALF + 6.0
		while x < STREET_HALF - 4.0:
			if absf(x) > 9.0:
				var scene: PackedScene = _load(BUILDINGS[index % BUILDINGS.size()])
				index += 1
				_place_fitted(scene, Vector3(x, 0.0, side * BUILDING_Z), 0.0 if side < 0.0 else PI, 11.0)
			x += 13.0
		var tower_x: float = -STREET_HALF + 10.0
		while tower_x < STREET_HALF:
			var tower: PackedScene = _load(TOWERS[index % TOWERS.size()])
			index += 1
			_place_fitted(tower, Vector3(tower_x, 0.0, side * TOWER_Z), 0.0 if side < 0.0 else PI, 15.0)
			tower_x += 19.0

	# Фонари и деревья вдоль тротуаров
	var light: PackedScene = _load(STREET_LIGHT)
	var tree: PackedScene = _load(TREE)
	for side: float in [-1.0, 1.0]:
		var x: float = -STREET_HALF + 8.0
		while x < STREET_HALF - 4.0:
			if absf(x) > 8.0:
				# Плечо фонаря (+Z модели) — к дороге
				_place(light, Vector3(x, 0.0, side * (SIDEWALK_Z + 1.6)), 0.0 if side < 0.0 else PI, 1.0)
				_place_fitted(tree, Vector3(x + 8.0, 0.0, side * (SIDEWALK_Z + 1.8)), _rng.randf() * TAU, 3.5)
			x += 16.0
	_build_traffic_lights()


## Светофоры на углах перекрёстка + свои огни (общие материалы — меняются все сразу)
func _build_traffic_lights() -> void:
	var scene: PackedScene = _load(TRAFFIC_LIGHT)
	var colors: Array[Color] = [Color(1.0, 0.1, 0.05), Color(1.0, 0.75, 0.1), Color(0.2, 1.0, 0.35)]
	for color: Color in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.7)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.0
		_signal_materials.append(material)
	var corners: Array[Vector3] = [Vector3(5.6, 0, 5.6), Vector3(-5.6, 0, 5.6), Vector3(-5.6, 0, -5.6), Vector3(5.6, 0, -5.6)]
	var yaws: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for i in corners.size():
		var pole := Node3D.new()
		pole.position = corners[i]
		pole.rotation.y = yaws[i]
		add_child(pole)
		if scene != null:
			pole.add_child(scene.instantiate())
		# Лампы на верхней секции (над столбом, лицом к перекрёстку по +Z модели)
		for lamp in 3:
			var sphere := SphereMesh.new()
			sphere.radius = 0.11
			sphere.height = 0.22
			sphere.radial_segments = 8
			sphere.rings = 4
			sphere.material = _signal_materials[lamp]
			var bulb := MeshInstance3D.new()
			bulb.mesh = sphere
			bulb.position = Vector3(0.0, 4.45 - lamp * 0.27, 0.55)
			pole.add_child(bulb)


## Светофоры: днём работают по циклу, при заражении и в мёртвом городе — мигает жёлтый
func _update_signals() -> void:
	if _signal_materials.is_empty():
		return
	var red: float = 0.0
	var yellow: float = 0.0
	var green: float = 0.0
	if mood == StoryShot.Mood.LIVING:
		var phase: float = fmod(_signal_time, 10.0)
		red = 3.0 if phase < 4.0 else 0.0
		yellow = 3.0 if phase >= 4.0 and phase < 5.0 else 0.0
		green = 3.0 if phase >= 5.0 else 0.0
	elif mood == StoryShot.Mood.OUTBREAK or mood == StoryShot.Mood.DEAD:
		yellow = 3.0 if fmod(_signal_time, 1.2) < 0.6 else 0.0
	_signal_materials[0].emission_energy_multiplier = red
	_signal_materials[1].emission_energy_multiplier = yellow
	_signal_materials[2].emission_energy_multiplier = green


# ---------- Настроения ----------

## Живой город: прохожие, болтающие люди, бегун, собака, машины в обе стороны
func _build_living() -> void:
	for i in 16:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var forward: bool = i % 4 < 2
		var z: float = side * (SIDEWALK_Z + _rng.randf_range(-0.9, 0.9))
		var from := Vector3(-STREET_HALF + 4.0 if forward else STREET_HALF - 4.0, 0.0, z)
		var to := Vector3(STREET_HALF - 4.0 if forward else -STREET_HALF + 4.0, 0.0, z)
		_add_person(PackedVector3Array([from, to]), _rng.randf_range(1.1, 1.6), false, _rng.randf())
	# Трое болтают у кафе
	for i in 3:
		var at := Vector3(-14.0 + i * 0.9, 0.0, 7.0 + (0.6 if i == 1 else 0.0))
		var person: StageActor = _add_person(PackedVector3Array([at]), 0.0, false, 0.0, true)
		if person != null:
			person.rotation.y = [-PI * 0.5, PI, PI * 0.5][i]
			person.play([&"Wave", &"Yes", &"No"][i])
	# Бегун в наушниках — бежит по кругу; хозяин с собакой
	_add_person(PackedVector3Array([Vector3(STREET_HALF - 4.0, 0, -7.2), Vector3(-STREET_HALF + 4.0, 0, -7.2)]),
		3.4, true, 0.4)
	_add_person(PackedVector3Array([Vector3(-30, 0, 5.8), Vector3(30, 0, 5.8)]), 1.2, false, 0.25)
	_add_actor(_load(DOG), 0.55, PackedVector3Array([Vector3(-29, 0, 5.2), Vector3(31, 0, 5.2)]), 1.2,
		&"Walk", &"Idle", 0.25)
	# Машины: по полосе в каждую сторону и по поперечной улице
	for i in 8:
		var east: bool = i % 2 == 0
		var lane: float = 2.0 if east else -2.0
		var route := PackedVector3Array([Vector3(-STREET_HALF if east else STREET_HALF, 0, lane),
			Vector3(STREET_HALF if east else -STREET_HALF, 0, lane)])
		var scene: PackedScene = _load(POLICE) if i == 5 else _load(CARS[i % CARS.size()])
		_add_car(scene, route, _rng.randf_range(8.0, 12.0), false, i / 8.0)
	for i in 2:
		var north: bool = i == 0
		var lane_x: float = -2.0 if north else 2.0
		var cross_route := PackedVector3Array([Vector3(lane_x, 0, -CROSS_HALF if north else CROSS_HALF),
			Vector3(lane_x, 0, CROSS_HALF if north else -CROSS_HALF)])
		_add_car(_load(CARS[(i + 3) % CARS.size()]), cross_route, 9.0, false, 0.3 + i * 0.4)


## Начало заражения: люди бегут по улице, за ними зомби; мигалки, разбитая машина, огонь
func _build_outbreak() -> void:
	for i in 12:
		var z: float = _rng.randf_range(-6.0, 6.0)
		var from := Vector3(_rng.randf_range(20.0, 45.0), 0.0, z)
		var to := Vector3(-STREET_HALF - 10.0, 0.0, z + _rng.randf_range(-2.0, 2.0))
		_add_person(PackedVector3Array([from, to]), _rng.randf_range(4.0, 5.2), true, 0.0)
	for i in 7:
		var z: float = _rng.randf_range(-5.0, 5.0)
		var from := Vector3(_rng.randf_range(32.0, 55.0), 0.0, z)
		var to := Vector3(-STREET_HALF - 10.0, 0.0, z)
		_add_actor(_load(ZOMBIES[i % ZOMBIES.size()]), 1.75, PackedVector3Array([from, to]),
			_rng.randf_range(3.4, 4.2), &"Run", &"Idle", 0.0)
	var police: StageCar = _add_car(_load(POLICE), PackedVector3Array(), 0.0, false, 0.0, 35.0,
		Color(0.1, 0.3, 1.0))
	if police != null:
		police.position = Vector3(3.0, 0.0, -3.0)
	var ambulance: StageCar = _add_car(_load(AMBULANCE), PackedVector3Array(), 0.0, false, 0.0, -70.0,
		Color(1.0, 1.0, 1.0))
	if ambulance != null:
		ambulance.position = Vector3(-9.0, 0.0, 2.5)
	var crashed: StageCar = _add_car(_load(CARS[0]), PackedVector3Array(), 0.0, false, 0.0, 120.0)
	if crashed != null:
		crashed.position = Vector3(6.0, 0.0, -6.0)
		_add_fire(Vector3(6.0, 0.8, -6.0), 1.0)
	_add_fire(Vector3(-24.0, 0.2, 14.0), 2.0)


## Мёртвый город: обгоревшие машины, обломки, кровь, медленные зомби, огонь в бочках
func _build_dead(quiet: bool = false) -> void:
	var wreck_spots: Array[Vector3] = [Vector3(-30, 0, 1.5), Vector3(-17, 0, -2.5), Vector3(8, 0, 2.0),
		Vector3(21, 0, -1.0), Vector3(36, 0, 2.5), Vector3(-2, 0, 14), Vector3(2, 0, -20), Vector3(-45, 0, -2)]
	for i in wreck_spots.size():
		var scene: PackedScene = _load(CARS[(i * 3) % CARS.size()]) if i % 3 != 0 else _load(POLICE)
		var wreck: StageCar = _add_car(scene, PackedVector3Array(), 0.0, true, 0.0, _rng.randf_range(-180.0, 180.0))
		if wreck != null:
			wreck.position = wreck_spots[i]
	for i in 18:
		var debris: PackedScene = _load(DEBRIS[i % DEBRIS.size()])
		_place_actor_prop(debris, Vector3(_rng.randf_range(-50, 50), 0.0, _rng.randf_range(-7, 7)), 1.0)
	for i in 6:
		_place_actor_prop(_load(BLOOD[i % BLOOD.size()]), Vector3(_rng.randf_range(-35, 35), 0.02, _rng.randf_range(-4, 4)), 1.5)
	_add_fire(Vector3(21.0, 0.9, -1.0), 1.2)
	_add_fire(Vector3(-17.0, 0.9, -2.5), 0.9)
	var count: int = 6 if quiet else 14
	for i in count:
		var start := Vector3(_rng.randf_range(-50.0, 50.0), 0.0, _rng.randf_range(-6.0, 6.0))
		var finish: Vector3 = start + Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-3.0, 3.0))
		var zombie: StageActor = _add_actor(_load(ZOMBIES[i % ZOMBIES.size()]), _rng.randf_range(1.65, 1.9),
			PackedVector3Array([start, finish, start]), _rng.randf_range(0.5, 0.9), &"Walk", &"Idle", _rng.randf())
		if zombie != null and i == 3:
			zombie.speed = 0.4
			zombie.move_anim = &"Crawl"
			zombie.play(&"Crawl")
	# Комичный зомби: упорно идёт в стену магазина, разворачивается и снова идёт
	_add_actor(_load(ZOMBIES[0]), 1.75, PackedVector3Array([Vector3(-6.5, 0, 9.2), Vector3(-6.5, 0, 11.6),
		Vector3(-6.5, 0, 9.2)]), 0.6, &"Walk", &"Idle", 0.0)


## Лагерь бандитов Барона у бочки с огнём на перекрёстке; пленник у грузовика; надпись на стене
func _build_bandits() -> void:
	var barrel: PackedScene = _load(BARREL)
	_place_actor_prop(barrel, Vector3.ZERO, 1.0)
	_add_fire(Vector3(0.0, 1.1, 0.0), 1.0)
	var guns: Array[String] = ["Pistol", "Shotgun", "SMG", "Rifle", "Pistol"]
	for i in 5:
		var angle: float = TAU * i / 5.0 + 0.3
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 2.4
		var bandit: StageActor = _add_actor(_load(PEOPLE_QUATERNIUS[(i + 1) % PEOPLE_QUATERNIUS.size()]),
			1.8, PackedVector3Array([at]), 0.0, &"Walk_Gun", &"Idle_Gun", 0.0, guns[i])
		if bandit != null:
			bandit.rotation.y = atan2(at.x, at.z)  # лицом к огню (актёр смотрит в -Z)
	# Барон — крупнее, с автоматом, у грузовика
	var baron: StageActor = _add_actor(_load(PEOPLE_QUATERNIUS[3]), 2.2,
		PackedVector3Array([Vector3(0.0, 0.0, -3.0)]), 0.0, &"Walk_Gun", &"Idle_Gun", 0.0, "SMG")
	if baron != null:
		baron.rotation.y = 0.0
	for i in 2:
		var patrol := PackedVector3Array([Vector3(-12 + i * 24, 0, -4), Vector3(-12 + i * 24, 0, 4)])
		_add_actor(_load(PEOPLE_QUATERNIUS[i]), 1.8, patrol, 1.2, &"Walk_Gun", &"Idle_Gun", 0.5, "Rifle")
	var truck: StageCar = _add_car(_load(ARMORED_TRUCK), PackedVector3Array(), 0.0, false, 0.0, 70.0)
	if truck != null:
		truck.position = Vector3(-6.0, 0.0, -9.0)
	var captive: StageActor = _add_actor(_load(PEOPLE_QUATERNIUS[0]), 1.7,
		PackedVector3Array([Vector3(-3.0, 0.0, -9.5)]), 0.0, &"Idle", &"Duck", 0.0)
	if captive != null:
		captive.rotation.y = PI
	var graffiti := Label3D.new()
	graffiti.text = "ТЕРРИТОРИЯ БАРОНА"
	graffiti.font_size = 120
	graffiti.outline_size = 0
	graffiti.pixel_size = 0.012
	graffiti.modulate = Color(0.85, 0.1, 0.05)
	graffiti.position = Vector3(-6.0, 4.0, -BUILDING_Z + 5.4)
	_actors.add_child(graffiti)


## Рассвет: выжившие идут вместе по середине улицы, за ними медленно едет бронепикап
func _build_hope() -> void:
	for i in 9:
		var row: int = floori(i / 3.0)
		var column: int = i % 3
		var start := Vector3(14.0 + row * 1.8, 0.0, (column - 1) * 1.6)
		var finish := Vector3(-60.0, 0.0, start.z)
		_add_person(PackedVector3Array([start, finish]), 1.3, false, 0.0)
	_add_actor(_load(DOG), 0.55, PackedVector3Array([Vector3(12.5, 0, 1.0), Vector3(-60, 0, 1.0)]), 1.3,
		&"Walk", &"Idle", 0.0)
	_add_car(_load(ARMORED_PICKUP), PackedVector3Array([Vector3(24, 0, 0), Vector3(-60, 0, 0)]), 1.3, false,
		0.0, 0.0, Color(0.0, 0.0, 0.0, 0.0), true)
	# Обломки отодвинуты к обочинам
	for i in 6:
		var wreck: StageCar = _add_car(_load(CARS[i % CARS.size()]), PackedVector3Array(), 0.0, true, 0.0,
			_rng.randf_range(80.0, 100.0))
		if wreck != null:
			wreck.position = Vector3(-40.0 + i * 14.0, 0.0, 4.6 if i % 2 == 0 else -4.6)


## Ночной лагерь выживших на перекрёстке: костёр, палатки, люди сидят у огня, собака, броневики
func _build_camp() -> void:
	_place_camp_prop("campfire-pit", Vector3.ZERO, 0.0)
	_place_camp_prop("campfire-stand", Vector3.ZERO, 0.0)
	_add_fire(Vector3(0.0, 0.15, 0.0), 0.8)
	_place_camp_prop("tent-canvas", Vector3(-5.0, 0.0, -4.0), 0.5)
	_place_camp_prop("tent", Vector3(5.0, 0.0, -4.5), -0.5)
	_place_camp_prop("tent-canvas", Vector3(0.0, 0.0, -6.5), 0.0)
	_place_camp_prop("box-large", Vector3(3.6, 0.0, 1.8), 0.4)
	_place_camp_prop("barrel", Vector3(-3.8, 0.0, 2.2), 0.0)
	_place_camp_prop("bedroll", Vector3(-2.8, 0.0, -2.6), 0.9)
	# Сидят у огня (Kenney «sit»), лицом к костру
	for i in 6:
		var angle: float = TAU * i / 6.0 + 0.4
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 2.1
		var scene: PackedScene = _load(PEOPLE_KENNEY[(i * 2) % PEOPLE_KENNEY.size()])
		var person: StageActor = _add_actor(scene, 1.7, PackedVector3Array([at]), 0.0, &"walk", &"sit", 0.0)
		if person != null:
			person.rotation.y = atan2(at.x, at.z)  # актёр смотрит в -Z — к огню
	# Часовой с винтовкой ходит по краю
	_add_actor(_load(PEOPLE_QUATERNIUS[2]), 1.8, PackedVector3Array([Vector3(-9, 0, 5), Vector3(9, 0, 5)]), 1.0,
		&"Walk_Gun", &"Idle_Gun", 0.3, "Rifle")
	_add_actor(_load(DOG), 0.55, PackedVector3Array([Vector3(1.2, 0.0, 2.6)]), 0.0, &"Walk", &"Idle", 0.0)
	var truck: StageCar = _add_car(_load(ARMORED_TRUCK), PackedVector3Array(), 0.0, false, 0.0, 70.0)
	if truck != null:
		truck.position = Vector3(-8.0, 0.0, -9.0)
	var pickup: StageCar = _add_car(_load(ARMORED_PICKUP), PackedVector3Array(), 0.0, false, 0.0, -60.0)
	if pickup != null:
		pickup.position = Vector3(8.5, 0.0, -8.0)


func _place_camp_prop(model: String, at: Vector3, yaw: float) -> void:
	var scene: PackedScene = _load(CAMP_DIR + model + ".glb")
	if scene == null:
		return
	var prop := scene.instantiate() as Node3D
	if prop == null:
		return
	prop.position = at
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * CAMP_SCALE
	_actors.add_child(prop)


# ---------- Актёры ----------

## Житель: Kenney или Quaternius (у них разные имена анимаций)
func _add_person(route: PackedVector3Array, walk_speed: float, running: bool, start_t: float,
		quaternius: bool = false) -> StageActor:
	var use_quaternius: bool = quaternius or _rng.randf() < 0.35
	if use_quaternius:
		var scene: PackedScene = _load(PEOPLE_QUATERNIUS[_rng.randi() % PEOPLE_QUATERNIUS.size()])
		return _add_actor(scene, _rng.randf_range(1.65, 1.85), route, walk_speed,
			&"Run" if running else &"Walk", &"Idle", start_t)
	var kenney: PackedScene = _load(PEOPLE_KENNEY[_rng.randi() % PEOPLE_KENNEY.size()])
	return _add_actor(kenney, _rng.randf_range(1.6, 1.85), route, walk_speed,
		&"sprint" if running else &"walk", &"idle", start_t)


func _add_actor(scene: PackedScene, height: float, route: PackedVector3Array, walk_speed: float,
		walk_anim: StringName, stand_anim: StringName, start_t: float, weapon: String = "") -> StageActor:
	if scene == null:
		return null
	var actor := StageActor.create(scene, height, route, walk_speed, walk_anim, stand_anim, start_t)
	actor.held_weapon = weapon
	_actors.add_child(actor)
	return actor


## Машина настроения; flasher — цвет мигалки (прозрачный — нет), lights — фары
func _add_car(scene: PackedScene, route: PackedVector3Array, drive_speed: float, burnt: bool, start_t: float,
		yaw_degrees: float = 0.0, flasher: Color = Color(0.0, 0.0, 0.0, 0.0), lights: bool = false) -> StageCar:
	if scene == null:
		return null
	var car := StageCar.create(scene, route, drive_speed, yaw_degrees, burnt, start_t)
	car.flasher = flasher
	car.headlights = lights
	_actors.add_child(car)
	return car


func _add_fire(at: Vector3, size_scale: float) -> void:
	var flames := GraveyardBuilder.make_flames()
	flames.position = at
	flames.scale = Vector3.ONE * size_scale
	_actors.add_child(flames)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.5 * size_scale
	light.omni_range = 9.0 * size_scale
	light.position = at + Vector3.UP * 0.6
	light.shadow_enabled = false
	_actors.add_child(light)
	_flames.append(flames)


## Неподвижная мелочь настроения (мусор, обломки, кровь) — меняется вместе с настроением
func _place_actor_prop(scene: PackedScene, at: Vector3, scale_value: float) -> void:
	if scene == null:
		return
	var prop := scene.instantiate() as Node3D
	if prop == null:
		return
	prop.position = at
	prop.rotation.y = _rng.randf() * TAU
	prop.scale = Vector3.ONE * scale_value
	_actors.add_child(prop)


# ---------- Вспомогательное ----------

func _load(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("StoryStage: нет модели %s" % path)
	_scenes[path] = scene
	return scene


func _place(scene: PackedScene, at: Vector3, yaw: float, scale_value: float) -> Node3D:
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_value
	add_child(node)
	return node


## Модель по ширине: самая широкая горизонтальная сторона = width
func _place_fitted(scene: PackedScene, at: Vector3, yaw: float, width: float) -> void:
	var node: Node3D = _place(scene, at, yaw, 1.0)
	if node == null:
		return
	var bounds := AABB()
	var has_bounds: bool = false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != node:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		var mesh_bounds: AABB = xform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	var widest: float = maxf(bounds.size.x, bounds.size.z) if has_bounds else 0.0
	if widest > 0.01:
		node.scale = Vector3.ONE * (width / widest)
