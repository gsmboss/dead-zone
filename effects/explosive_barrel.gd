class_name ExplosiveBarrel
extends Node3D
## Взрывная бочка: компонент тела-декорации (StaticProp с моделью бочки). Попадание пули или взрыв
## рядом — искры и шипение, через миг взрыв (урон зомби и игроку, огонь); соседние бочки — цепной реакцией.
## Бочка подкрашена красным, чтобы было видно, что она взрывается. По сети взрыв рассылается всем.

const GROUP: StringName = &"explosive_barrel"
const MAX_HEALTH: float = 25.0
const BLAST_RADIUS: float = 5.0
const BLAST_DAMAGE: float = 130.0
const PLAYER_DAMAGE_SCALE: float = 0.6
## После попадания — короткое шипение, чтобы игрок успел понять, что сейчас рванёт
const FUSE_TIME: float = 0.35
const SPARK_INTERVAL: float = 0.07
const FIRE_RADIUS: float = 2.2
const FIRE_DPS: float = 14.0
const FIRE_TIME: float = 4.0
const TINT: Color = Color(0.9, 0.1, 0.05, 0.38)

var _prop: Node3D
var _bounds: AABB
var _health: Health
var _fuse: float = -1.0
var _spark_timer: float = 0.0
var _exploded: bool = false


const BARREL_MODEL: String = "res://models/environment/Barrel.gltf"


## Поставить взрывную бочку (StaticProp с моделью) в точку at. Имя по номеру — одинаково у всех
## игроков по сети (взрыв рассылается по пути узла)
static func spawn(parent: Node3D, at: Vector3, index: int) -> StaticProp:
	if parent == null or not ResourceLoader.exists(BARREL_MODEL):
		return null
	var scene := load(BARREL_MODEL) as PackedScene
	var model := scene.instantiate() as Node3D if scene != null else null
	if model == null:
		return null
	var prop := StaticProp.new()
	prop.name = "ExplosiveBarrel_%d" % index
	prop.explosive = true
	prop.position = at
	model.name = "Model"
	prop.add_child(model)
	parent.add_child(prop)
	return prop


## Сделать декорацию взрывной. bounds — габариты модели в осях prop
static func attach(prop: Node3D, bounds: AABB) -> ExplosiveBarrel:
	if prop == null or bounds.size == Vector3.ZERO or prop.has_node(^"ExplosiveBarrel"):
		return null
	var barrel := ExplosiveBarrel.new()
	barrel.name = "ExplosiveBarrel"
	barrel._prop = prop
	barrel._bounds = bounds
	prop.add_child(barrel)
	return barrel


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false)
	_health = Health.new()
	_health.name = "Health"
	_health.max_health = MAX_HEALTH
	add_child(_health)
	_health.died.connect(_on_shot_down)

	# Хитбокс чуть больше коробки коллизии — пули попадают в него, а не в стену-коробку
	var hitbox := Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.health = _health
	hitbox.flesh = false
	hitbox.auto_target = false
	var cylinder := CylinderShape3D.new()
	cylinder.radius = maxf(_bounds.size.x, _bounds.size.z) * 0.5 + 0.06
	cylinder.height = _bounds.size.y + 0.1
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position = _bounds.get_center()
	hitbox.add_child(shape)
	add_child(hitbox)
	_tint()


func _process(delta: float) -> void:
	if _fuse < 0.0:
		return
	_fuse -= delta
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = SPARK_INTERVAL
		var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
		if impacts != null:
			impacts.spawn(get_center() + Vector3.UP * _bounds.size.y * 0.5, Vector3.UP, false)
	if _fuse <= 0.0:
		_explode(false)


## Центр бочки в мире
func get_center() -> Vector3:
	return _prop.global_transform * _bounds.get_center() if is_instance_valid(_prop) else global_position


## Поджечь (взрыв рядом): рванёт через delay секунд
func ignite(delay: float) -> void:
	if _exploded or _fuse >= 0.0:
		return
	_fuse = maxf(delay, 0.0)
	set_process(true)


## Взрыв по сообщению другого игрока (без повторной рассылки)
func explode_remote() -> void:
	_explode(true)


func _on_shot_down() -> void:
	if _fuse < 0.0:
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), get_center(), 2.0, 1.4)
	ignite(FUSE_TIME)


func _explode(remote: bool) -> void:
	if _exploded:
		return
	_exploded = true
	set_process(false)
	remove_from_group(GROUP)
	var scene: Node = get_tree().current_scene
	var at: Vector3 = get_center()
	# По сети зомби считает хост: у клиента взрыв ранит только своего игрока
	var host_side: bool = not Net.in_match or Net.is_host()
	var explosion := Explosion.create(scene, at, BLAST_RADIUS, BLAST_DAMAGE, PLAYER_DAMAGE_SCALE)
	if explosion != null:
		explosion.damage_zombies = host_side
	if host_side:
		FireArea.create(scene, Vector3(at.x, _prop.global_position.y, at.z), FIRE_RADIUS, FIRE_DPS, FIRE_TIME)
	if Net.in_match and not remote and is_instance_valid(_prop):
		Net.rpc_barrel_explode.rpc(_prop.get_path())
	if is_instance_valid(_prop):
		_prop.queue_free()


## Красная подкраска поверх модели (видно, что бочка взрывная)
func _tint() -> void:
	if _prop == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = TINT
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for node: Node in _prop.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay
