class_name CityGenerator
extends Node3D
## Большой город, который строится при запуске уровня по CityConfig:
## сетка дорог, кварталы (в центре — деловой район и небоскрёбы, по краям — дома и деревья),
## фонари, брошенные машины, мусор, машины для езды, подборы.
## Одинаковые модели рисуются через MultiMesh (мало вызовов отрисовки на телефоне),
## коллизии — коробки в одном StaticBody3D (по ним строится навмеш RuntimeNavRegion).
## Должен быть дочерним узлом NavigationRegion3D со скриптом runtime_nav_region.gd.

## Коллизия дерева — только ствол (коробка по всей кроне перекрывала двор)
const TREE_TRUNK: Vector3 = Vector3(0.7, 4.0, 0.7)
## Взрывных бочек у дорог
const EXPLOSIVE_BARRELS: int = 14
const ROAD_TILE: float = 8.0
const ROAD_HALF_WIDTH: float = 4.0
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

	_body = StaticBody3D.new()
	_body.name = "CityCollision"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)

	_build_ground()
	_build_roads()
	_build_blocks()
	_build_street_lights()
	_build_wrecks()
	_build_props()
	_build_multimeshes()
	_build_lamp_glow()
	_spawn_drivable_cars()
	_spawn_pickups()
	for spot: LootSpot in _loot_spots:
		add_child(spot)
	_spawn_survivors()
	_build_bounds()


## Половина размера города (для спавна и границ)
func get_half_size() -> float:
	return _half


# ---------- Земля, дороги, границы ----------

func _build_ground() -> void:
	var size: float = _half * 2.0 + ROAD_TILE * 2.0
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
	for line: float in _lines:
		for k in tiles_per_line + 1:
			var along: float = -_half + k * ROAD_TILE
			var crossing: bool = _is_on_line(along)
			# Вдоль Z (x = line): здесь же перекрёстки
			if crossing and config.road_cross != null:
				_add_instance(config.road_cross, _xform(Vector3(line, ROAD_HEIGHT, along), 0.0, 1.0))
			elif not crossing:
				_add_instance(config.road_straight, _xform(Vector3(line, ROAD_HEIGHT, along), 0.0, 1.0))
			# Вдоль X (z = line): перекрёстки уже поставлены
			if not crossing:
				_add_instance(config.road_straight, _xform(Vector3(along, ROAD_HEIGHT, line), PI * 0.5, 1.0))


func _build_bounds() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Bounds"
	walls.collision_layer = PhysicsLayers.WORLD
	walls.collision_mask = 0
	add_child(walls)
	var edge: float = _half + BOUNDS_MARGIN
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
	var interior_half: float = config.block_size * 0.5 - ROAD_HALF_WIDTH - SIDEWALK
	var lot: float = interior_half * 2.0 / LOTS_PER_SIDE
	for bx in config.blocks:
		for bz in config.blocks:
			var center := Vector3(-_half + (bx + 0.5) * config.block_size, 0.0,
				-_half + (bz + 0.5) * config.block_size)
			var downtown: bool = maxf(absf(bx - middle), absf(bz - middle)) <= config.downtown_radius
			for ix in range(-1, 2):
				for iz in range(-1, 2):
					var lot_center: Vector3 = center + Vector3(ix * lot, 0.0, iz * lot)
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


# ---------- Улица ----------

func _build_street_lights() -> void:
	if config.street_light == null or config.street_light_spacing <= 0.0:
		return
	var offset: float = ROAD_HALF_WIDTH + 1.0
	var count: int = floori(_half * 2.0 / config.street_light_spacing)
	for line_index in _lines.size():
		var line: float = _lines[line_index]
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
func _random_road_spot(lateral: float) -> Dictionary:
	for attempt in 6:
		var line: float = _pick_float(_lines)
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
	if config.drivable_cars.is_empty():
		return
	for i in config.drivable_car_count:
		var at: Vector3
		var yaw: float
		if i == 0 and not _courtyards.is_empty():
			# Первая — во дворе у старта игрока
			at = _closest_courtyard(Vector3.ZERO) + Vector3(0.0, 0.0, 4.5)
			yaw = PI * 0.5
		else:
			var spot: Dictionary = _random_road_spot(2.4)
			if spot.is_empty():
				continue
			at = spot["position"]
			yaw = spot["yaw"]
		var car := DrivableCar.new()
		car.name = "Car%d" % (i + 1)
		car.model_scene = config.drivable_cars[i % config.drivable_cars.size()]
		# Своя машина из сюжета ждёт у старта
		var owned: Array[PackedScene] = GameState.get_owned_cars()
		if i == 0 and not owned.is_empty():
			car.model_scene = owned[owned.size() - 1]
		car.position = at + Vector3.UP * 0.3
		car.rotation.y = yaw
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
	for line: float in _lines:
		if absf(line - value) < CROSSING_CLEARANCE:
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
