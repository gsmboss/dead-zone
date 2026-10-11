class_name StageActor
extends Node3D
## Актёр кино-сцены (StoryStage): человек, зомби, бандит или собака. Модель glTF с AnimationPlayer
## идёт по маршруту (или стоит) и играет анимацию по кругу. Без физики и навмеша — только для кино.

## Маршрут в координатах сцены; пустой — стоит на месте
var path := PackedVector3Array()
var speed: float = 1.4
## Идти по кругу (иначе — дошёл и стоит, играя idle_anim)
var loop: bool = true
var move_anim: StringName = &"Walk"
var idle_anim: StringName = &"Idle"
## Встроенный ствол моделей Quaternius Characters_* (Pistol, Shotgun, SMG, Rifle); пусто — без оружия
var held_weapon: String = ""

var _model: Node3D
var _animation_player: AnimationPlayer
var _target: int = 0
var _moving: bool = false
var _current: StringName = &""


## Создать актёра: модель, рост (метры), маршрут; start_t — с какого места первого отрезка начать (0..1)
static func create(scene: PackedScene, height: float, route: PackedVector3Array, walk_speed: float,
		walk_anim: StringName, stand_anim: StringName, start_t: float = 0.0) -> StageActor:
	var actor := StageActor.new()
	actor.path = route
	actor.speed = walk_speed
	actor.move_anim = walk_anim
	actor.idle_anim = stand_anim
	if scene != null:
		actor._model = scene.instantiate() as Node3D
	if actor._model != null:
		actor._model.rotation.y = PI  # модели смотрят в +Z, актёр — в -Z
		actor.add_child(actor._model)
		actor._fit_height(height)
	if not route.is_empty():
		actor.position = route[0] if route.size() < 2 else route[0].lerp(route[1], clampf(start_t, 0.0, 1.0))
		actor._target = mini(1, route.size() - 1)
	return actor


func _ready() -> void:
	if _model == null:
		return
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	_hide_weapons()
	_moving = path.size() > 1
	if _moving:
		_face(path[_target])
	_play(move_anim if _moving else idle_anim)
	# Не в ногу: каждый начинает анимацию с разного места
	if _animation_player != null and _animation_player.current_animation != "":
		_animation_player.seek(randf() * _animation_player.current_animation_length, true)


func _process(delta: float) -> void:
	if not _moving:
		return
	var goal: Vector3 = path[_target]
	var to_goal: Vector3 = goal - position
	to_goal.y = 0.0
	var step: float = speed * delta
	if to_goal.length() <= step:
		position = Vector3(goal.x, position.y, goal.z)
		_target += 1
		if _target >= path.size():
			if not loop:
				_moving = false
				_play(idle_anim)
				return
			# По кругу: мгновенно в начало (точка старта за кадром)
			position = path[0]
			_target = mini(1, path.size() - 1)
		_face(path[_target])
		return
	position += to_goal.normalized() * step


## Сыграть анимацию по кругу (dance, wave и т.п. для отдельных моментов)
func play(anim: StringName) -> void:
	_play(anim)


func _play(anim: StringName) -> void:
	if _animation_player == null or anim == _current or not _animation_player.has_animation(anim):
		return
	_current = anim
	var animation: Animation = _animation_player.get_animation(anim)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(anim, 0.2)


func _face(point: Vector3) -> void:
	var direction := Vector3(point.x - position.x, 0.0, point.z - position.z)
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(-direction.x, -direction.z)


## Оружие в моделях Quaternius — отдельные меши без скина: оставляем только held_weapon
func _hide_weapons() -> void:
	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	var has_skinned: bool = false
	for node: Node in meshes:
		if (node as MeshInstance3D).skin != null:
			has_skinned = true
			break
	if not has_skinned:
		return
	for node: Node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			var weapon_name: String = String(mesh_instance.name)
			mesh_instance.visible = not held_weapon.is_empty() and (weapon_name == held_weapon \
				or String(mesh_instance.get_parent().name) == held_weapon)


## Рост модели по габаритам (у Quaternius тело — скинованные меши, оружие не считается)
func _fit_height(height: float) -> void:
	var bounds := AABB()
	var has_bounds: bool = false
	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	var has_skinned: bool = false
	for node: Node in meshes:
		if (node as MeshInstance3D).skin != null:
			has_skinned = true
			break
	for node: Node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or (has_skinned and mesh_instance.skin == null):
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != _model:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		var mesh_bounds: AABB = xform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	if not has_bounds or bounds.size.y <= 0.01:
		return
	var k: float = height / bounds.size.y
	_model.scale = Vector3.ONE * k
	_model.position.y = -bounds.position.y * k
