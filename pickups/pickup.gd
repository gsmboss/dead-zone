class_name Pickup
extends Area3D
## Подбираемый предмет: патроны, аптечка или предмет задания (ящик с припасами).
## Модель создаётся кодом, если у ноды нет дочерних визуальных нод.
## Выпавшие из зомби предметы исчезают через lifetime секунд (мигают в конце).

signal collected(pickup: Pickup)

enum Kind { AMMO, HEALTH, MISSION_ITEM }

const AMMO_MODEL: String = "res://models/environment/Chest.gltf"
const ITEM_MODEL: String = "res://models/environment/Chest_Special.gltf"
const SPIN_SPEED: float = 1.6
const BOB_HEIGHT: float = 0.12
const BOB_SPEED: float = 2.5
const BLINK_TIME: float = 3.0
const PICKUP_RADIUS: float = 0.9
## Как часто проверять игрока, стоящего на ненужном предмете (здоровье потом упало)
const RECHECK_INTERVAL: float = 0.5

@export var kind: Kind = Kind.AMMO
## AMMO: доля от максимального запаса каждого ствола; HEALTH: очки здоровья
@export var amount: float = 0.35
## 0 = лежит вечно
@export var lifetime: float = 0.0

var _visual: Node3D
var _time: float = 0.0
var _base_y: float = 0.0
var _taken: bool = false
var _recheck: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	if kind == Kind.MISSION_ITEM:
		add_to_group(&"mission_items")
	_ensure_shape()
	_visual = _ensure_visual()
	if _visual != null:
		_base_y = _visual.position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _visual != null:
		_visual.rotation.y += SPIN_SPEED * delta
		_visual.position.y = _base_y + (sin(_time * BOB_SPEED) * 0.5 + 0.5) * BOB_HEIGHT
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = RECHECK_INTERVAL
		if has_overlapping_bodies():
			for body: Node3D in get_overlapping_bodies():
				_on_body_entered(body)
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
		elif lifetime < BLINK_TIME and _visual != null:
			_visual.visible = fmod(lifetime, 0.3) > 0.12


func _on_body_entered(body: Node3D) -> void:
	if _taken:
		return
	var player := body as Player
	if player == null or player.health == null or player.health.is_dead:
		return
	if not _apply(player):
		return  # предмет не нужен (полное здоровье / патроны) — остаётся лежать
	_taken = true
	Sfx.play_2d(Sfx.sounds.pickup, -2.0, 1.0, 0.0)
	collected.emit(self)
	queue_free()


func _apply(player: Player) -> bool:
	match kind:
		Kind.AMMO:
			return player.weapon_manager != null and player.weapon_manager.add_reserve_ammo(amount)
		Kind.HEALTH:
			if player.health.current >= player.health.max_health:
				return false
			player.health.heal(amount)
			return true
		Kind.MISSION_ITEM:
			var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
			if manager != null:
				manager.on_item_collected()
			return true
	return false


func _ensure_shape() -> void:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.6, 0.0)
	add_child(shape)


func _ensure_visual() -> Node3D:
	for child: Node in get_children():
		if child is Node3D and not child is CollisionShape3D:
			return child as Node3D
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.position.y = 0.25
	add_child(visual)
	match kind:
		Kind.AMMO:
			_add_model(visual, AMMO_MODEL, 0.9)
		Kind.MISSION_ITEM:
			_add_model(visual, ITEM_MODEL, 1.0)
			_add_beacon(visual)
		Kind.HEALTH:
			_build_medkit(visual)
	return visual


func _add_model(parent: Node3D, path: String, model_scale: float) -> void:
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("Pickup '%s': нет модели %s, показан ящик" % [name, path])
		_add_box(parent, Vector3(0.5, 0.35, 0.4), Vector3(0.0, 0.18, 0.0), Color(0.35, 0.4, 0.25))
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.scale = Vector3.ONE * model_scale
	parent.add_child(model)


## Аптечка: белый ящик с красным крестом
func _build_medkit(parent: Node3D) -> void:
	_add_box(parent, Vector3(0.5, 0.32, 0.36), Vector3(0.0, 0.16, 0.0), Color(0.92, 0.92, 0.9))
	var red := Color(0.85, 0.08, 0.08)
	for side: float in [-1.0, 1.0]:
		var z: float = side * 0.185
		_add_box(parent, Vector3(0.26, 0.08, 0.01), Vector3(0.0, 0.16, z), red)
		_add_box(parent, Vector3(0.08, 0.24, 0.01), Vector3(0.0, 0.16, z), red)


## Световой столб над предметом задания, чтобы его было видно издалека
func _add_beacon(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.85, 0.2, 0.25)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.15
	cylinder.height = 6.0
	cylinder.radial_segments = 8
	cylinder.rings = 1
	cylinder.material = material
	var beam := MeshInstance3D.new()
	beam.mesh = cylinder
	beam.position.y = 3.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)


func _add_box(parent: Node3D, box_size: Vector3, at: Vector3, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position = at
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(box)
