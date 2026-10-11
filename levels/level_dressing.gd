class_name LevelDressing
extends Node3D
## Оформление общего уровня под рассказ главы: одна и та же улица становится больницей, курортом
## или подъездом к мосту. MissionData.dressing — имя набора (функция _set_<имя>), MissionData.time_of_day —
## день/закат/ночь/рассвет (небо, солнце, свет окружения, туман). Предметы ставятся на свободные места
## (не у точек спавна/подборов/обороны/игрока, не в стены и чужие коллизии — проверка физикой) через PropBatch;
## узел — ребёнок NavigationRegion3D, поэтому коллизии попадают в навмеш (он строится позже, RuntimeNavRegion).
## Ставит MissionManager (apply) в своём _ready; зерно случайности — id миссии (одинаково у всех по сети).

## Время суток: верх неба, горизонт, цвет солнца, сила, высота солнца°, цвет окружения, сила окружения, ночь (0..1)
const TIME_PRESETS: Dictionary = {
	MissionData.TimeOfDay.DAY: [Color(0.32, 0.52, 0.85), Color(0.72, 0.8, 0.88), Color(1.0, 0.96, 0.88), 1.15, 55.0,
		Color(0.7, 0.72, 0.74), 0.7, 0.0],
	MissionData.TimeOfDay.DUSK: [Color(0.22, 0.2, 0.38), Color(0.95, 0.55, 0.35), Color(1.0, 0.6, 0.38), 0.85, 12.0,
		Color(0.58, 0.46, 0.44), 0.6, 0.2],
	MissionData.TimeOfDay.NIGHT: [Color(0.02, 0.03, 0.08), Color(0.1, 0.13, 0.21), Color(0.55, 0.65, 0.95), 0.35, 40.0,
		Color(0.26, 0.3, 0.45), 0.5, 0.55],
	MissionData.TimeOfDay.DAWN: [Color(0.36, 0.46, 0.75), Color(1.0, 0.74, 0.56), Color(1.0, 0.8, 0.6), 0.95, 10.0,
		Color(0.66, 0.6, 0.56), 0.65, 0.1],
}
## Не ставить предметы ближе этого к точкам спавна, подборов, обороны и игрока
const KEEP_CLEAR: float = 3.2
const MARKET: String = "res://models/market/"
const FOOD: String = "res://models/food/"
const HOLIDAY: String = "res://models/holiday/"
const ROADS: String = "res://models/roads/"
const NATURE: String = "res://models/nature/"
const PIRATE: String = "res://models/harbor/pirate/"
const WATERCRAFT: String = "res://models/harbor/watercraft/"
const CARS: String = "res://models/vehicles/kenney/"
const VEHICLES: String = "res://models/vehicles/"
const ENV: String = "res://models/environment/"
const SURV: String = "res://models/survival/"
const GRAVE: String = "res://models/graveyard/"
const IND: String = "res://models/industrial/"
const FURNITURE: String = "res://models/furniture/"
## Машины Kenney Car Kit: ширина 1.5 → ~2.1 м
const CAR_SCALE: float = 1.4
const ROAD_KIT_SCALE: float = 8.0

var mission: MissionData

var _batch: PropBatch
var _rng := RandomNumberGenerator.new()
var _half := Vector2(26.0, 26.0)
var _keep: Array[Vector3] = []
var _taken: Array[Vector4] = []  # x, z, радиус, — занятые места без коллизии
var _scenes: Dictionary = {}
var _space: PhysicsDirectSpaceState3D
var _query := PhysicsShapeQueryParameters3D.new()
var _probe := BoxShape3D.new()
var _night: float = 0.0


## Оформить уровень под миссию (один раз)
static func apply(scene: Node, data: MissionData) -> void:
	if scene == null or data == null or scene.has_node(^"LevelDressing"):
		return
	if data.dressing == &"" and data.time_of_day == MissionData.TimeOfDay.SCENE:
		return
	var dressing := LevelDressing.new()
	dressing.name = "LevelDressing"
	dressing.mission = data
	# Ребёнок навмеш-региона: коллизии предметов учтутся при сборке навмеша
	var regions: Array[Node] = scene.find_children("*", "NavigationRegion3D", true, false)
	var parent: Node = regions[0] if not regions.is_empty() else scene
	parent.add_child(dressing)


func _ready() -> void:
	if mission == null:
		return
	_rng.seed = hash(mission.id)
	_measure_half()
	_collect_keep()
	_space = get_world_3d().direct_space_state
	_query.shape = _probe
	_query.collision_mask = PhysicsLayers.WORLD
	_apply_time()
	if mission.dressing == &"":
		return
	_batch = PropBatch.new(self)
	var method: StringName = StringName("_set_" + String(mission.dressing))
	if has_method(method):
		call(method)
	else:
		push_warning("%s: нет набора оформления «%s»" % [name, mission.dressing])
	_batch.build()


func _exit_tree() -> void:
	if _night > 0.0 and is_equal_approx(DayNightCycle.night_amount, _night):
		DayNightCycle.night_amount = 0.0


# ---------- Время суток ----------

func _apply_time() -> void:
	if not TIME_PRESETS.has(mission.time_of_day):
		return
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.find_children("*", "DayNightCycle", true, false).is_empty():
		return  # своя смена дня и ночи (город)
	var values: Array = TIME_PRESETS[mission.time_of_day]
	for node: Node in scene.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world.environment == null:
			continue
		var environment: Environment = world.environment.duplicate() as Environment
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = values[0]
		sky_material.sky_horizon_color = values[1]
		sky_material.ground_horizon_color = values[1]
		sky_material.ground_bottom_color = (values[1] as Color).darkened(0.6)
		var sky := Sky.new()
		sky.sky_material = sky_material
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = values[5]
		environment.ambient_light_energy = values[6]
		if environment.fog_enabled:
			environment.fog_light_color = (values[1] as Color).darkened(0.25)
			if mission.time_of_day == MissionData.TimeOfDay.DAY:
				environment.fog_density *= 0.5  # ясный день — дальше видно
		world.environment = environment
	for node: Node in scene.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		sun.light_color = values[2]
		sun.light_energy = values[3]
		sun.rotation.x = deg_to_rad(-float(values[4]))
	if mission.time_of_day == MissionData.TimeOfDay.NIGHT:
		# Ночью луч маяка (HarborBuilder) — ярче, днём он почти прозрачный
		for beam_root: Node in scene.find_children("LighthouseBeam", "Node3D", true, false):
			for beam: Node in beam_root.get_children():
				var mesh_instance := beam as MeshInstance3D
				var cone := mesh_instance.mesh as CylinderMesh if mesh_instance != null else null
				var beam_material := cone.material as StandardMaterial3D if cone != null else null
				if beam_material != null:
					beam_material.albedo_color.a = 0.22
	# Край карты (EdgeCover) красится под горизонт — взять новое небо
	var cover := scene.get_node_or_null(^"EdgeCover") as EdgeCover
	if cover != null:
		cover.refresh_environment()
	_night = values[7]
	if _night > 0.0:
		DayNightCycle.night_amount = _night  # фонарик сам зажигается ночью (Player._update_auto_torch)


# ---------- Свободные места ----------

func _measure_half() -> void:
	var scene: Node = get_tree().current_scene
	var bounds := scene.find_child("Bounds", true, false) as StaticBody3D if scene != null else null
	if bounds == null:
		return
	var half := Vector2.ZERO
	for child: Node in bounds.get_children():
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		var at: Vector3 = shape.global_position
		if absf(at.x) > absf(at.z):
			half.x = maxf(half.x, absf(at.x))
		else:
			half.y = maxf(half.y, absf(at.z))
	if half.x > 4.0 and half.y > 4.0:
		_half = half - Vector2(1.0, 1.0)


func _collect_keep() -> void:
	for group: StringName in [&"zombie_spawn", &"item_spawn", &"defend_point", &"player"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var node_3d := node as Node3D
			if node_3d != null:
				_keep.append(node_3d.global_position)


## Место свободно: не у важных точек, не на своих предметах без коллизий, физика не видит там стен/моделей
func _is_free(at: Vector3, radius: float) -> bool:
	if absf(at.x) > _half.x - radius or absf(at.z) > _half.y - radius:
		return false
	for keep: Vector3 in _keep:
		if Vector2(keep.x - at.x, keep.z - at.z).length() < KEEP_CLEAR + radius:
			return false
	for taken: Vector4 in _taken:
		if Vector2(taken.x - at.x, taken.y - at.z).length() < taken.z + radius:
			return false
	_probe.size = Vector3(radius * 2.0, 2.2, radius * 2.0)
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 1.4, at.z))
	return _space.intersect_shape(_query, 1).is_empty()


## Свободная точка: рядом с near (в пределах spread) или где угодно на площадке; INF — не нашлось
func _spot(radius: float, near: Vector3 = Vector3.INF, spread: float = 0.0) -> Vector3:
	for attempt in 40:
		var at: Vector3
		if near != Vector3.INF:
			var reach: float = spread * (0.3 + 0.7 * float(attempt) / 40.0)
			at = near + Vector3(_rng.randf_range(-reach, reach), 0.0, _rng.randf_range(-reach, reach))
		else:
			at = Vector3(_rng.randf_range(-_half.x, _half.x), 0.0, _rng.randf_range(-_half.y, _half.y))
		at.y = 0.0
		if _is_free(at, radius):
			return at
	return Vector3.INF


## Точка у стены: side 0 — север (-Z), 1 — юг, 2 — запад (-X), 3 — восток; t — доля вдоль стены (-1..1)
func _edge(side: int, t: float, inset: float) -> Vector3:
	match side:
		0:
			return Vector3(t * _half.x, 0.0, -_half.y + inset)
		1:
			return Vector3(t * _half.x, 0.0, _half.y - inset)
		2:
			return Vector3(-_half.x + inset, 0.0, t * _half.y)
		_:
			return Vector3(_half.x - inset, 0.0, t * _half.y)


func _edge_yaw(side: int) -> float:
	return [0.0, PI, PI * 0.5, -PI * 0.5][side]


# ---------- Постановка ----------

func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("%s: нет модели %s" % [name, path])
	_scenes[path] = scene
	return scene


## Модель в точке (с коллизией по габаритам); tint — перекрасить (альфа > 0)
func _put(path: String, at: Vector3, yaw: float, scale_value: float, collide: bool = true,
		tint: Color = Color(0, 0, 0, 0)) -> void:
	var scene: PackedScene = _scene(path)
	if scene == null or at == Vector3.INF:
		return
	var xform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value), at)
	var bounds: AABB = _batch.get_bounds(scene)
	var radius: float = maxf(bounds.size.x, bounds.size.z) * scale_value * 0.5
	if tint.a > 0.0:
		var node := scene.instantiate() as Node3D
		if node == null:
			return
		node.transform = xform
		_tint(node, tint)
		add_child(node)
		if collide:
			_batch.add_oriented_box(xform, bounds)
	else:
		_batch.add(scene, xform, collide)
	if not collide:
		_taken.append(Vector4(at.x, at.z, radius, 0.0))


## Найти место и поставить; вернуть точку (INF — не поместилось)
func _place(path: String, radius: float, scale_value: float, near: Vector3 = Vector3.INF, spread: float = 0.0,
		yaw: float = INF, collide: bool = true, tint: Color = Color(0, 0, 0, 0)) -> Vector3:
	var at: Vector3 = _spot(radius, near, spread)
	if at != Vector3.INF:
		_put(path, at, _rng.randf() * TAU if yaw == INF else yaw, scale_value, collide, tint)
	return at


func _scatter(paths: Array[String], count: int, radius: float, scale_range: Vector2, collide: bool = true,
		near: Vector3 = Vector3.INF, spread: float = 0.0) -> void:
	for i in count:
		_place(paths[i % paths.size()], radius, _rng.randf_range(scale_range.x, scale_range.y), near, spread, INF, collide)


## Ряд вдоль стены
func _edge_row(side: int, paths: Array[String], count: int, inset: float, radius: float, scale_value: float,
		collide: bool = true, yaw_offset: float = 0.0) -> void:
	for i in count:
		var t: float = -0.85 + 1.7 * (float(i) + 0.5) / float(count)
		var at: Vector3 = _edge(side, t, inset)
		if _is_free(at, radius):
			_put(paths[i % paths.size()], at, _edge_yaw(side) + yaw_offset, scale_value, collide)


func _tint(node: Node, color: Color) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D if source != null \
				else StandardMaterial3D.new()
			material.albedo_color = material.albedo_color * color
			mesh_instance.set_surface_override_material(surface, material)


func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 2.5
	return material


func _box(at: Vector3, box_size: Vector3, color: Color, collide: bool = false, emissive: bool = false,
		yaw: float = 0.0) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	box.material = _material(color, emissive)
	var part := MeshInstance3D.new()
	part.mesh = box
	part.position = at
	part.rotation.y = yaw
	add_child(part)
	if collide:
		_batch.add_oriented_box(Transform3D(Basis(Vector3.UP, yaw), at - Vector3.UP * box_size.y * 0.5),
			AABB(Vector3(-box_size.x * 0.5, 0.0, -box_size.z * 0.5), box_size))


func _light(at: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = at
	add_child(light)


func _fire(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	_put(ENV + "Barrel.gltf", at, 0.0, 1.0)
	var flames := GraveyardBuilder.make_flames()
	flames.position = at + Vector3.UP * 1.05
	add_child(flames)
	_light(at + Vector3.UP * 1.8, Color(1.0, 0.58, 0.25), 1.6, 8.0)


## Табличка-надпись (Label3D, переводится сама)
func _sign(text: String, at: Vector3, yaw: float, color: Color, font_size: int = 96) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 18
	label.pixel_size = 0.02
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.03, 0.02)
	label.shaded = false
	label.position = at
	label.rotation.y = yaw
	label.double_sided = false  # сзади надпись не видна (иначе читается задом наперёд)
	add_child(label)


## Медицинский крест на щите (белый щит, цветной крест)
func _cross_sign(at: Vector3, yaw: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(at, Vector3(2.2, 2.2, 0.15), Color(0.95, 0.95, 0.95), false, false, yaw)
	_box(at + basis * Vector3(0.0, 0.0, 0.1), Vector3(1.6, 0.5, 0.05), color, false, true, yaw)
	_box(at + basis * Vector3(0.0, 0.0, 0.1), Vector3(0.5, 1.6, 0.05), color, false, true, yaw)
	var post_height: float = maxf(at.y - 1.1, 0.2)
	_box(Vector3(at.x, post_height * 0.5, at.z), Vector3(0.15, post_height, 0.15), Color(0.3, 0.3, 0.32), false, false, yaw)


## Фасад здания у стены уровня (только вид, вплотную к невидимой стене): стена с окнами, дверь, вывеска.
## side — как в _edge; t — центр вдоль стены (-1..1); lit — часть окон светится (вечер, ночь)
func _facade(side: int, t: float, width: float, height: float, color: Color, text: String, text_color: Color,
		lit: bool = false) -> Vector3:
	var yaw: float = _edge_yaw(side)
	var basis := Basis(Vector3.UP, yaw)
	var base: Vector3 = _edge(side, t, 0.6)
	_box(base + Vector3.UP * height * 0.5, Vector3(width, height, 0.8), color, false, false, yaw)
	# Окна рядами (над первым этажом), дверь посередине
	var rows: int = maxi(int((height - 3.5) / 3.0), 1)
	var columns: int = maxi(int(width / 3.2), 2)
	for row in rows:
		for column in columns:
			var x: float = -width * 0.5 + width * (float(column) + 0.5) / float(columns)
			var y: float = 4.2 + row * 3.0
			if absf(x) < 1.6 and row == 0:
				continue
			var glow: bool = lit and _rng.randf() < 0.35
			_box(base + basis * Vector3(x, y, 0.42), Vector3(1.4, 1.6, 0.05),
				Color(1.0, 0.85, 0.55) if glow else Color(0.12, 0.16, 0.2), false, glow, yaw)
	_box(base + basis * Vector3(0.0, 1.3, 0.42), Vector3(2.2, 2.6, 0.05), Color(0.1, 0.1, 0.12), false, false, yaw)
	if not text.is_empty():
		_sign(text, base + basis * Vector3(0.0, 3.4, 0.5) , yaw, text_color, 110)
	_taken.append(Vector4(base.x, base.z, 1.5, 0.0))
	return base + basis * Vector3(0.0, 0.0, 2.5)


## Пляжный зонт: шест и купол
func _umbrella(at: Vector3, color: Color) -> void:
	if at == Vector3.INF:
		return
	_box(at + Vector3.UP * 1.2, Vector3(0.08, 2.4, 0.08), Color(0.9, 0.9, 0.9))
	var dome := CylinderMesh.new()
	dome.top_radius = 0.05
	dome.bottom_radius = 1.5
	dome.height = 0.5
	dome.radial_segments = 8
	dome.material = _material(color)
	var top := MeshInstance3D.new()
	top.mesh = dome
	top.position = at + Vector3.UP * 2.5
	add_child(top)
	_taken.append(Vector4(at.x, at.z, 0.8, 0.0))


## Гирлянда между двумя точками: провисающая цепочка светящихся лампочек и один свет посередине
func _garland(from: Vector3, to: Vector3, colors: Array[Color]) -> void:
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	bulb.radial_segments = 6
	bulb.rings = 3
	var count: int = maxi(int(from.distance_to(to) / 0.8), 2)
	for i in count + 1:
		var t: float = float(i) / float(count)
		var at: Vector3 = from.lerp(to, t) - Vector3.UP * sin(t * PI) * 0.8
		var lamp := MeshInstance3D.new()
		lamp.mesh = bulb
		lamp.material_override = _material(colors[i % colors.size()], true)
		lamp.position = at
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
	_light(from.lerp(to, 0.5) - Vector3.UP * 0.9, Color(1.0, 0.85, 0.6), 1.2, 9.0)


## Столб для гирлянды (вид + тонкая коллизия)
func _pole(at: Vector3, height: float) -> void:
	_box(at + Vector3.UP * height * 0.5, Vector3(0.15, height, 0.15), Color(0.35, 0.28, 0.2), true)


# ---------- Наборы (MissionData.dressing) ----------

## «Первый день»: стоянка у трассы — указатель трассы, брошенные машины, ящик с рацией
func _set_highway_yard() -> void:
	_put(ROADS + "sign-highway.glb", _spot(2.0, _edge(1, 0.3, 4.0), 6.0), PI * 0.5, ROAD_KIT_SCALE * 0.8)
	_scatter([CARS + "sedan.glb", CARS + "suv.glb", CARS + "van.glb"], 4, 2.4, Vector2(CAR_SCALE, CAR_SCALE))
	var crate: Vector3 = _place(PIRATE + "crate.glb", 1.0, 0.9)
	if crate != Vector3.INF:
		_put(FURNITURE + "radio.glb", crate + Vector3.UP * 0.7, 0.4, 2.0, false)
	_fire(_spot(1.0))


## «Улица молчания»: киоск мороженого с зонтом, лавочки, тележки, велосипедная мастерская (стойки)
func _set_quiet_street() -> void:
	_facade(0, -0.4, 16.0, 7.0, Color(0.75, 0.7, 0.62), "ВЕЛОМАСТЕРСКАЯ", Color(0.95, 0.85, 0.4))
	_facade(0, 0.45, 14.0, 7.0, Color(0.7, 0.62, 0.7), "ПРОДУКТЫ", Color(0.95, 0.55, 0.6))
	var kiosk: Vector3 = _place(MARKET + "freezer.glb", 1.4, 2.5)
	if kiosk != Vector3.INF:
		_umbrella(kiosk + Vector3(1.6, 0.0, 0.0), Color(0.95, 0.4, 0.55))
		_put(FOOD + "popsicle.glb", kiosk + Vector3(0.0, 0.9, 0.0), 0.0, 1.6, false)
		_sign("МОРОЖЕНОЕ", kiosk + Vector3(0.0, 3.0, 0.0), 0.0, Color(1.0, 0.75, 0.85), 72)
	_scatter([HOLIDAY + "bench.glb"], 5, 1.4, Vector2(1.8, 1.8))
	_scatter([MARKET + "shopping-cart.glb"], 3, 0.8, Vector2(2.4, 2.4), false)
	_scatter([FURNITURE + "pottedPlant.glb"], 4, 0.6, Vector2(2.2, 2.6))


## «Стервятники»: колонна беженцев, бронепикапы бандитов, красные флаги, бочки с огнём
func _set_convoy() -> void:
	for i in 5:
		var at: Vector3 = Vector3(-_half.x * 0.6 + i * 6.5, 0.0, _rng.randf_range(-2.0, 2.0))
		if _is_free(at, 2.4):
			_put(CARS + ["van.glb", "suv.glb", "sedan.glb", "delivery.glb", "truck.glb"][i], at, PI * 0.5, CAR_SCALE)
	_scatter([VEHICLES + "Vehicle_Pickup_Armored.gltf"], 2, 3.0, Vector2(1.0, 1.0))
	_scatter([PIRATE + "flag-pirate.glb"], 3, 0.8, Vector2(1.2, 1.2), false)
	for i in 3:
		_fire(_spot(1.0))


## «Логово Барона»: баррикада из машин, прожекторы, красная неоновая вывеска наоборот
func _set_baron() -> void:
	_edge_row(0, [CARS + "sedan.glb", CARS + "taxi.glb", CARS + "police.glb", CARS + "suv.glb"], 6, 5.0, 2.2,
		CAR_SCALE, true, PI * 0.5)
	_facade(0, 0.0, 34.0, 14.0, Color(0.55, 0.5, 0.48), "", Color.WHITE, true)
	_sign("ЙЫНЙЕЛИБЮ", _edge(0, 0.0, 1.5) + Vector3.UP * 11.0, 0.0, Color(1.0, 0.15, 0.1), 220)
	_light(_edge(0, 0.0, 3.0) + Vector3.UP * 6.0, Color(1.0, 0.2, 0.15), 2.0, 18.0)
	_scatter([ROADS + "construction-light.glb"], 4, 0.8, Vector2(ROAD_KIT_SCALE, ROAD_KIT_SCALE))
	_scatter([ROADS + "construction-barrier.glb"], 6, 1.0, Vector2(ROAD_KIT_SCALE, ROAD_KIT_SCALE))
	for i in 3:
		_fire(_spot(1.0))


## «Старый мост»: стальные фермы въезда на мост, перила, синий мамин шарф, брошенные машины
func _set_bridge() -> void:
	var steel := Color(0.35, 0.42, 0.5)
	for side: int in [0, 1]:
		var center: Vector3 = _edge(side, 0.0, 2.0)
		for x: float in [-6.0, 6.0]:
			_box(center + Vector3(x, 4.5, 0.0), Vector3(0.5, 9.0, 0.5), steel, true)
		_box(center + Vector3(0.0, 9.0, 0.0), Vector3(12.5, 0.5, 0.5), steel)
		_box(center + Vector3(-3.0, 6.8, 0.0), Vector3(6.6, 0.35, 0.35), steel, false, false, 0.0)
		_box(center + Vector3(3.0, 6.8, 0.0), Vector3(6.6, 0.35, 0.35), steel, false, false, 0.0)
	# Перила вдоль въезда и шарф на них
	for x: float in [-7.5, 7.5]:
		var from: Vector3 = _edge(0, 0.0, 2.0) + Vector3(x, 0.0, 0.0)
		var rail_length: float = 10.0
		_box(from + Vector3(0.0, 1.0, rail_length * 0.5), Vector3(0.12, 0.12, rail_length), steel)
		_box(from + Vector3(0.0, 0.5, rail_length * 0.5), Vector3(0.1, 1.0, 0.1), steel)
	_box(_edge(0, 0.0, 2.0) + Vector3(-7.5, 0.85, 4.0), Vector3(0.05, 0.6, 0.35), Color(0.2, 0.35, 0.9))
	_scatter([CARS + "sedan.glb", CARS + "van.glb", CARS + "taxi.glb"], 4, 2.4, Vector2(CAR_SCALE, CAR_SCALE))


## «Переправа»: затор у моста — автобус (длинный фургон), грузовики, дом на колёсах с гномами
func _set_crossing() -> void:
	var line_z: float = _rng.randf_range(-4.0, 4.0)
	var x: float = -_half.x * 0.7
	var index: int = 0
	while x < _half.x * 0.7:
		var at := Vector3(x, 0.0, line_z + _rng.randf_range(-1.5, 1.5))
		if _is_free(at, 2.6):
			var path: String = [CARS + "delivery.glb", CARS + "truck.glb", CARS + "van.glb", CARS + "garbage-truck.glb"][index % 4]
			var tint: Color = Color(1.0, 0.95, 0.6) if index == 2 else Color(0, 0, 0, 0)
			_put(path, at, PI * 0.5 + _rng.randf_range(-0.3, 0.3), CAR_SCALE * (1.25 if index == 0 else 1.0), true, tint)
			if index == 2:
				# Гномы на крыше дома на колёсах
				for g in 3:
					_put(HOLIDAY + "nutcracker.glb", at + Vector3(-0.8 + g * 0.8, 2.0, 0.0), PI * 0.5, 1.0, false)
			index += 1
		x += 7.0
	_scatter([ROADS + "construction-barrier.glb"], 5, 1.0, Vector2(ROAD_KIT_SCALE, ROAD_KIT_SCALE))
	_scatter([ROADS + "road-sign-warning.glb"], 2, 0.6, Vector2(5.0, 5.0))


## «Рецепт вакцины»: аптечный склад — стеллажи с коробками, зелёный крест, кассы
func _set_pharmacy() -> void:
	_facade(0, -0.3, 22.0, 8.0, Color(0.85, 0.9, 0.86), "АПТЕЧНЫЙ СКЛАД", Color(0.15, 0.75, 0.3))
	var store: Vector3 = _spot(4.0, _edge(0, -0.3, 6.0), 8.0)
	if store != Vector3.INF:
		for i in 4:
			_put(MARKET + ("shelf-boxes.glb" if i % 2 == 0 else "shelf-bags.glb"), store + Vector3(-3.0 + i * 2.0, 0.0, 0.0),
				0.0, 2.3)
		_put(MARKET + "cash-register.glb", store + Vector3(0.0, 0.0, 3.0), PI, 2.0)
		_cross_sign(store + Vector3(0.0, 4.2, -1.5), 0.0, Color(0.15, 0.8, 0.3))
	_scatter([SURV + "box-large.glb", SURV + "box.glb"], 8, 1.0, Vector2(2.6, 3.2))


## «Больница»: машины скорой у входа, красные кресты, медицинские палатки, ограждения
func _set_hospital() -> void:
	_facade(0, 0.0, 30.0, 13.0, Color(0.88, 0.88, 0.84), "ГОРОДСКАЯ БОЛЬНИЦА №1", Color(0.9, 0.15, 0.15), true)
	var entrance: Vector3 = _spot(5.0, _edge(0, 0.0, 6.0), 10.0)
	if entrance != Vector3.INF:
		_cross_sign(entrance + Vector3(0.0, 4.2, -3.0), 0.0, Color(0.85, 0.1, 0.1))
		_light(entrance + Vector3(0.0, 3.0, -1.0), Color(1.0, 0.3, 0.25), 1.2, 8.0)
	_scatter([CARS + "ambulance.glb"], 3, 2.4, Vector2(CAR_SCALE, CAR_SCALE))
	_place(CARS + "police.glb", 2.4, CAR_SCALE)
	_scatter([NATURE + "tent_detailedOpen.glb"], 3, 2.0, Vector2(3.4, 3.4), true, Vector3.INF, 0.0)
	_scatter([ROADS + "construction-barrier.glb"], 6, 1.0, Vector2(ROAD_KIT_SCALE, ROAD_KIT_SCALE))
	_scatter([SURV + "box.glb"], 5, 0.8, Vector2(2.6, 2.6))


## «Курорт «Чайка»» (порт днём): пальмы, песок, пляжные зонты, лежаки, киоск мороженого и коктейли
func _set_resort() -> void:
	var colors: Array[Color] = [Color(0.95, 0.3, 0.3), Color(0.25, 0.6, 0.95), Color(1.0, 0.85, 0.2), Color(0.3, 0.85, 0.5)]
	for i in 8:
		_place(PIRATE + ["palm-straight.glb", "palm-bend.glb", "palm-detailed-straight.glb"][i % 3], 1.4, 1.4)
	for i in 4:
		var sand: Vector3 = _spot(3.5)
		if sand != Vector3.INF:
			_put(PIRATE + "patch-sand.glb", sand + Vector3.UP * -0.2, _rng.randf() * TAU, 0.9, false)
			_umbrella(sand + Vector3(1.0, 0.0, 0.5), colors[i % colors.size()])
			_put(HOLIDAY + "bench.glb", sand + Vector3(-1.2, 0.0, -0.6), _rng.randf() * TAU, 1.6)
	_facade(1, 0.3, 20.0, 7.0, Color(0.95, 0.88, 0.7), "КАФЕ «ЧАЙКА»", Color(0.1, 0.45, 0.9))
	var kiosk: Vector3 = _place(MARKET + "freezer.glb", 1.4, 2.5)
	if kiosk != Vector3.INF:
		_umbrella(kiosk + Vector3(1.6, 0.0, 0.0), Color(0.95, 0.45, 0.7))
		_put(FOOD + "ice-cream.glb", kiosk + Vector3(0.0, 0.9, 0.0), 0.0, 2.0, false)
		_sign("МОРОЖЕНОЕ", kiosk + Vector3(0.0, 3.0, 0.0), 0.0, Color(1.0, 0.75, 0.85), 72)
	var bar: Vector3 = _place(FURNITURE + "table.glb", 1.2, 2.4)
	if bar != Vector3.INF:
		for c in 3:
			_put(FOOD + "cocktail.glb", bar + Vector3(-0.6 + c * 0.6, 0.8, 0.0), 0.0, 0.8, false)
	# Розовый автобус «Ласточка» с пальмами
	_place(CARS + "delivery.glb", 2.6, CAR_SCALE * 1.3, Vector3.INF, 0.0, INF, true, Color(1.0, 0.55, 0.75))


## «Холодная цепь»: хладокомбинат — ряды морозильников, иней, сугробы, ящики мороженого
func _set_cold() -> void:
	_facade(0, 0.2, 26.0, 10.0, Color(0.82, 0.86, 0.92), "ХЛАДОКОМБИНАТ №3", Color(0.35, 0.65, 1.0))
	var hall: Vector3 = _spot(5.0, Vector3.ZERO, 14.0)
	if hall != Vector3.INF:
		for row in 2:
			for i in 4:
				_put(MARKET + "freezers-standing.glb", hall + Vector3(-3.6 + i * 2.4, 0.0, row * 3.4), PI * row, 2.2)
		_light(hall + Vector3(0.0, 3.5, 1.7), Color(0.6, 0.8, 1.0), 1.4, 12.0)
	_scatter([MARKET + "freezer.glb"], 5, 1.2, Vector2(2.5, 2.5))
	_scatter([HOLIDAY + "snow-pile.glb", HOLIDAY + "snow-flat-large.glb"], 10, 1.6, Vector2(2.0, 2.6), false)
	_scatter([PIRATE + "crate.glb"], 5, 0.9, Vector2(0.9, 0.9))
	_scatter([FOOD + "popsicle.glb"], 4, 0.4, Vector2(2.5, 2.5), false)


## «По следу Кабана»: база банды — бронегрузовик с сиреной «Ревун», флаги, палатки, костры
func _set_kaban_base() -> void:
	var truck: Vector3 = _place(VEHICLES + "Vehicle_Truck_Armored.gltf", 3.5, 1.0, Vector3.ZERO, 12.0, 0.4)
	if truck != Vector3.INF:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.9
		horn.bottom_radius = 0.25
		horn.height = 1.4
		horn.material = _material(Color(0.75, 0.2, 0.15))
		var siren := MeshInstance3D.new()
		siren.mesh = horn
		siren.position = truck + Vector3(0.0, 3.6, 0.0)
		siren.rotation = Vector3(0.0, 0.4, PI * 0.5)
		add_child(siren)
		_sign("РЕВУН", truck + Vector3(0.0, 5.2, 0.0), 0.4, Color(1.0, 0.25, 0.15), 80)
	_scatter([PIRATE + "flag-pirate.glb"], 4, 0.8, Vector2(1.3, 1.3), false)
	_scatter([NATURE + "tent_detailedOpen.glb"], 3, 2.0, Vector2(3.4, 3.4))
	_scatter([ROADS + "dumpster.glb"], 2, 1.6, Vector2(6.0, 6.0))
	for i in 3:
		_fire(_spot(1.0))


## «Портовые склады»: портальный кран, штабеля морских контейнеров, ящики бананов
func _set_port_depot() -> void:
	var crane: Vector3 = _spot(5.5, _edge(0, 0.4, 7.0), 8.0)
	if crane != Vector3.INF:
		for leg: Vector3 in HarborBuilder.make_crane(self, crane, 14.0, crane.z - 4.0):
			_batch.add_box(leg, Vector3(0.7, 14.0, 0.7))
		_taken.append(Vector4(crane.x, crane.z, 5.0, 0.0))
	for i in 6:
		var at: Vector3 = _spot(3.4)
		if at == Vector3.INF:
			continue
		var yaw: float = _rng.randf() * TAU
		var path: String = WATERCRAFT + "cargo-container-%s.glb" % ["a", "b", "c"][i % 3]
		_put(path, at, yaw, 2.2)
		if i % 2 == 0:
			_put(WATERCRAFT + "cargo-container-%s.glb" % ["b", "c", "a"][i % 3], at + Vector3.UP * 2.43, yaw, 2.2, false)
	for i in 4:
		var crate: Vector3 = _place(PIRATE + "crate.glb", 0.9, 0.9)
		if crate != Vector3.INF:
			_put(FOOD + "banana.glb", crate + Vector3.UP * 0.75, _rng.randf() * TAU, 0.6, false)


## «Промзона»: заправка рабочих — колонки, навес, цистерны
func _set_gas_station() -> void:
	var station: Vector3 = _spot(5.0, Vector3.ZERO, 12.0)
	if station != Vector3.INF:
		for i in 2:
			var pump: Vector3 = station + Vector3(-2.0 + i * 4.0, 0.0, 0.0)
			_box(pump + Vector3.UP * 0.9, Vector3(0.8, 1.8, 0.6), Color(0.9, 0.2, 0.15), true)
			_box(pump + Vector3(0.0, 1.5, 0.31), Vector3(0.5, 0.3, 0.02), Color(0.3, 0.9, 0.4), false, true)
		for corner: Vector2 in [Vector2(-3.5, -2.0), Vector2(3.5, -2.0), Vector2(-3.5, 2.0), Vector2(3.5, 2.0)]:
			_box(station + Vector3(corner.x, 2.2, corner.y), Vector3(0.25, 4.4, 0.25), Color(0.85, 0.85, 0.85), true)
		_box(station + Vector3(0.0, 4.5, 0.0), Vector3(8.0, 0.3, 5.0), Color(0.9, 0.9, 0.9))
		_box(station + Vector3(0.0, 4.75, 2.55), Vector3(8.0, 0.5, 0.1), Color(0.95, 0.5, 0.1), false, true)
		_light(station + Vector3(0.0, 4.0, 0.0), Color(1.0, 0.95, 0.85), 1.2, 10.0)
	_scatter([IND + "detail-tank.glb"], 3, 2.2, Vector2(4.2, 4.6))


## «Источник»: гнездо в цехах «Генома» — светящиеся зелёные колбы и пульсирующие наросты
func _set_nest() -> void:
	for i in 5:
		var at: Vector3 = _spot(1.2)
		if at == Vector3.INF:
			continue
		var tank := CylinderMesh.new()
		tank.top_radius = 0.8
		tank.bottom_radius = 0.8
		tank.height = 2.8
		var glass := _material(Color(0.25, 1.0, 0.35, 0.55), true)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tank.material = glass
		var tube := MeshInstance3D.new()
		tube.mesh = tank
		tube.position = at + Vector3.UP * 1.4
		add_child(tube)
		_batch.add_box(at + Vector3.UP * 1.4, Vector3(1.6, 2.8, 1.6))
		_light(at + Vector3.UP * 2.0, Color(0.3, 1.0, 0.4), 1.2, 7.0)
	for i in 10:
		var at: Vector3 = _spot(1.0)
		if at == Vector3.INF:
			continue
		var blob := SphereMesh.new()
		var size: float = _rng.randf_range(0.6, 1.4)
		blob.radius = size
		blob.height = size * 1.4
		blob.material = _material(Color(0.55, 0.08, 0.12), true)
		var growth := MeshInstance3D.new()
		growth.mesh = blob
		growth.position = at + Vector3.UP * size * 0.4
		add_child(growth)
		_taken.append(Vector4(at.x, at.z, size, 0.0))
		var pulse: Tween = growth.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(growth, ^"scale", Vector3.ONE * 1.12, 0.9 + _rng.randf() * 0.6)
		pulse.tween_property(growth, ^"scale", Vector3.ONE, 0.9 + _rng.randf() * 0.6)


## «Осада» и «Крыса»-ночь у лагеря: баррикады у ворот, мешки, бочки с огнём, сигнальные огни
func _set_camp_gate() -> void:
	_edge_row(1, [SURV + "fence-fortified.glb"], 7, 4.0, 1.6, 3.4)
	for i in 8:
		var at: Vector3 = _spot(0.8)
		if at != Vector3.INF:
			_box(at + Vector3.UP * 0.35, Vector3(1.4, 0.7, 0.6), Color(0.6, 0.55, 0.4), true, false, _rng.randf() * TAU)
	for i in 4:
		_fire(_spot(1.0))
	for i in 3:
		var flare: Vector3 = _spot(0.5)
		if flare != Vector3.INF:
			_light(flare + Vector3.UP * 0.4, Color(1.0, 0.15, 0.1), 1.8, 7.0)
			_box(flare + Vector3.UP * 0.1, Vector3(0.12, 0.2, 0.12), Color(1.0, 0.2, 0.1), false, true)


## «Праздник»: кофейный фестиваль — гирлянды на столбах, столы с тортом и кружками, кофемашина, подарки
func _set_festival() -> void:
	var colors: Array[Color] = [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3), Color(0.3, 0.9, 0.4), Color(0.35, 0.6, 1.0)]
	var center: Vector3 = _spot(5.0, Vector3.ZERO, 10.0)
	if center == Vector3.INF:
		center = Vector3.ZERO
	var poles: Array[Vector3] = []
	for i in 6:
		var angle: float = TAU * i / 6.0
		poles.append(center + Vector3(cos(angle), 0.0, sin(angle)) * 7.0)
	for pole: Vector3 in poles:
		_pole(pole, 4.0)
	for i in poles.size():
		_garland(poles[i] + Vector3.UP * 4.0, poles[(i + 1) % poles.size()] + Vector3.UP * 4.0, colors)
	for i in 3:
		var table: Vector3 = _spot(1.4, center, 5.0)
		if table == Vector3.INF:
			continue
		_put(FURNITURE + "table.glb", table, _rng.randf() * TAU, 2.4)
		var top: Vector3 = table + Vector3.UP * 0.8
		if i == 0:
			_put(FURNITURE + "kitchenCoffeeMachine.glb", top, 0.0, 2.4, false)
		elif i == 1:
			_put(FOOD + "cake-birthday.glb", top, 0.0, 0.9, false)
		for c in 3:
			_put(FOOD + "mug.glb", top + Vector3(-0.6 + c * 0.6, 0.0, 0.35), _rng.randf() * TAU, 0.6, false)
	_scatter([HOLIDAY + "present-a-cube.glb"], 6, 0.5, Vector2(1.4, 1.8), false, center, 8.0)
	_fire(_spot(1.0, center, 4.0))


## «Домой»: всё вместе — баррикады, гирлянды, костры, маяк-огонь на флагштоке
func _set_home() -> void:
	_set_camp_gate()
	var colors: Array[Color] = [Color(1.0, 0.85, 0.3), Color(1.0, 0.4, 0.3)]
	var a: Vector3 = _spot(0.6, Vector3.ZERO, 10.0)
	var b: Vector3 = _spot(0.6, Vector3(8.0, 0.0, 0.0), 10.0)
	if a != Vector3.INF and b != Vector3.INF:
		_pole(a, 4.0)
		_pole(b, 4.0)
		_garland(a + Vector3.UP * 4.0, b + Vector3.UP * 4.0, colors)
	_scatter([PIRATE + "flag-high.glb"], 2, 0.6, Vector2(1.2, 1.2), false)


## «Крыса»: розовый спорткар Кабана с фарами, фонари бандитов между контейнерами
func _set_rat() -> void:
	var car: Vector3 = _place(CARS + "hatchback-sports.glb", 2.2, CAR_SCALE, Vector3.INF, 0.0, INF, true, Color(1.0, 0.55, 0.8))
	if car != Vector3.INF:
		_light(car + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.95, 0.8), 1.5, 10.0)
	for i in 4:
		var lamp: Vector3 = _place(ROADS + "construction-light.glb", 0.6, ROAD_KIT_SCALE)
		if lamp != Vector3.INF:
			_light(lamp + Vector3.UP * 2.0, Color(1.0, 0.9, 0.7), 1.0, 8.0)
	_sign("№7", _edge(0, 0.2, 1.5) + Vector3.UP * 3.0, 0.0, Color(1.0, 0.9, 0.3), 120)


## «Голоса с юга»: вышка связи у точки обороны (как в кино)
func _set_radio_tower() -> void:
	var defend: Vector3 = Vector3.ZERO
	var points: Array[Node] = get_tree().get_nodes_in_group(&"defend_point")
	if not points.is_empty():
		defend = (points[0] as Node3D).global_position
	var base: Vector3 = _spot(2.0, defend + Vector3(0.0, 0.0, -6.0), 6.0)
	if base == Vector3.INF:
		return
	base.y = 0.0
	StageLocations._radio_tower(self, base, 22.0)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_batch.add_box(base + Vector3(corner.x * 1.6, 11.0, corner.y * 1.6), Vector3(0.35, 22.0, 0.35))
	_taken.append(Vector4(base.x, base.z, 2.2, 0.0))
	_put(FURNITURE + "radio.glb", base + Vector3(2.4, 0.0, 0.0), 0.0, 3.0, false)


## «Дорога на юг»: трасса через лес — асфальт, фура «Мороженое», машины колонны, указатель
func _set_highway() -> void:
	var road := BoxMesh.new()
	road.size = Vector3(_half.x * 2.0, 0.04, 7.0)
	road.material = _material(Color(0.22, 0.22, 0.23))
	var asphalt := MeshInstance3D.new()
	asphalt.mesh = road
	asphalt.position = Vector3(0.0, 0.02, 0.0)
	add_child(asphalt)
	var line := BoxMesh.new()
	line.size = Vector3(_half.x * 2.0, 0.05, 0.15)
	line.material = _material(Color(0.95, 0.9, 0.7))
	var marking := MeshInstance3D.new()
	marking.mesh = line
	marking.position = Vector3(0.0, 0.03, 0.0)
	add_child(marking)
	var truck: Vector3 = _place(VEHICLES + "Vehicle_Truck.gltf", 3.0, 1.0, Vector3(6.0, 0.0, 5.5), 4.0, PI * 0.5)
	if truck != Vector3.INF:
		_sign("МОРОЖЕНОЕ", truck + Vector3(0.0, 3.6, 0.0), PI * 0.5, Color(1.0, 0.75, 0.85), 72)
		_put(FOOD + "popsicle.glb", truck + Vector3(0.0, 2.9, 0.0), 0.0, 2.2, false)
	for i in 3:
		_place(CARS + ["suv.glb", "van.glb", "sedan.glb"][i], 2.4, CAR_SCALE, Vector3(-6.0 - i * 6.0, 0.0, -1.5), 3.0, PI * 0.5)
	_put(ROADS + "sign-highway.glb", _spot(1.6, Vector3(_half.x - 5.0, 0.0, -5.0), 3.0), PI * 0.5, ROAD_KIT_SCALE * 0.8)


## «Голос мамы»: станция скорой у кладбища — машина скорой, домик, белые страницы дневника на земле
func _set_ambulance_station() -> void:
	var station: Vector3 = _spot(4.0, _edge(1, 0.5, 6.0), 8.0)
	if station != Vector3.INF:
		_box(station + Vector3(0.0, 1.6, -1.0), Vector3(6.0, 3.2, 4.0), Color(0.85, 0.85, 0.8), true)
		_cross_sign(station + Vector3(0.0, 4.4, -1.0), 0.0, Color(0.85, 0.1, 0.1))
		_light(station + Vector3(0.0, 3.0, 1.5), Color(1.0, 0.9, 0.7), 1.0, 8.0)
		_put(CARS + "ambulance.glb", station + Vector3(4.5, 0.0, 1.5), 0.3, CAR_SCALE)
	for i in 14:
		var at: Vector3 = _spot(0.2)
		if at != Vector3.INF:
			_box(at + Vector3.UP * 0.02, Vector3(0.3, 0.01, 0.42), Color(0.95, 0.93, 0.85), false, false, _rng.randf() * TAU)


## «Горный перевал»: розовый курортный автобус в сугробе, снеговик, сани
func _set_pink_bus() -> void:
	var bus: Vector3 = _place(CARS + "delivery.glb", 2.8, CAR_SCALE * 1.3, Vector3(0.0, 0.0, 6.0), 6.0, 0.15, true,
		Color(1.0, 0.55, 0.75))
	if bus != Vector3.INF:
		_put(HOLIDAY + "snow-pile.glb", bus + Vector3(1.2, 0.0, 1.6), 0.0, 3.0, false)
		_put(HOLIDAY + "snow-pile.glb", bus + Vector3(-1.4, 0.0, -1.5), 1.0, 3.0, false)
	_place(HOLIDAY + "snowman.glb", 1.0, 1.7)
	_place(HOLIDAY + "sled.glb", 0.8, 1.6, Vector3.INF, 0.0, INF, false)
	_scatter([HOLIDAY + "tree-snow-a.glb", HOLIDAY + "tree-snow-b.glb", HOLIDAY + "tree-snow-c.glb"], 8, 1.4, Vector2(2.6, 3.4))


## «Верхние Ключи»: очередь на прививку у ворот — столы, ящики, фонари, снежные ёлки
func _set_village_queue() -> void:
	var gate: Vector3 = Vector3.ZERO
	var points: Array[Node] = get_tree().get_nodes_in_group(&"defend_point")
	if not points.is_empty():
		gate = (points[0] as Node3D).global_position
	for i in 2:
		var table: Vector3 = _spot(1.3, gate + Vector3(-5.0 + i * 10.0, 0.0, 2.0), 3.0)
		if table != Vector3.INF:
			_put(FURNITURE + "table.glb", table, 0.0, 2.4)
			_put(SURV + "box.glb", table + Vector3.UP * 0.8, 0.3, 1.6, false)
	for i in 4:
		var lantern: Vector3 = _spot(0.4, gate, 8.0)
		if lantern != Vector3.INF:
			_pole(lantern, 2.4)
			_put(HOLIDAY + "lantern-hanging.glb", lantern + Vector3.UP * 1.8, 0.0, 1.6, false)
			_light(lantern + Vector3.UP * 2.0, Color(1.0, 0.8, 0.5), 0.9, 6.0)
	_scatter([HOLIDAY + "tree-snow-a.glb", HOLIDAY + "tree-snow-b.glb"], 6, 1.4, Vector2(2.6, 3.4))


## «Пастух»: вершина перевала — развалины турбазы, кости-обломки, снег, тёмное небо
func _set_lodge() -> void:
	var lodge: Vector3 = _spot(4.0, _edge(1, -0.4, 6.0), 8.0)
	if lodge != Vector3.INF:
		_put(GRAVE + "stone-wall-damaged.glb", lodge + Vector3(-2.5, 0.0, 0.0), PI * 0.5, 2.6)
		_put(GRAVE + "stone-wall-damaged.glb", lodge + Vector3(2.5, 0.0, 0.0), PI * 0.5, 2.6)
		_put(GRAVE + "stone-wall.glb", lodge + Vector3(0.0, 0.0, -2.5), 0.0, 2.6)
		_put(GRAVE + "debris-wood.glb", lodge, 0.0, 2.6, false)
		_sign("ТУРБАЗА", lodge + Vector3(0.0, 3.4, -2.3), 0.0, Color(0.85, 0.85, 0.9), 64)
	_scatter([GRAVE + "debris.glb", GRAVE + "debris-wood.glb"], 8, 1.0, Vector2(2.2, 2.6), false)
	_scatter([HOLIDAY + "snow-pile.glb"], 8, 1.4, Vector2(2.4, 3.2), false)
	_scatter([NATURE + "rock_tallA.glb", NATURE + "rock_tallB.glb"], 5, 1.8, Vector2(3.5, 4.5))
