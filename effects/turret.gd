class_name Turret
extends Deployable
## Турель на треноге: ищет ближайшего зомби в RANGE с прямой видимостью, поворачивает голову
## и стреляет очередями (урон — item.amount за выстрел). Кончились патроны — исчезает.

const RANGE: float = 16.0
const AMMO: int = 120
const FIRE_INTERVAL: float = 0.18
## Как быстро поворачивается голова (рад/с) и при каком угле уже стреляет
const TURN_SPEED: float = 7.0
const AIM_TOLERANCE: float = 0.25
const HEAD_HEIGHT: float = 0.95
const SHOT_SOUND: AudioStream = preload("res://audio/weapons/rifle_shot.ogg")
## Подсветка заряда: зелёный → красный к концу патронов
const FULL_COLOR: Color = Color(0.3, 1.0, 0.4)
const EMPTY_COLOR: Color = Color(1.0, 0.25, 0.15)

var _ammo: int = AMMO
var _target: Zombie
var _fire_left: float = 0.0
var _head: Node3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_left: float = 0.0
var _lamp_material: StandardMaterial3D
var _ammo_label: Label3D
var _ray: PhysicsRayQueryParameters3D


func _build() -> void:
	var steel := Color(0.32, 0.35, 0.38)
	# Тренога
	for i in 3:
		var angle: float = i * TAU / 3.0
		var leg := CylinderMesh.new()
		leg.top_radius = 0.03
		leg.bottom_radius = 0.035
		leg.height = 0.85
		var leg_instance := _add_mesh(leg, steel, Vector3(sin(angle) * 0.2, 0.38, cos(angle) * 0.2))
		leg_instance.rotation = Vector3(-cos(angle) * 0.45, 0.0, sin(angle) * 0.45)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.07
	post.height = 0.3
	_add_mesh(post, steel, Vector3(0.0, 0.78, 0.0))
	# Голова: корпус, ствол, щиток, лампа
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	add_child(_head)
	var body := BoxMesh.new()
	body.size = Vector3(0.32, 0.24, 0.46)
	_add_mesh(body, Color(0.36, 0.42, 0.3), Vector3.ZERO, _head)
	var shield := BoxMesh.new()
	shield.size = Vector3(0.5, 0.3, 0.04)
	_add_mesh(shield, Color(0.3, 0.34, 0.27), Vector3(0.0, 0.02, 0.26), _head)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.035
	barrel.bottom_radius = 0.04
	barrel.height = 0.55
	var barrel_instance := _add_mesh(barrel, Color(0.15, 0.15, 0.16), Vector3(0.0, 0.03, 0.5), _head)
	barrel_instance.rotation.x = PI * 0.5
	var lamp := SphereMesh.new()
	lamp.radius = 0.04
	lamp.height = 0.08
	var lamp_instance := _add_mesh(lamp, FULL_COLOR, Vector3(0.0, 0.14, -0.12), _head, 2.0)
	_lamp_material = lamp_instance.material_override as StandardMaterial3D
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.03, 0.8)
	_head.add_child(_muzzle)
	var flash := SphereMesh.new()
	flash.radius = 0.09
	flash.height = 0.18
	_flash = _add_mesh(flash, Color(1.0, 0.8, 0.35), Vector3.ZERO, _muzzle, 6.0)
	_flash.visible = false
	# Остаток патронов над турелью
	_ammo_label = Label3D.new()
	_ammo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ammo_label.font_size = 48
	_ammo_label.outline_size = 12
	_ammo_label.pixel_size = 0.004
	_ammo_label.position = Vector3(0.0, HEAD_HEIGHT + 0.45, 0.0)
	_ammo_label.text = str(_ammo)
	add_child(_ammo_label)
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = PhysicsLayers.WORLD


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
	if _removing or _head == null:
		return
	_fire_left = maxf(_fire_left - delta, 0.0)
	if not _is_valid_target(_target):
		_target = null
		return
	# Поворот головы к груди цели (в локальных осях турели)
	var aim_point: Vector3 = _target.global_position + Vector3.UP * 1.1
	var local: Vector3 = to_local(aim_point) - _head.position
	var wanted_yaw: float = atan2(local.x, local.z)
	var wanted_pitch: float = -atan2(local.y, Vector2(local.x, local.z).length())
	_head.rotation.y = rotate_toward(_head.rotation.y, wanted_yaw, TURN_SPEED * delta)
	_head.rotation.x = rotate_toward(_head.rotation.x, wanted_pitch, TURN_SPEED * delta)
	if absf(angle_difference(_head.rotation.y, wanted_yaw)) < AIM_TOLERANCE and _fire_left <= 0.0:
		_shoot(aim_point)


func _check(_delta: float) -> void:
	if _is_valid_target(_target) and _can_see(_target):
		return
	_target = null
	var candidate: Zombie = _nearest_zombie(RANGE, 4.0)
	if candidate != null and _can_see(candidate):
		_target = candidate


func _shoot(aim_point: Vector3) -> void:
	_fire_left = FIRE_INTERVAL
	_ammo -= 1
	_ammo_label.text = str(_ammo)
	var charge: float = float(_ammo) / float(AMMO)
	_lamp_material.albedo_color = EMPTY_COLOR.lerp(FULL_COLOR, charge)
	_lamp_material.emission = _lamp_material.albedo_color
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash_left = 0.05
	_head.position.z = -0.04  # отдача, возвращается твином
	create_tween().tween_property(_head, "position:z", 0.0, FIRE_INTERVAL * 0.8)
	Sfx.play_3d(SHOT_SOUND, _muzzle.global_position, -7.0, 1.15)
	# Небольшой разброс: попадает почти всегда
	var spread := Vector3(randf_range(-0.15, 0.15), randf_range(-0.2, 0.25), randf_range(-0.15, 0.15))
	var hit_point: Vector3 = aim_point + spread
	if _target.health != null:
		_target.health.take_damage(float(item.amount) if item != null else 14.0, hit_point, false)
	Impacts.spawn(hit_point, (_muzzle.global_position - hit_point).normalized(), true)
	if _ammo <= 0:
		_ammo_label.text = UIKit.t("ПУСТО")
		_target = null
		remove()


func _is_valid_target(zombie: Zombie) -> bool:
	if zombie == null or not is_instance_valid(zombie) or zombie.state == Zombie.State.DEAD:
		return false
	return global_position.distance_squared_to(zombie.global_position) <= RANGE * RANGE


## Луч от ствола до груди зомби не упирается в стену
func _can_see(zombie: Zombie) -> bool:
	_ray.from = global_position + Vector3.UP * HEAD_HEIGHT
	_ray.to = zombie.global_position + Vector3.UP * 1.1
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()
