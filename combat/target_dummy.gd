extends StaticBody3D
## Манекен для проверки стрельбы: мигает при попадании, после «смерти» возрождается.

const FLASH_TIME: float = 0.08

## Пусто → дочерняя нода "Health"
@export var health: Health
## Пусто → дочерние ноды "Body" и "Head"
@export var meshes: Array[GeometryInstance3D] = []
@export var respawn_time: float = 2.0
@export var base_color: Color = Color(0.75, 0.65, 0.5)
@export var hit_color: Color = Color(1.0, 0.15, 0.15)

var _material: StandardMaterial3D
var _flash: float = 0.0
var _hitboxes: Array[Hitbox] = []


func _ready() -> void:
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = 0

	if health == null:
		health = get_node_or_null(^"Health") as Health
	if health == null:
		push_error("TargetDummy '%s': нет ноды Health" % name)
		return

	if meshes.is_empty():
		for node_name: String in ["Body", "Head"]:
			var mesh := get_node_or_null(node_name) as GeometryInstance3D
			if mesh != null:
				meshes.append(mesh)

	# Свой материал на каждый манекен, чтобы мигал только он
	_material = StandardMaterial3D.new()
	_material.albedo_color = base_color
	for mesh: GeometryInstance3D in meshes:
		if mesh != null:
			mesh.material_override = _material

	for child: Node in get_children():
		if child is Hitbox:
			_hitboxes.append(child)

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0:
		_material.albedo_color = base_color


func _on_damaged(_amount: float, _hit_position: Vector3, _is_headshot: bool) -> void:
	_flash = FLASH_TIME
	_material.albedo_color = hit_color


func _on_died() -> void:
	_set_active(false)
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	health.reset()
	_flash = 0.0
	_material.albedo_color = base_color
	_set_active(true)


func _set_active(active: bool) -> void:
	visible = active
	collision_layer = PhysicsLayers.ENEMY if active else 0
	# Выключенные хитбоксы не перекрывают выстрелы
	for hitbox: Hitbox in _hitboxes:
		hitbox.collision_layer = PhysicsLayers.HITBOX if active else 0
