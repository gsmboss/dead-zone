class_name CityGenerator
extends Node3D
## Большой город, который строится при запуске уровня по CityConfig:
## сетка дорог, широкие проспекты (кольцо по краю и бульвар вокруг центра — простор для дрифта),
## дрифт-площадь, кварталы (в центре — деловой район и небоскрёбы, по краям — дома и деревья),
## фонари, брошенные машины, мусор, машины для езды (своя — у старта, по сети — у каждого игрока), подборы.
## Одинаковые модели рисуются через MultiMesh (мало вызовов отрисовки на телефоне),
## коллизии — коробки в одном StaticBody3D (по ним строится навмеш RuntimeNavRegion).
## Должен быть дочерним узлом NavigationRegion3D со скриптом runtime_nav_region.gd.

## Коллизия дерева — только ствол (коробка по всей кроне перекрывала двор)
const TREE_TRUNK: Vector3 = Vector3(0.7, 4.0, 0.7)
## Точек появления игроков по сети (ближайшие к центру дворы)
const MATCH_SPAWNS: int = 8
## Взрывных бочек у дорог
const EXPLOSIVE_BARRELS: int = 20
const ROAD_TILE: float = 8.0
const ROAD_HALF_WIDTH: float = 4.0
## Проспект: 24 м асфальта (три тайла дороги), разметка и бордюр
const AVENUE_HALF_WIDTH: float = 12.0
const AVENUE_HEIGHT: float = 0.006
const AVENUE_COLOR: Color = Color(0.17, 0.17, 0.19)
const MARKING_COLOR: Color = Color(0.92, 0.9, 0.8)
const MARKING_SIZE: Vector3 = Vector3(0.25, 0.02, 3.0)
const MARKING_STEP: float = 6.0
## Дрифт-площадь: асфальт на весь квартал, конусы по кругу для «пончиков», шины по углам
const PLAZA_COLOR: Color = Color(0.2, 0.2, 0.22)
const PLAZA_CONES: int = 14
const PLAZA_CONE_RADIUS: float = 7.0
## Отступ построек от края дороги (тротуар)
const SIDEWALK: float = 2.0
const LOTS_PER_SIDE: int = 3
## Здание занимает такую долю участка
const LOT_FILL: float = 0.86
const ROAD_HEIGHT: float = 0.01
const GROUND_VISUAL_SIZE: float = 600.0
const BOUNDS_MARGIN: float = 6.0
const BOUNDS_HEIGHT: float = 40.0
## Фонари и брошенные машины не ставятся ближе этого к перекрёстку
const CROSSING_CLEARANCE: float = 7.0
const POLE_BOX: Vector3 = Vector3(0.4, 6.6, 0.4)
const GROUND_COLOR: Color = Color(0.32, 0.33, 0.31)
## Плафон фонаря относительно модели StreetLights (плечо вдоль +Z)
const LAMP_OFFSET: Vector3 = Vector3(0.0, 6.35, 2.55)
const LAMP_RADIUS: float = 0.35
const LAMP_COLOR: Color = Color(1.0, 0.85, 0.55)

@export var config: CityConfig

var _rng := RandomNumberGenerator.new()
var _half: float = 0.0
var _lines: Array[float] = []
var _body: StaticBody3D
## PackedScene -> Array[Dictionary] {"mesh": Mesh, "xform": Transform3D}
var _parts_cache: Dictionary = {}
## PackedScene -> AABB (в координатах модели)
var _bounds_cache: Dictionary = {}
## PackedScene -> Array из Transform3D (экземпляры для MultiMesh)
var _instances: Dictionary = {}
## Сцены без теней (дороги, мусор) — дешевле на телефоне
var _no_shadow: Dictionary = {}
## Центры дворов (пустая середина квартала) — для машин, подборов и мелочей
var _courtyards: Array[Vector3] = []
## Плафоны фонарей: светятся ночью (DayNightCycle, группа night_glow)
var _lamps: Array[Transform3D] = []
var _loot_spots: Array[LootSpot] = []
## Полуширина дороги каждой линии сетки (проспекты шире)
var _half_widths: Array[float] = []
## Квартал под дрифт-площадь (bx, bz); (-1, -1) — нет
var _plaza_block: Vector2i = Vector2i(-1, -1)
var _plaza_center: Vector3 = Vector3.ZERO
## Белая разметка проспектов (одним MultiMesh)
var _markings: Array[Transform3D] = []


func _ready() -> void:
	if config == null:
		push_error("CityGenerator '%s': не задан config (CityConfig)" % name)
		return
	if config.generation_seed != 0:
		_rng.seed = config.generation_seed
	else:
		_rng.randomize()
	_half = config.blocks * config.block_size * 0.5
	_lines.clear()
	for i in config.blocks + 1:
		_lines.append(-_half + i * config.block_size)
	_setup_avenues()

	_body = StaticBody3D.new()
	_body.name = "CityCollision"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)

	_build_ground()
	_build_roads()
	_build_avenues()
	_build_blocks()
	_build_drift_plaza()
	_build_street_lights()
	_build_wrecks()
	_build_props()
	_build_multimeshes()
	_build_markings()
	_build_lamp_glow()
	_spawn_drivable_cars()
	_spawn_pickups()
	for spot: LootSpot in _loot_spots:
		add_child(spot)
	# По сети: выживших и эвакуации нет (это задание одиночной игры), игроки появляются во дворах
	if Net.in_match:
		_add_match_spawns()
	else:
		_spawn_survivors()
	_build_bounds()


## Половина размера города (для спавна и границ)
func get_half_size() -> float:
	return _half


## Центр дрифт-площади (Vector3.ZERO, если её нет)
func get_plaza_center() -> Vector3:
	return _plaza_center


## Проспекты: кольцо по краю города и бульвар вокруг делового центра; дрифт-площадь — за бульваром
func _setup_avenues() -> void:
	_half_widths.clear()
	var wide := {}
	if config.wide_avenues:
		var middle: int = floori((config.blocks - 1) * 0.5)
		for index: int in [0, config.blocks, middle - config.downtown_radius, middle + config.downtown_radius + 1]:
			if index >= 0 and index <= config.blocks:
				wide[index] = true
	for i in _lines.size():
		_half_widths.append(AVENUE_HALF_WIDTH if wide.has(i) else ROAD_HALF_WIDTH)
	if config.drift_plaza:
		var middle_block: int = floori((config.blocks - 1) * 0.5)
		var plaza_x: int = mini(middle_block + config.downtown_radius + 1, config.blocks - 1)
		if plaza_x != middle_block:
			_plaza_block = Vector2i(plaza_x, middle_block)


func _is_avenue(index: int) -> bool:
	return _half_widths[index] > ROAD_HALF_WIDTH


## Ширина самой широкой дороги (для границ)
func _max_half_width() -> float:
	var result: float = ROAD_HALF_WIDTH
	for half_width: float in _half_widths:
		result = maxf(result, half_width)
	return result


# ---------- Земля, дороги, границы ----------

func _build_ground() -> void:
	var size: float = (_half + _max_half_width() + BOUNDS_MARGIN) * 2.0 + ROAD_TILE
	_add_box_collision(Vector3(0.0, -0.5, 0.0), Vector3(size, 1.0, size))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_VISUAL_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = GROUND_COLOR
	material.roughness = 1.0
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_roads() -> void:
	if config.road_straight == null:
		push_warning("CityGenerator: нет модели дороги road_straight")
		return
	_no_shadow[config.road_straight] = true
	if config.road_cross != null:
		_no_shadow[config.road_cross] = true
	var tiles_per_line: int = roundi(_half * 2.0 / ROAD_TILE)
	for line_index in _lines.size():
		if _is_avenue(line_index):
			continue  # проспект — сплошной асфальт (_build_avenues)
		var line: float = _lines[line_index]
		for k in tiles_per_line + 1:
			var along: float = -_half + k * ROAD_TILE
			if _under_avenue(along):
				continue
			var crossing: bool = _is_on_line(along)
			# Вдоль Z (x = line): здесь же перекрёстки
			if crossing and config.road_cross != null:
				_add_instance(config.road_cross, _xform(Vector3(line, ROAD_HEIGHT, along), 0.0, 1.0))
			elif not crossing:
				_add_instance(config.road_straight, _xform(Vector3(line, ROAD_HEIGHT, along), 0.0, 1.0))
			# Вдоль X (z = line): перекрёстки уже поставлены
			if not crossing:
				_add_instance(config.road_straight, _xform(Vector3(along, ROAD_HEIGHT, line), PI * 0.5, 1.0))


## Тайл дороги попадает на асфальт проспекта
func _under_avenue(along: float) -> bool:
	for i in _lines.size():
		if _is_avenue(i) and absf(_lines[i] - along) < AVENUE_HALF_WIDTH - 0.1:
			return true
	return false


## Проспекты: полоса асфальта вдоль Z и вдоль X, белая прерывистая разметка по оси и у краёв
func _build_avenues() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = AVENUE_COLOR
	material.roughness = 0.9
	var length: float = _half * 2.0 + AVENUE_HALF_WIDTH * 2.0
	for i in _lines.size():
		if not _is_avenue(i):
			continue
		var line: float = _lines[i]
		for along_x: bool in [false, true]:
			var plane := PlaneMesh.new()
			plane.size = Vector2(AVENUE_HALF_WIDTH * 2.0, length) if not along_x else Vector2(length, AVENUE_HALF_WIDTH * 2.0)
			plane.material = material
			var strip := MeshInstance3D.new()
			strip.name = "Avenue%d%s" % [i, "X" if along_x else "Z"]
			strip.mesh = plane
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Полосы вдоль X чуть выше — без мерцания на пересечениях
			strip.position = Vector3(line, AVENUE_HEIGHT, 0.0) if not along_x else Vector3(0.0, AVENUE_HEIGHT + 0.002, line)
			add_child(strip)
			_add_avenue_markings(i, along_x)


func _add_avenue_markings(index: int, along_x: bool) -> void:
	var line: float = _lines[index]
	var count: int = floori((_half * 2.0) / MARKING_STEP)
	for k in count + 1:
		var along: float = -_half + k * MARKING_STEP
		if _near_crossing(along):
			continue
		for offset: float in [0.0, -AVENUE_HALF_WIDTH * 0.5, AVENUE_HALF_WIDTH * 0.5]:
			var at := Vector3(line + offset, 0.02, along) if not along_x else Vector3(along, 0.02, line + offset)
			_markings.append(Transform3D(Basis(Vector3.UP, 0.0 if not along_x else PI * 0.5), at))


func _build_markings() -> void:
	if _markings.is_empty():
		return
	var box := BoxMesh.new()
	box.size = MARKING_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = MARKING_COLOR
	material.roughness = 0.8
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = _markings.size()
	for i in _markings.size():
		multimesh.set_instance_transform(i, _markings[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "RoadMarkings"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_markings.clear()


func _build_bounds() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Bounds"
	walls.collision_layer = PhysicsLayers.WORLD
	walls.collision_mask = 0
	add_child(walls)
	var edge: float = _half + _max_half_width() + BOUNDS_MARGIN
	var length: float = edge * 2.0 + 1.0
	for side: Vector3 in [Vector3(edge, 0.0, 0.0), Vector3(-edge, 0.0, 0.0), Vector3(0.0, 0.0, edge), Vector3(0.0, 0.0, -edge)]:
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, BOUNDS_HEIGHT, length) if side.x != 0.0 else Vector3(length, BOUNDS_HEIGHT, 0.5)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = side + Vector3.UP * BOUNDS_HEIGHT * 0.5
		walls.add_child(shape)


# ---------- Кварталы ----------

func _build_blocks() -> void:
	var middle: float = (config.blocks - 1) * 0.5
	for bx in config.blocks:
		for bz in config.blocks:
			if Vector2i(bx, bz) == _plaza_block:
				continue
			# Участок между дорогами (у проспекта он уже)
			var min_x: float = _lines[bx] + _half_widths[bx] + SIDEWALK
			var max_x: float = _lines[bx + 1] - _half_widths[bx + 1] - SIDEWALK
			var min_z: float = _lines[bz] + _half_widths[bz] + SIDEWALK
			var max_z: float = _lines[bz + 1] - _half_widths[bz + 1] - SIDEWALK
			var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
			var lot_x: float = (max_x - min_x) / LOTS_PER_SIDE
			var lot_z: float = (max_z - min_z) / LOTS_PER_SIDE
			var lot: float = minf(lot_x, lot_z)
			var downtown: bool = maxf(absf(bx - middle), absf(bz - middle)) <= config.downtown_radius
			for ix in range(-1, 2):
				for iz in range(-1, 2):
					var lot_center: Vector3 = center + Vector3(ix * lot_x, 0.0, iz * lot_z)
					if ix == 0 and iz == 0:
						_courtyards.append(lot_center)  # двор посередине квартала
						continue
					if _rng.randf() < config.empty_lot_chance:
						_decorate_empty_lot(lot_center, lot, downtown)
						continue
					_place_building(lot_center, lot, ix, iz, downtown)


func _place_building(lot_center: Vector3, lot: float, ix: int, iz: int, downtown: bool) -> void:
	var scene: PackedScene
	var base_scale: float
	if downtown:
		if not config.skyscrapers.is_empty() and _rng.randf() < 0.35:
			scene = _pick(config.skyscrapers)
			base_scale = config.skyscraper_scale
		else:
			scene = _pick(config.commercial)
			base_scale = config.commercial_scale
	else:
		scene = _pick(config.houses)
		base_scale = config.house_scale
	if scene == null:
		return
	var bounds: AABB = _scene_bounds(scene)
	var footprint: float = maxf(bounds.size.x, bounds.size.z)
	var scale_value: float = minf(base_scale, lot * LOT_FILL / maxf(footprint, 0.01))
	# Фасадом к ближайшей дороге (на углу — к одной из двух)
	var facing := Vector3(ix, 0.0, iz)
	if ix != 0 and iz != 0:
		facing = Vector3(ix, 0.0, 0.0) if _rng.randf() < 0.5 else Vector3(0.0, 0.0, iz)
	var yaw: float = atan2(facing.x, facing.z)
	_add_static(scene, _xform(lot_center, yaw, scale_value))
	# Вход в магазин с лутом — перед фасадом
	if downtown and _rng.randf() < config.loot_spot_chance:
		var depth: float = maxf(bounds.size.x, bounds.size.z) * scale_value * 0.5
		var spot := LootSpot.new()
		spot.position = lot_center + facing.normalized() * (depth + 1.6)
		_loot_spots.append(spot)
	# У домов — дерево во дворе
	if not downtown and not config.trees.is_empty() and _rng.randf() < 0.5:
		var tree_offset: Vector3 = -facing * lot * 0.42 + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0))
		_add_static(_pick(config.trees), _xform(lot_center + tree_offset, _rng.randf() * TAU, config.tree_scale), TREE_TRUNK)


func _decorate_empty_lot(lot_center: Vector3, lot: float, downtown: bool) -> void:
	if not downtown and not config.trees.is_empty():
		for i in 2:
			var offset := Vector3(_rng.randf_range(-lot, lot) * 0.35, 0.0, _rng.randf_range(-lot, lot) * 0.35)
			_add_static(_pick(config.trees), _xform(lot_center + offset, _rng.randf() * TAU, config.tree_scale), TREE_TRUNK)
	else:
		_courtyards.append(lot_center)  # пустырь в центре — как двор


## Дрифт-площадь: квартал без домов, асфальт до самых дорог, конусы кругом, шины по углам, фонари
func _build_drift_plaza() -> void:
	if _plaza_block.x < 0:
		return
	var bx: int = _plaza_block.x
	var bz: int = _plaza_block.y
	var min_x: float = _lines[bx] + _half_widths[bx]
	var max_x: float = _lines[bx + 1] - _half_widths[bx + 1]
	var min_z: float = _lines[bz] + _half_widths[bz]
	var max_z: float = _lines[bz + 1] - _half_widths[bz + 1]
	_plaza_center = Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = PLAZA_COLOR
	material.roughness = 0.85
	var plane := PlaneMesh.new()
	plane.size = Vector2(max_x - min_x, max_z - min_z)
	plane.material = material
	var asphalt := MeshInstance3D.new()
	asphalt.name = "DriftPlaza"
	asphalt.mesh = plane
	asphalt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	asphalt.position = _plaza_center + Vector3.UP * 0.004
	add_child(asphalt)
	# Круг разметки и конусы для «пончиков» (конусы без коллизии — можно проезжать насквозь)
	for i in 48:
		var angle: float = TAU * i / 48.0
		var at: Vector3 = _plaza_center + Vector3(cos(angle), 0.0, sin(angle)) * (PLAZA_CONE_RADIUS + 5.0)
		_markings.append(Transform3D(Basis(Vector3.UP, -angle), at + Vector3.UP * 0.02))
	var cone: PackedScene = _find_prop("TrafficCone")
	if cone != null:
		_no_shadow[cone] = true
		for i in PLAZA_CONES:
			var angle_cone: float = TAU * i / PLAZA_CONES
			_add_instance(cone, _xform(_plaza_center + Vector3(cos(angle_cone), 0.0, sin(angle_cone)) * PLAZA_CONE_RADIUS, angle_cone, 1.0))
	# Шины и фонари по углам — площадь видно и ночью
	var tires: PackedScene = _find_prop("Wheels_Stack")
	var half_x: float = (max_x - min_x) * 0.5 - 2.5
	var half_z: float = (max_z - min_z) * 0.5 - 2.5
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var at_corner: Vector3 = _plaza_center + Vector3(corner.x * half_x, 0.0, corner.z * half_z)
		if tires != null:
			_add_static(tires, _xform(at_corner, _rng.randf() * TAU, 1.0))
		if config.street_light != null:
			var light_at: Vector3 = at_corner - Vector3(corner.x, 0.0, corner.z) * 2.5
			var light: Transform3D = _xform(light_at, atan2(-corner.x, -corner.z), 1.0)
			_add_static(config.street_light, light, POLE_BOX)
			_lamps.append(light)
	var plaza_sign := Label3D.new()
	plaza_sign.name = "PlazaSign"
	plaza_sign.text = "ДРИФТ-ПЛОЩАДЬ"
	plaza_sign.font_size = 96
	plaza_sign.outline_size = 24
	plaza_sign.pixel_size = 0.02
	plaza_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	plaza_sign.modulate = Color(1.0, 0.75, 0.25)
	plaza_sign.position = _plaza_center + Vector3.UP * 7.0
	add_child(plaza_sign)


## Модель мелочи из config.props по части имени файла
func _find_prop(part: String) -> PackedScene:
	for scene: PackedScene in config.props:
		if scene != null and scene.resource_path.get_file().contains(part):
			return scene
	return null


# ---------- Улица ----------

func _build_street_lights() -> void:
	if config.street_light == null or config.street_light_spacing <= 0.0:
		return
	var count: int = floori(_half * 2.0 / config.street_light_spacing)
	for line_index in _lines.size():
		var line: float = _lines[line_index]
		var offset: float = _half_widths[line_index] + 1.0
		for k in count + 1:
			var along: float = -_half + k * config.street_light_spacing
			if _near_crossing(along):
				continue
			var side: float = 1.0 if (k + line_index) % 2 == 0 else -1.0
			# Вдоль Z: фонарь сбоку по X, плечо — к дороге
			var light_z: Transform3D = _xform(Vector3(line + side * offset, 0.0, along), atan2(-side, 0.0), 1.0)
			_add_static(config.street_light, light_z, POLE_BOX)
			_lamps.append(light_z)
			# Вдоль X: сбоку по Z
			var light_x: Transform3D = _xform(Vector3(along, 0.0, line + side * offset), atan2(0.0, -side), 1.0)
			_add_static(config.street_light, light_x, POLE_BOX)
			_lamps.append(light_x)


func _build_wrecks() -> void:
	if config.wrecks.is_empty():
		return
	for i in config.wreck_count:
		var spot: Dictionary = _random_road_spot(2.2)
		if spot.is_empty():
			continue
		var yaw: float = float(spot["yaw"]) + _rng.randf_range(-0.5, 0.5)
		_add_static(_pick(config.wrecks), _xform(spot["position"], yaw, 1.0))


func _build_props() -> void:
	if config.props.is_empty():
		return
	for i in config.prop_count:
		var at: Vector3
		if not _courtyards.is_empty() and _rng.randf() < 0.5:
			at = _pick_vector(_courtyards) + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
		else:
			var spot: Dictionary = _random_road_spot(ROAD_HALF_WIDTH + 1.2)
			if spot.is_empty():
				continue
			at = spot["position"]
		if at.length() < 3.0:
			continue  # место старта игрока
		var scene: PackedScene = _pick(config.props)
		_no_shadow[scene] = true
		_add_static(scene, _xform(at, _rng.randf() * TAU, 1.0))
	# Взрывные бочки у дорог
	for i in EXPLOSIVE_BARRELS:
		var spot: Dictionary = _random_road_spot(ROAD_HALF_WIDTH + 0.9)
		if not spot.is_empty() and (spot["position"] as Vector3).length() > 6.0:
			ExplosiveBarrel.spawn(self, spot["position"], i)


## Случайная точка на дороге (не у перекрёстка), сдвинутая от оси на lateral метров
## (на проспекте — у его края: середина свободна для езды)
func _random_road_spot(lateral_offset: float) -> Dictionary:
	for attempt in 6:
		var line_index: int = _rng.randi() % _lines.size()
		var line: float = _lines[line_index]
		var lateral: float = lateral_offset + _half_widths[line_index] - ROAD_HALF_WIDTH
		var along: float = _rng.randf_range(-_half + 4.0, _half - 4.0)
		if _near_crossing(along):
			continue
		var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
		if _rng.randf() < 0.5:
			return {"position": Vector3(line + side * lateral, 0.0, along), "yaw": 0.0 if side > 0.0 else PI}
		return {"position": Vector3(along, 0.0, line + side * lateral), "yaw": PI * 0.5 if side > 0.0 else -PI * 0.5}
	return {}


# ---------- Машины и подборы ----------

func _spawn_drivable_cars() -> void:
	var start_yard: int = 0
	if Net.in_match:
		_spawn_match_cars()
	elif not _courtyards.is_empty():
		# Своя машина из автосалона ждёт во дворе у старта
		var own: DrivableCar = DrivableCar.create_selected()
		if own != null:
			own.name = "MyCar"
			own.position = _closest_courtyard(Vector3.ZERO) + Vector3(0.0, 0.3, 4.5)
			own.rotation.y = PI * 0.5
			add_child(own)
			start_yard = 1
			_add_races(own.position)
	if config.drivable_cars.is_empty():
		return
	# Остальные — на дорогах (по сети у всех одинаковые: тот же _rng)
	for i in range(start_yard, config.drivable_car_count):
		var spot: Dictionary = _random_road_spot(2.4)
		if spot.is_empty():
			continue
		var car := DrivableCar.new()
		car.name = "Car%d" % (i + 1)
		car.model_scene = config.drivable_cars[i % config.drivable_cars.size()]
		car.position = (spot["position"] as Vector3) + Vector3.UP * 0.3
		car.rotation.y = spot["yaw"]
		add_child(car)


## Заезды по городу — только в открытом мире одиночной игры (не в сюжетных миссиях)
func _add_races(near: Vector3) -> void:
	var mission: MissionData = GameState.selected_mission
	if mission != null and mission.type != MissionData.Type.FREE_ROAM:
		return
	var races := RaceDirector.new()
	races.name = "Races"
	races.lines = _lines.duplicate()
	races.half_widths = _half_widths.duplicate()
	races.start_point = near
	races.route_seed = config.generation_seed if config.generation_seed != 0 else 1337
	add_child(races)


## По сети: у каждого игрока его машина из автосалона (покраска, неон, тюнинг) — в ближних дворах.
## Порядок по peer_id — одинаковые имена и места у всех
func _spawn_match_cars() -> void:
	var yards: Array[Vector3] = _courtyards.duplicate()
	yards.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	if yards.is_empty():
		yards.append(Vector3.ZERO)
	var peers: Array = Net.players.keys()
	peers.sort()
	# Здесь — запасные места; MatchManager потом ставит каждую машину рядом с её игроком
	for i in peers.size():
		var peer_id: int = int(peers[i])
		var info: String = str((Net.players[peer_id] as Dictionary).get("car", ""))
		var car: DrivableCar = DrivableCar.create_from_net_info(info)
		if car == null and not config.drivable_cars.is_empty():
			# Нет данных о машине игрока — обычный пикап, чтобы у каждого была своя
			car = DrivableCar.new()
			car.model_scene = config.drivable_cars[0]
		if car == null:
			continue
		car.name = "PlayerCar_%d" % peer_id
		car.position = yards[i % yards.size()] + Vector3(floorf(float(i) / yards.size()) * 3.0, 0.3, 4.5)
		car.rotation.y = PI * 0.5
		add_child(car)


func _spawn_pickups() -> void:
	for i in config.pickup_count:
		var at: Vector3
		if not _courtyards.is_empty() and _rng.randf() < 0.7:
			at = _pick_vector(_courtyards) + Vector3(_rng.randf_range(-3.5, 3.5), 0.0, _rng.randf_range(-3.5, 3.5))
		else:
			var spot: Dictionary = _random_road_spot(ROAD_HALF_WIDTH + 1.0)
			if spot.is_empty():
				continue
			at = spot["position"]
		var pickup := Pickup.new()
		var roll: float = _rng.randf()
		if roll < 0.3:
			pickup.kind = Pickup.Kind.SCRAP  # лом для мастерской
			pickup.amount = 2.0
		elif roll < 0.6:
			pickup.kind = Pickup.Kind.HEALTH
			pickup.amount = 30.0
		else:
			pickup.kind = Pickup.Kind.AMMO
			pickup.amount = 0.35
		pickup.position = at
		add_child(pickup)


## Выжившие в дальних дворах и точка эвакуации в центре (у старта игрока)
func _spawn_survivors() -> void:
	if config.survivor_models.is_empty() or config.survivor_count <= 0:
		return
	var far_yards: Array[Vector3] = []
	for yard: Vector3 in _courtyards:
		if yard.length() >= config.survivor_min_distance:
			far_yards.append(yard)
	if far_yards.is_empty():
		far_yards = _courtyards.duplicate()
	for i in config.survivor_count:
		if far_yards.is_empty():
			break
		var index: int = _rng.randi() % far_yards.size()
		var survivor := Survivor.new()
		survivor.name = "Survivor%d" % (i + 1)
		survivor.model_scene = config.survivor_models[i % config.survivor_models.size()]
		survivor.position = far_yards[index] + Vector3(_rng.randf_range(-2.0, 2.0), 0.2, _rng.randf_range(-2.0, 2.0))
		survivor.rotation.y = _rng.randf() * TAU
		add_child(survivor)
		far_yards.remove_at(index)
	var evac := EvacPoint.new()
	evac.name = "EvacPoint"
	evac.position = _closest_courtyard(Vector3.ZERO) + Vector3(0.0, 0.0, -2.0)
	add_child(evac)


## Точки появления игроков по сети (группа mp_spawn): дворы по порядку — одинаково у всех
func _add_match_spawns() -> void:
	var yards: Array[Vector3] = _courtyards.duplicate()
	yards.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	for i in mini(yards.size(), MATCH_SPAWNS):
		var marker := Marker3D.new()
		marker.name = "MatchSpawn%d" % i
		marker.position = yards[i] + Vector3.UP * 0.2
		marker.add_to_group(&"mp_spawn")
		add_child(marker)


# ---------- MultiMesh и коллизии ----------

## Модель в списке экземпляров + коробка коллизии (custom_box — свой размер, например столб)
func _add_static(scene: PackedScene, xform: Transform3D, custom_box: Vector3 = Vector3.ZERO) -> void:
	if scene == null:
		return
	_add_instance(scene, xform)
	if custom_box != Vector3.ZERO:
		_add_box_collision(xform.origin + Vector3.UP * custom_box.y * 0.5, custom_box)
		return
	# Коробка повёрнута вместе с моделью (AABB повёрнутой модели заметно шире)
	var local: AABB = _scene_bounds(scene)
	var box_size: Vector3 = local.size * xform.basis.get_scale().abs()
	if box_size.x < 0.05 or box_size.z < 0.05:
		return
	var box := BoxShape3D.new()
	box.size = box_size.max(Vector3.ONE * 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.transform = Transform3D(xform.basis.orthonormalized(), xform * local.get_center())
	_body.add_child(shape)


func _add_instance(scene: PackedScene, xform: Transform3D) -> void:
	if not _instances.has(scene):
		_instances[scene] = []
	(_instances[scene] as Array).append(xform)


func _add_box_collision(center: Vector3, box_size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(box_size.x, 0.1), maxf(box_size.y, 0.1), maxf(box_size.z, 0.1))
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = center
	_body.add_child(shape)


func _build_multimeshes() -> void:
	for scene: PackedScene in _instances:
		var transforms: Array = _instances[scene]
		var cast_shadows: bool = not _no_shadow.has(scene)
		for part: Dictionary in _scene_parts(scene):
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part["mesh"]
			multimesh.instance_count = transforms.size()
			var part_xform: Transform3D = part["xform"]
			for i in transforms.size():
				var instance_xform: Transform3D = transforms[i]
				multimesh.set_instance_transform(i, instance_xform * part_xform)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
	_instances.clear()


## Светящиеся плафоны фонарей одним MultiMesh; яркость меняет DayNightCycle
func _build_lamp_glow() -> void:
	if _lamps.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = LAMP_COLOR
	material.emission_enabled = true
	material.emission = LAMP_COLOR
	material.emission_energy_multiplier = 0.0
	var sphere := SphereMesh.new()
	sphere.radius = LAMP_RADIUS
	sphere.height = LAMP_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = _lamps.size()
	for i in _lamps.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _lamps[i] * LAMP_OFFSET))
	var lamps := MultiMeshInstance3D.new()
	lamps.name = "LampGlow"
	lamps.multimesh = multimesh
	lamps.material_override = material
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps.add_to_group(&"night_glow")
	add_child(lamps)


## Меши модели с трансформами относительно её корня (кэш на сцену)
func _scene_parts(scene: PackedScene) -> Array:
	if _parts_cache.has(scene):
		return _parts_cache[scene]
	var parts: Array = []
	var root := scene.instantiate() as Node3D
	if root == null:
		push_warning("CityGenerator: модель %s не Node3D" % scene.resource_path)
		_parts_cache[scene] = parts
		return parts
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != root:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		parts.append({"mesh": mesh_instance.mesh, "xform": xform})
	root.free()
	_parts_cache[scene] = parts
	return parts


func _scene_bounds(scene: PackedScene) -> AABB:
	if _bounds_cache.has(scene):
		return _bounds_cache[scene]
	var result := AABB()
	var has_bounds: bool = false
	for part: Dictionary in _scene_parts(scene):
		var mesh: Mesh = part["mesh"]
		var bounds: AABB = (part["xform"] as Transform3D) * mesh.get_aabb()
		result = result.merge(bounds) if has_bounds else bounds
		has_bounds = true
	_bounds_cache[scene] = result
	return result


# ---------- Вспомогательное ----------

func _xform(at: Vector3, yaw: float, scale_value: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value), at)


func _is_on_line(value: float) -> bool:
	for line: float in _lines:
		if absf(line - value) < 0.01:
			return true
	return false


func _near_crossing(value: float) -> bool:
	for i in _lines.size():
		if absf(_lines[i] - value) < CROSSING_CLEARANCE + _half_widths[i] - ROAD_HALF_WIDTH:
			return true
	return false


func _closest_courtyard(point: Vector3) -> Vector3:
	var best: Vector3 = _courtyards[0]
	for yard: Vector3 in _courtyards:
		if yard.distance_to(point) < best.distance_to(point):
			best = yard
	return best


func _pick(list: Array[PackedScene]) -> PackedScene:
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()]


func _pick_vector(list: Array[Vector3]) -> Vector3:
	return list[_rng.randi() % list.size()]


func _pick_float(list: Array[float]) -> float:
	return list[_rng.randi() % list.size()]
