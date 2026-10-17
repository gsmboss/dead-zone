class_name GraveyardBuilder
extends Node3D
## Кладбище, которое строится при запуске уровня (модели Kenney Graveyard Kit):
## ограда, крест дорожек, ряды могил, склепы, сосны, фонари, жаровни с огнём и мусор.
## Места спавна, подборов, точки обороны и игрока остаются свободными.
## Должен быть дочерним узлом NavigationRegion3D со скриптом runtime_nav_region.gd.

const DIR: String = "res://models/graveyard/"
const GRAVESTONES: Array[String] = ["gravestone-cross", "gravestone-round", "gravestone-bevel",
	"gravestone-decorative", "gravestone-wide", "gravestone-broken"]
const SCATTER: Array[String] = ["rocks", "rocks-tall", "trunk", "debris", "debris-wood", "bench-damaged",
	"cross-column", "pillar-obelisk", "shovel-dirt", "coffin-old", "lantern-candle"]
const PINES: Array[String] = ["pine", "pine-crooked", "pine-fall"]
## Ширина главных дорожек (крест через центр)
const PATH_HALF_WIDTH: float = 2.5
const PINE_TRUNK: Vector3 = Vector3(0.6, 3.5, 0.6)
const POST_BOX: Vector3 = Vector3(0.3, 2.8, 0.3)
const FIRE_COLOR: Color = Color(1.0, 0.55, 0.2)

## Половина стороны площадки (уровень 56×56 → 26 с запасом до стен)
@export var half_size: float = 26.0
## Масштаб моделей Kenney (персонаж 0.83 → ~1.8 м)
@export var prop_scale: float = 2.2
## Шаг рядов могил по X и Z
@export var grave_spacing: Vector2 = Vector2(3.2, 4.4)
@export_range(0.0, 1.0, 0.05) var grave_skip_chance: float = 0.25
@export var scatter_count: int = 34
## Свободный радиус вокруг точек спавна, подборов, обороны и игрока
@export var clear_radius: float = 3.5
@export var generation_seed: int = 1313
## Туман и лунный свет
@export var gloomy: bool = true

var _rng := RandomNumberGenerator.new()
var _batch: PropBatch
var _keep_clear: Array[Vector3] = []
## Занятые прямоугольники (склепы): x, z — центр, w, h — половины
var _reserved: Array[Rect2] = []
var _scenes: Dictionary = {}


func _ready() -> void:
	_rng.seed = generation_seed
	# Точки спавна и подборов ещё не в группах — строим после их _ready
	_build.call_deferred()


func _build() -> void:
	_collect_keep_clear()
	_batch = PropBatch.new(self)
	_build_fence()
	_build_crypts()
	_build_graves()
	_build_pines()
	_build_lights()
	_build_scatter()
	_batch.build()
	if gloomy:
		_apply_mood()


func _collect_keep_clear() -> void:
	for group: StringName in [&"zombie_spawn", &"item_spawn", &"defend_point", &"player"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var node_3d := node as Node3D
			if node_3d != null:
				_keep_clear.append(node_3d.global_position)


# ---------- Части ----------

## Кованая ограда по периметру (только визуал — стены уровня в Bounds), ворота на юге
func _build_fence() -> void:
	var fence: PackedScene = _scene("iron-fence")
	var damaged: PackedScene = _scene("iron-fence-damaged")
	var gate: PackedScene = _scene("iron-fence-border-gate")
	var step: float = prop_scale  # секция ограды 1 м
	var edge: float = half_size + 1.0
	var count: int = int(edge * 2.0 / step)
	for side in 4:
		var yaw: float = side * PI * 0.5
		for i in count:
			var along: float = -edge + step * (i + 0.5)
			var local := Vector3(along, 0.0, edge)
			var at: Vector3 = local.rotated(Vector3.UP, yaw)
			var is_gate: bool = side == 0 and absf(along) < step
			var scene: PackedScene = gate if is_gate else (damaged if _rng.randf() < 0.18 else fence)
			_batch.add(scene, _xform(at, yaw, prop_scale), false)


## Склепы в центрах четырёх кварталов
func _build_crypts() -> void:
	var large: PackedScene = _scene("crypt-large")
	var small: PackedScene = _scene("crypt-small")
	var offset: float = half_size * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var center := Vector3(corner.x * offset, 0.0, corner.y * offset)
		if not _is_free(center, 4.0):
			continue
		var big: bool = _rng.randf() < 0.6
		var scene: PackedScene = large if big else small
		var yaw: float = PI if corner.y < 0.0 else 0.0  # входом к центральной дорожке
		_batch.add(scene, _xform(center, yaw, prop_scale))
		var half: float = (2.8 if big else 1.8)
		_reserved.append(Rect2(center.x - half, center.z - half, half * 2.0, half * 2.0))


## Ряды могил: холмик (без коллизии) и надгробие (с коллизией)
func _build_graves() -> void:
	var mound: PackedScene = _scene("grave")
	var border: PackedScene = _scene("grave-border")
	var limit: float = half_size - 3.5
	var x: float = -limit
	while x <= limit:
		var z: float = -limit
		while z <= limit:
			var at := Vector3(x + _rng.randf_range(-0.3, 0.3), 0.0, z)
			z += grave_spacing.y
			if absf(at.x) < PATH_HALF_WIDTH + 1.0 or absf(at.z) < PATH_HALF_WIDTH + 1.5:
				continue
			if _rng.randf() < grave_skip_chance or not _is_free(at, 1.6):
				continue
			var yaw: float = _rng.randf_range(-0.08, 0.08)
			_batch.add(border if _rng.randf() < 0.35 else mound, _xform(at, yaw, prop_scale), false)
			var stone: PackedScene = _scene(GRAVESTONES[_rng.randi() % GRAVESTONES.size()])
			var head: Vector3 = at + Vector3(0.0, 0.0, -0.75 * prop_scale).rotated(Vector3.UP, yaw)
			_batch.add(stone, _xform(head, yaw + _rng.randf_range(-0.15, 0.15), prop_scale))
		x += grave_spacing.x
	for scene_name: String in ["grave", "grave-border"]:
		_batch.set_no_shadow(_scene(scene_name))


## Сосны вдоль ограды
func _build_pines() -> void:
	var edge: float = half_size - 1.2
	var step: float = 6.5
	for side in 4:
		var yaw: float = side * PI * 0.5
		var along: float = -edge + _rng.randf_range(0.0, step)
		while along < edge:
			var at: Vector3 = Vector3(along, 0.0, edge).rotated(Vector3.UP, yaw)
			along += step + _rng.randf_range(-1.5, 2.0)
			if not _is_free(at, 2.0):
				continue
			var scene: PackedScene = _scene(PINES[_rng.randi() % PINES.size()])
			_batch.add(scene, _xform(at, _rng.randf() * TAU, prop_scale * _rng.randf_range(1.1, 1.5)),
				true, PINE_TRUNK)


## Фонари вдоль дорожек и четыре жаровни с живым огнём у центра
func _build_lights() -> void:
	var post: PackedScene = _scene("lightpost-single")
	var x: float = -half_size + 6.0
	while x < half_size - 4.0:
		for z: float in [-PATH_HALF_WIDTH - 0.4, PATH_HALF_WIDTH + 0.4]:
			var along_x := Vector3(x, 0.0, z)
			var along_z := Vector3(z, 0.0, x)
			if absf(x) > PATH_HALF_WIDTH + 1.0:
				if _is_free(along_x, 1.0):
					_batch.add(post, _xform(along_x, 0.0, prop_scale), true, POST_BOX)
				if _is_free(along_z, 1.0):
					_batch.add(post, _xform(along_z, PI * 0.5, prop_scale), true, POST_BOX)
		x += 9.0
	var basket: PackedScene = _scene("fire-basket")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector3(corner.x, 0.0, corner.y) * (PATH_HALF_WIDTH + 1.6)
		if not _is_free(at, 1.0):
			continue
		_batch.add(basket, _xform(at, 0.0, prop_scale * 1.3))
		var light := OmniLight3D.new()
		light.light_color = FIRE_COLOR
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.position = at + Vector3.UP * 0.9
		add_child(light)
		var flames := make_flames()
		flames.position = at + Vector3.UP * 0.35
		add_child(flames)


## Мусор, камни, гробы и колонны в свободных местах
func _build_scatter() -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < scatter_count and attempts < scatter_count * 12:
		attempts += 1
		var at := Vector3(_rng.randf_range(-half_size + 2.0, half_size - 2.0), 0.0,
			_rng.randf_range(-half_size + 2.0, half_size - 2.0))
		if absf(at.x) < PATH_HALF_WIDTH or absf(at.z) < PATH_HALF_WIDTH:
			continue
		if not _is_free(at, 1.4):
			continue
		var scene_name: String = SCATTER[_rng.randi() % SCATTER.size()]
		var small: bool = scene_name in ["debris", "debris-wood", "lantern-candle", "coffin-old"]
		_batch.add(_scene(scene_name), _xform(at, _rng.randf() * TAU, prop_scale), not small)
		if small:
			_batch.set_no_shadow(_scene(scene_name))
		_keep_clear.append(at)
		placed += 1


# ---------- Атмосфера ----------

## Туман, лунный свет, тёмное небо (меняем только копии ресурсов уровня)
func _apply_mood() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for node: Node in scene_root.find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world.environment == null:
			continue
		var environment: Environment = world.environment.duplicate() as Environment
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.32, 0.36, 0.42)
		environment.fog_density = 0.025
		environment.ambient_light_energy = 0.6
		world.environment = environment
	for node: Node in scene_root.find_children("*", "DirectionalLight3D", true, false):
		var moon := node as DirectionalLight3D
		moon.light_color = Color(0.65, 0.72, 0.95)
		moon.light_energy = 0.55


## Огонь из частиц (жаровни, костры), без текстур
static func make_flames() -> CPUParticles3D:
	var flames := CPUParticles3D.new()
	flames.amount = 14
	flames.lifetime = 0.6
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.initial_velocity_min = 0.8
	flames.initial_velocity_max = 1.6
	flames.gravity = Vector3(0.0, 1.5, 0.0)
	flames.scale_amount_min = 0.5
	flames.scale_amount_max = 1.0
	flames.color = FIRE_COLOR
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.7, 0.3)
	quad.material = material
	flames.mesh = quad
	return flames


# ---------- Вспомогательное ----------

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


func _scene(scene_name: String) -> PackedScene:
	if _scenes.has(scene_name):
		return _scenes[scene_name]
	var path: String = DIR + scene_name + ".glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("GraveyardBuilder: нет модели %s" % path)
	_scenes[scene_name] = scene
	return scene


func _xform(at: Vector3, yaw: float, scale_value: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value), at)
