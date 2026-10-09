class_name Companion
extends CharacterBody3D
## Напарник: идёт за игроком (навмеш, без него — напрямую), сам находит ближайшего зомби и атакует —
## пёс кусает, выживший стреляет. Бессмертен, сквозь игрока и зомби проходит (слой 0, маска WORLD).
## Отстал дальше CATCH_UP_DISTANCE — догоняет рывком (переносится к игроку). Пёс иногда приносит
## патроны или аптечку. Ставит MissionManager (и убежище — просто ходит рядом).

const FOLLOW_DISTANCE: float = 2.4
const FOLLOW_SIDE: float = 1.3
const ARRIVE_DISTANCE: float = 0.9
const CATCH_UP_DISTANCE: float = 24.0
## Дальше этого от игрока за зомби не бежит
const LEASH_DISTANCE: float = 16.0
const REPATH_INTERVAL: float = 0.4
const SCAN_INTERVAL: float = 0.35
const CALLOUT_CHANCE: float = 0.25
const CALLOUT_TIME: float = 1.8
const EYE_HEIGHT: float = 1.3
const ZOMBIE_CENTER: float = 1.1

var data: CompanionData
## В убежище: только ходит рядом
var peaceful: bool = false

var _player: Player
var _body: PlayerBody
var _agent: NavigationAgent3D
var _target: Zombie
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _repath_timer: float = 0.0
var _scan_timer: float = 0.0
var _attack_timer: float = 0.0
var _fetch_timer: float = 0.0
var _callout: Label3D
var _callout_left: float = 0.0
var _side: float = 1.0
var _rng := RandomNumberGenerator.new()


## Создать напарника рядом с игроком (null — напарника нет или он не выбран)
static func spawn_for(player: Player, companion: CompanionData, is_peaceful: bool = false) -> Companion:
	if player == null or companion == null or companion.skin == null:
		return null
	var node := Companion.new()
	node.name = "Companion"
	node.data = companion
	node.peaceful = is_peaceful
	var parent: Node = player.get_parent()
	parent.add_child(node)
	node.global_position = player.global_position + player.global_basis.z * 1.5 + player.global_basis.x * 1.2
	return node


func _ready() -> void:
	_rng.randomize()
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	add_to_group(&"companions")
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25 if data.is_dog() else 0.32
	capsule.height = 0.6 if data.is_dog() else 1.7
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_body = PlayerBody.new()
	_body.name = "Body"
	add_child(_body)
	_body.set_skin(data.skin)
	_body.set_weapon(data.weapon)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = ARRIVE_DISTANCE
	_agent.radius = capsule.radius
	add_child(_agent)
	_callout = Label3D.new()
	_callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_callout.font_size = 44
	_callout.outline_size = 10
	_callout.pixel_size = 0.004
	_callout.modulate = Color(1.0, 0.9, 0.55)
	_callout.position.y = 0.95 if data.is_dog() else 2.2
	_callout.visible = false
	add_child(_callout)
	_fetch_timer = data.fetch_interval
	_find_player.call_deferred()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("Companion '%s': игрок не найден" % name)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_update_callout(delta)

	# Игрок в машине или далеко ушёл — догоняем рывком
	var to_player: float = global_position.distance_to(_player.global_position)
	if to_player > CATCH_UP_DISTANCE and _player.visible:
		_teleport_near_player()
		return

	if not peaceful:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = SCAN_INTERVAL
			_target = _find_target()
		_update_fetch(delta)

	var speed: float = 0.0
	if _target != null and _is_alive(_target):
		speed = _fight(delta)
	else:
		_target = null
		speed = _follow(delta)
	_body.update_motion(speed, is_on_floor(), delta)


# ---------- Следовать ----------

func _follow(delta: float) -> float:
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP)
	var spot: Vector3 = _player.global_position - forward * FOLLOW_DISTANCE + right * FOLLOW_SIDE * _side
	var distance: float = _flat(spot - global_position).length()
	if distance < ARRIVE_DISTANCE:
		_stop()
		_face(_player.global_position, delta)
		return 0.0
	var speed: float = data.run_speed if distance > 5.0 else data.walk_speed
	_move_to(spot, speed, delta)
	return speed


# ---------- Бой ----------

## Ближайший живой зомби в поле зрения (и не дальше поводка от игрока)
func _find_target() -> Zombie:
	var best: Zombie
	var best_distance: float = data.sight_range
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or not _is_alive(zombie) or zombie.net_puppet:
			continue
		var distance: float = global_position.distance_to(zombie.global_position)
		if distance >= best_distance:
			continue
		if zombie.global_position.distance_to(_player.global_position) > LEASH_DISTANCE:
			continue
		if not _can_see(zombie):
			continue
		best = zombie
		best_distance = distance
	if best != null and best != _target and _rng.randf() < CALLOUT_CHANCE:
		_say_callout()
	return best


func _fight(delta: float) -> float:
	var target_position: Vector3 = _target.global_position
	var distance: float = _flat(target_position - global_position).length()
	if distance > data.attack_range or (not data.is_dog() and not _can_see(_target)):
		var speed: float = data.run_speed
		_move_to(target_position, speed, delta)
		return speed
	_stop()
	_face(target_position, delta)
	if _attack_timer <= 0.0:
		_attack_timer = data.attack_interval
		if data.is_dog():
			_bite()
		else:
			_shoot()
	return 0.0


func _bite() -> void:
	_body.play_attack()
	var hit_at: Vector3 = _target.global_position + Vector3.UP * 0.5
	_target.health.take_damage(data.damage, hit_at, false)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(hit_at, (global_position - hit_at).normalized(), true)


func _shoot() -> void:
	_body.on_fired(data.weapon)
	if data.weapon != null and data.weapon.fire_sound != null:
		Sfx.play_3d(data.weapon.fire_sound, global_position + Vector3.UP * EYE_HEIGHT, -6.0,
			data.weapon.fire_pitch * _rng.randf_range(0.95, 1.05))
	if _rng.randf() > data.accuracy:
		return  # промах
	var hit_at: Vector3 = _target.global_position + Vector3.UP * ZOMBIE_CENTER
	_target.health.take_damage(data.damage, hit_at, false)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(hit_at, (global_position + Vector3.UP * EYE_HEIGHT - hit_at).normalized(), true)


func _can_see(zombie: Zombie) -> bool:
	var from: Vector3 = global_position + Vector3.UP * (0.4 if data.is_dog() else EYE_HEIGHT)
	var to: Vector3 = zombie.global_position + Vector3.UP * ZOMBIE_CENTER
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.exclude = [get_rid(), zombie.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _is_alive(zombie: Zombie) -> bool:
	return is_instance_valid(zombie) and zombie.is_inside_tree() and zombie.health != null \
		and not zombie.health.is_dead


# ---------- Пёс приносит припасы ----------

func _update_fetch(delta: float) -> void:
	if data.fetch_interval <= 0.0:
		return
	_fetch_timer -= delta
	if _fetch_timer > 0.0:
		return
	_fetch_timer = data.fetch_interval
	var pickup := Pickup.new()
	var low_health: bool = _player.health != null and _player.health.current < _player.health.max_health * 0.5
	pickup.kind = Pickup.Kind.HEALTH if low_health else Pickup.Kind.AMMO
	pickup.amount = 25.0 if low_health else 0.3
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3.UP * 0.2
	_say(UIKit.t("ГАВ! ПРИНЁС АПТЕЧКУ") if low_health else UIKit.t("ГАВ! ПРИНЁС ПАТРОНЫ"))


# ---------- Движение ----------

func _move_to(point: Vector3, speed: float, delta: float) -> void:
	var next: Vector3 = point
	if _is_navigation_ready():
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = REPATH_INTERVAL
			_agent.target_position = point
		if not _agent.is_navigation_finished():
			next = _agent.get_next_path_position()
	var direction: Vector3 = _flat(next - global_position)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if direction.length_squared() > 0.0001:
		_face(global_position + direction, delta)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _face(point: Vector3, delta: float) -> void:
	var direction: Vector3 = _flat(point - global_position)
	if direction.length_squared() < 0.0001:
		return
	# Тело смотрит в -Z
	var yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(10.0 * delta, 0.0, 1.0))


func _teleport_near_player() -> void:
	var point: Vector3 = _player.global_position + _player.global_basis.z * 2.0
	if _is_navigation_ready():
		point = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), point)
	global_position = point + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_target = null


func _is_navigation_ready() -> bool:
	return _agent != null and NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


# ---------- Реплики ----------

func _say_callout() -> void:
	var line: String = VoiceOver.pick_random_line(data.callouts_ru, data.callouts_en)
	if not line.is_empty():
		_say(line)


func _say(text: String) -> void:
	_callout.text = text
	_callout.visible = true
	_callout_left = CALLOUT_TIME


func _update_callout(delta: float) -> void:
	if _callout_left <= 0.0:
		return
	_callout_left -= delta
	if _callout_left <= 0.0:
		_callout.visible = false
