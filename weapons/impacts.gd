class_name ImpactPool
extends Node3D
## Автозагрузка "Impacts": переиспользуемые искры попаданий и пятна крови.

const POOL_SIZE: int = 24
const WORLD_COLOR: Color = Color(1.0, 0.85, 0.5)
const FLESH_COLOR: Color = Color(0.65, 0.05, 0.05)
## Пятна крови (модели Quaternius), одновременно не больше BLOOD_POOL_SIZE
const BLOOD_PATHS: Array[String] = [
	"res://models/environment/Blood_1.gltf",
	"res://models/environment/Blood_2.gltf",
	"res://models/environment/Blood_3.gltf",
]
const BLOOD_POOL_SIZE: int = 10
const BLOOD_SCALE_MIN: float = 0.35
const BLOOD_SCALE_MAX: float = 0.6
## Над полом, чтобы не мерцало (и над дорогой: она на 0.01 выше пола)
const BLOOD_HEIGHT: float = 0.02

var _pool: Array[CPUParticles3D] = []
var _next: int = 0
var _blood_scenes: Array[PackedScene] = []
var _blood_pool: Array[Node3D] = []
var _blood_next: int = 0
## Контейнер пятен внутри текущей сцены: при смене сцены удаляется вместе с ней
var _blood_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for path: String in BLOOD_PATHS:
		var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene != null:
			_blood_scenes.append(scene)
	if _blood_scenes.is_empty():
		push_warning("Impacts: модели крови не найдены, пятен не будет")

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true

	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material

	for i in POOL_SIZE:
		var particles := CPUParticles3D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 8
		particles.lifetime = 0.35
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.mesh = mesh
		particles.spread = 35.0
		particles.initial_velocity_min = 1.5
		particles.initial_velocity_max = 4.0
		particles.gravity = Vector3(0.0, -9.8, 0.0)
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.2
		add_child(particles)
		_pool.append(particles)


func spawn(hit_position: Vector3, normal: Vector3, is_flesh: bool = false) -> void:
	if _pool.is_empty():
		return
	var particles: CPUParticles3D = _pool[_next]
	_next = (_next + 1) % _pool.size()

	var dir: Vector3 = normal if normal.length_squared() > 0.0001 else Vector3.UP
	particles.global_position = hit_position + dir * 0.02
	particles.direction = dir
	particles.color = FLESH_COLOR if is_flesh else WORLD_COLOR
	particles.restart()


## Пятно крови на полу (смерть зомби). Пул живёт в текущей сцене
func spawn_blood(at: Vector3) -> void:
	if _blood_scenes.is_empty():
		return
	if not _ensure_blood_root():
		return
	var blood: Node3D
	if _blood_pool.size() < BLOOD_POOL_SIZE:
		blood = _blood_scenes[_blood_pool.size() % _blood_scenes.size()].instantiate() as Node3D
		if blood == null:
			return
		_blood_root.add_child(blood)
		_disable_shadows(blood)
		_blood_pool.append(blood)
	else:
		blood = _blood_pool[_blood_next]
		_blood_next = (_blood_next + 1) % BLOOD_POOL_SIZE
	blood.global_position = Vector3(at.x, at.y + BLOOD_HEIGHT, at.z)
	blood.rotation = Vector3(0.0, _rng.randf() * TAU, 0.0)
	blood.scale = Vector3.ONE * _rng.randf_range(BLOOD_SCALE_MIN, BLOOD_SCALE_MAX)
	blood.visible = true


func _ensure_blood_root() -> bool:
	if is_instance_valid(_blood_root) and _blood_root.is_inside_tree():
		return true
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	_blood_pool.clear()
	_blood_next = 0
	_blood_root = Node3D.new()
	_blood_root.name = "BloodDecals"
	scene.add_child(_blood_root)
	return true


func _disable_shadows(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
