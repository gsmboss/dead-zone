class_name ImpactPool
extends Node3D
## Автозагрузка "Impacts": переиспользуемые искры попаданий.

const POOL_SIZE: int = 24
const WORLD_COLOR: Color = Color(1.0, 0.85, 0.5)
const FLESH_COLOR: Color = Color(0.65, 0.05, 0.05)

var _pool: Array[CPUParticles3D] = []
var _next: int = 0


func _ready() -> void:
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
