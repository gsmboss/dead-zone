class_name ThrownItem
extends RigidBody3D
## Брошенная граната или коктейль Молотова.
## Граната взрывается через fuse секунд, коктейль — при первом ударе (лужа огня).

const GRENADE_FUSE: float = 2.0
const GRENADE_RADIUS: float = 5.0
const MOLOTOV_RADIUS: float = 3.2
const MOLOTOV_DURATION: float = 6.0
const SIZE: float = 0.14

var item: ItemData
var _fuse: float = GRENADE_FUSE
var _done: bool = false


## Создать и бросить из from в направлении velocity
static func throw_item(parent: Node, item_data: ItemData, from: Vector3, throw_velocity: Vector3) -> ThrownItem:
	var thrown := ThrownItem.new()
	thrown.item = item_data
	parent.add_child(thrown)
	thrown.global_position = from
	thrown.linear_velocity = throw_velocity
	thrown.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	return thrown


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.ENEMY
	mass = 0.6
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var sphere := SphereShape3D.new()
	sphere.radius = SIZE
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done or item == null:
		return
	if item.effect == ItemData.Effect.GRENADE:
		_fuse -= delta
		if _fuse <= 0.0:
			_detonate()


func _on_body_entered(_body: Node) -> void:
	if item != null and item.effect == ItemData.Effect.MOLOTOV:
		_detonate.call_deferred()  # разбилась
	else:
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), global_position, -10.0, 1.4)


func _detonate() -> void:
	if _done:
		return
	_done = true
	var parent: Node = get_tree().current_scene
	if item.effect == ItemData.Effect.GRENADE:
		Explosion.create(parent, global_position + Vector3.UP * 0.2, GRENADE_RADIUS, item.amount, 0.5)
	else:
		FireArea.create(parent, global_position, MOLOTOV_RADIUS, item.amount, MOLOTOV_DURATION)
	queue_free()


func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = item.icon_color if item != null else Color.DARK_GREEN
	var mesh: Mesh
	if item != null and item.effect == ItemData.Effect.MOLOTOV:
		var bottle := CylinderMesh.new()
		bottle.top_radius = SIZE * 0.5
		bottle.bottom_radius = SIZE
		bottle.height = SIZE * 3.0
		mesh = bottle
	else:
		var ball := SphereMesh.new()
		ball.radius = SIZE
		ball.height = SIZE * 2.2
		mesh = ball
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
