class_name LocationBuilder
extends Node3D
## Основа процедурных локаций (лес, промзона): MultiMesh-декорации и коробки коллизий
## через PropBatch, свободные места у точек спавна/подборов/обороны/игрока, видимая ограда
## по краю (за ней — невидимые стены Bounds уровня), туман и свет атмосферы.
## Наследник переопределяет _build_location(). Узел — ребёнок NavigationRegion3D с runtime_nav_region.gd.

## Половина стороны площадки (уровень 56×56 → 26 с запасом до стен Bounds)
@export var half_size: float = 26.0
## Свободный радиус вокруг точек спавна, подборов, обороны и игрока
@export var clear_radius: float = 3.5
@export var generation_seed: int = 7
@export_group("Mood")
@export var fog_color: Color = Color(0.3, 0.32, 0.3)
@export var fog_density: float = 0.02
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 0.9
@export var ground_color: Color = Color(0.25, 0.25, 0.22)

var _rng := RandomNumberGenerator.new()
var _batch: PropBatch
var _keep_clear: Array[Vector3] = []
var _reserved: Array[Rect2] = []
var _scenes: Dictionary = {}


func _ready() -> void:
	_rng.seed = generation_seed
	# Точки спавна и подборов ещё не в группах — строим после их _ready
	_build.call_deferred()


func _build() -> void:
	_collect_keep_clear()
	_batch = PropBatch.new(self)
	_build_location()
	_batch.build()
	_apply_mood()


## Переопределяется: расставить декорации через _place/_scatter/_ring
func _build_location() -> void:
	pass


# ---------- Помощники для наследников ----------

func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("%s: нет модели %s" % [name, path])
	_scenes[path] = scene
	return scene


## Поставить модель (с коробкой коллизии, если collide); reserve — занять место под неё
func _place(path: String, at: Vector3, yaw: float, scale_value: float, collide: bool = true,
		custom_box: Vector3 = Vector3.ZERO, reserve: float = 0.0) -> void:
	var scene: PackedScene = _scene(path)
	if scene == null:
		return
	_batch.add(scene, _xform(at, yaw, scale_value), collide, custom_box)
	if reserve > 0.0:
		_reserved.append(Rect2(at.x - reserve, at.z - reserve, reserve * 2.0, reserve * 2.0))


## Разбросать count моделей из списка по свободным местам внутри площадки
func _scatter(paths: Array[String], count: int, scale_range: Vector2, spacing: float,
		collide: bool = true, custom_box: Vector3 = Vector3.ZERO, inset: float = 3.0) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 15:
		attempts += 1
		var at := Vector3(_rng.randf_range(-half_size + inset, half_size - inset), 0.0,
			_rng.randf_range(-half_size + inset, half_size - inset))
		if not _is_free(at, spacing):
			continue
		var path: String = paths[_rng.randi() % paths.size()]
		_place(path, at, _rng.randf() * TAU, _rng.randf_range(scale_range.x, scale_range.y), collide, custom_box)
		_keep_clear.append(at)
		placed += 1


## Видимая ограда по периметру (только вид — не пускают стены Bounds уровня)
func _ring(path: String, step: float, scale_value: float, offset: float = 1.0, yaw_offset: float = 0.0) -> void:
	var edge: float = half_size + offset
	var count: int = int(edge * 2.0 / step)
	for side in 4:
		var yaw: float = side * PI * 0.5
		for i in count:
			var along: float = -edge + step * (i + 0.5)
			var at: Vector3 = Vector3(along, 0.0, edge).rotated(Vector3.UP, yaw)
			_place(path, at, yaw + yaw_offset, scale_value, false)


## Огонь с живым светом (костры, бочки с огнём)
func _fire(at: Vector3, height: float = 0.4, light_range: float = 8.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.25)
	light.light_energy = 1.5
	light.omni_range = light_range
	light.position = at + Vector3.UP * (height + 0.6)
	add_child(light)
	var flames := GraveyardBuilder.make_flames()
	flames.position = at + Vector3.UP * height
	add_child(flames)


func _is_free(point: Vector3, radius: float) -> bool:
	for keep: Vector3 in _keep_clear:
		var dx: float = keep.x - point.x
		var dz: float = keep.z - point.z
		if dx * dx + dz * dz < (clear_radius + radius) * (clear_radius + radius):
			return false
	for rect: Rect2 in _reserved:
		if rect.grow(radius).has_point(Vector2(point.x, point.z)):
			return false
	return true


func _xform(at: Vector3, yaw: float, scale_value: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value), at)


func _collect_keep_clear() -> void:
	for group: StringName in [&"zombie_spawn", &"item_spawn", &"defend_point", &"player"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var node_3d := node as Node3D
			if node_3d != null:
				_keep_clear.append(node_3d.global_position)


## Туман, солнце и цвет земли уровня (копии ресурсов, файл сцены не меняется)
func _apply_mood() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for node: Node in scene_root.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world.environment == null:
			continue
		var environment: Environment = world.environment.duplicate() as Environment
		environment.fog_enabled = fog_density > 0.0
		environment.fog_light_color = fog_color
		environment.fog_density = fog_density
		world.environment = environment
	for node: Node in scene_root.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		sun.light_color = sun_color
		sun.light_energy = sun_energy
	# Земля за краем площадки (только вид), чтобы здания и лес за стенами не висели в пустоте
	var outside := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	var outside_material := StandardMaterial3D.new()
	outside_material.albedo_color = ground_color.darkened(0.1)
	outside_material.roughness = 1.0
	plane.material = outside_material
	outside.mesh = plane
	outside.position = Vector3(0.0, -0.03, 0.0)
	outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outside)
	var floor_box := get_parent().get_node_or_null(^"Floor") as CSGBox3D
	if floor_box != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = ground_color
		material.roughness = 1.0
		floor_box.material = material
