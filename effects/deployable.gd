class_name Deployable
extends Node3D
## Ловушка, которую игрок ставит перед собой (кнопка «ЛОВУШКА», B или «ПОСТАВИТЬ» в сумке):
## турель (Turret), капкан (BearTrap), мина (LandMine). Ставится на пол лучом вниз,
## живёт до конца миссии или пока не израсходована. По сети не ставится (зомби ведёт хост).

const GROUP: StringName = &"deployables"
## Насколько впереди игрока
const PLACE_DISTANCE: float = 1.8
## Больше стольких ловушек сразу — самая старая убирается
const MAX_ACTIVE: int = 8
## Как часто ловушки проверяют зомби рядом (чаще не нужно)
const CHECK_INTERVAL: float = 0.12

var item: ItemData
var _check_left: float = 0.0
var _removing: bool = false


## Поставить ловушку item перед игроком. false — некуда (стена, обрыв) или по сети
static func place(item_data: ItemData, player: Player) -> bool:
	if item_data == null or player == null or not player.is_inside_tree():
		return false
	if Net.in_match or player.get_tree().get_first_node_in_group(&"hub_hud") != null:
		return false  # по сети и в убежище не ставятся
	var scene: Node = player.get_tree().current_scene
	if scene == null:
		return false
	var forward: Vector3 = -player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var chest: Vector3 = player.global_position + Vector3.UP * 0.6
	var target: Vector3 = chest + forward * PLACE_DISTANCE
	# Между игроком и местом — стена: ставим ближе к ней
	var wall_query := PhysicsRayQueryParameters3D.create(chest, target, PhysicsLayers.WORLD)
	var wall: Dictionary = space.intersect_ray(wall_query)
	if not wall.is_empty():
		var wall_point: Vector3 = wall["position"]
		var free: float = chest.distance_to(wall_point) - 0.5
		if free < 0.5:
			return false
		target = chest + forward * free
	# Пол под точкой
	var floor_query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 1.0,
		target + Vector3.DOWN * 3.0, PhysicsLayers.WORLD)
	var hit: Dictionary = space.intersect_ray(floor_query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	if normal.y < 0.7:
		return false  # слишком круто
	var deployable: Deployable = _create(item_data.effect)
	if deployable == null:
		return false
	deployable.item = item_data
	_trim_old(player.get_tree())
	scene.add_child(deployable)
	deployable.global_position = hit["position"]
	deployable.rotation.y = atan2(forward.x, forward.z)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), deployable.global_position, -4.0, 0.8)
	return true


static func _create(effect: ItemData.Effect) -> Deployable:
	match effect:
		ItemData.Effect.TURRET:
			return Turret.new()
		ItemData.Effect.TRAP:
			return BearTrap.new()
		ItemData.Effect.MINE:
			return LandMine.new()
	return null


static func _trim_old(tree: SceneTree) -> void:
	var active: Array[Node] = tree.get_nodes_in_group(GROUP)
	var alive: int = 0
	for node: Node in active:
		var deployable := node as Deployable
		if deployable != null and not deployable._removing:
			alive += 1
	for node: Node in active:
		if alive < MAX_ACTIVE:
			return
		var deployable := node as Deployable
		if deployable != null and not deployable._removing:
			deployable.remove()
			alive -= 1


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	# Появление: «вырастает» из пола
	scale = Vector3(0.6, 0.05, 0.6)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _removing:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	_check(CHECK_INTERVAL)


## Израсходована: сжимается и исчезает
func remove() -> void:
	if _removing:
		return
	_removing = true
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.35)
	tween.tween_callback(queue_free)


## Ближайший живой зомби в радиусе (по горизонтали, по высоте ±max_height); null — нет
func _nearest_zombie(radius: float, max_height: float = 1.2) -> Zombie:
	var best: Zombie = null
	var best_distance: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or zombie.state == Zombie.State.DEAD or zombie.net_puppet:
			continue
		var offset: Vector3 = zombie.global_position - global_position
		if absf(offset.y) > max_height:
			continue
		var distance: float = offset.x * offset.x + offset.z * offset.z
		if distance < best_distance:
			best_distance = distance
			best = zombie
	return best


# ---------- Для наследников ----------

## Построить модель (дети-меши)
func _build() -> void:
	pass


## Проверка зомби рядом (раз в CHECK_INTERVAL)
func _check(_delta: float) -> void:
	pass


## Меш-ребёнок с простым материалом
func _add_mesh(mesh: Mesh, color: Color, at: Vector3, parent: Node3D = null,
		emission: float = 0.0) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.metallic = 0.3
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(instance)
	return instance
