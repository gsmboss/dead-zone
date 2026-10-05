class_name AcidProjectile
extends Area3D
## Комок кислоты плевуна: летит по дуге, ранит игрока, разбивается о стены.

const GRAVITY: float = 6.0
const LIFETIME: float = 4.0
const RADIUS: float = 0.18
const COLOR: Color = Color(0.45, 0.95, 0.2)

var damage: float = 12.0
var _velocity: Vector3 = Vector3.ZERO
var _life: float = LIFETIME


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER
	monitorable = false
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	body_entered.connect(_on_body_entered)


## Запуск из from в target со скоростью speed (с поправкой на падение по дуге)
func launch(from: Vector3, target: Vector3, speed: float) -> void:
	global_position = from
	var offset: Vector3 = target - from
	var time: float = maxf(offset.length() / maxf(speed, 0.1), 0.05)
	_velocity = offset / time + Vector3.UP * GRAVITY * time * 0.5


func _physics_process(delta: float) -> void:
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player != null and player.health != null:
		player.health.take_damage(damage, global_position, false)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(global_position, -_velocity.normalized(), true)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.flesh_hits), global_position, -6.0, 1.4)
	queue_free()
