class_name Survivor
extends CharacterBody3D
## Выживший в городе: ждёт и машет, подойди — идёт за игроком; доведи до точки
## эвакуации (EvacPoint) — награда. Зомби его не трогают (цель зомби — игрок).

enum State { WAITING, FOLLOWING, RESCUED }

const GROUP: StringName = &"survivors"
const NOTICE_DISTANCE: float = 16.0
const JOIN_DISTANCE: float = 3.0
const FOLLOW_DISTANCE: float = 2.5
const WALK_SPEED: float = 2.2
const RUN_SPEED: float = 5.0
const RUN_DISTANCE: float = 7.0
## Слишком отстал (игрок уехал на машине) — догоняет телепортом рядом с игроком
const TELEPORT_DISTANCE: float = 45.0
const PATH_INTERVAL: float = 0.3

@export var model_scene: PackedScene
@export var model_scale: float = 1.6
@export var reward_coins: int = 100

var state: State = State.WAITING

var _player: Player
var _agent: NavigationAgent3D
var _animation: AnimationPlayer
var _label: Label3D
var _path_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position = Vector3.UP * 0.9
	add_child(shape)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.0
	add_child(_agent)
	_build_model()
	_label = Label3D.new()
	_label.text = "ПОМОГИТЕ!"
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.55, 1.0, 0.55)
	_label.position.y = 2.5
	add_child(_label)
	_register.call_deferred()


func _register() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if manager != null:
		manager.register_survivor()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _player == null or state == State.RESCUED:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	match state:
		State.WAITING:
			velocity.x = 0.0
			velocity.z = 0.0
			if distance <= NOTICE_DISTANCE and distance > 0.1:
				rotation.y = lerp_angle(rotation.y, atan2(-to_player.x, -to_player.z), clampf(4.0 * delta, 0.0, 1.0))
				_play(&"Wave")
			else:
				_play(&"Idle")
			if distance <= JOIN_DISTANCE and _player.visible:
				state = State.FOLLOWING
				_label.text = "ИДУ ЗА ТОБОЙ"
				Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.1, 0.0)
		State.FOLLOWING:
			_follow(distance, delta)
	move_and_slide()


func _follow(distance: float, delta: float) -> void:
	if distance > TELEPORT_DISTANCE:
		global_position = _player.global_position + _player.global_basis.z * 2.0 + Vector3.UP * 0.3
		return
	if distance <= FOLLOW_DISTANCE:
		velocity.x = 0.0
		velocity.z = 0.0
		_play(&"Idle")
		return
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = PATH_INTERVAL
		_agent.target_position = _player.global_position
	var next: Vector3 = _agent.get_next_path_position()
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = _player.global_position - global_position
		direction.y = 0.0
	direction = direction.normalized()
	var speed: float = RUN_SPEED if distance > RUN_DISTANCE else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(8.0 * delta, 0.0, 1.0))
	_play(&"Run" if speed > WALK_SPEED else &"Walk")


## Вызывает EvacPoint, когда выживший дошёл
func rescue() -> void:
	if state != State.FOLLOWING:
		return
	state = State.RESCUED
	_label.text = "СПАСЁН!"
	_play(&"Yes")
	GameState.add_coins(reward_coins)
	GameState.report_event(&"rescue")
	var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if manager != null:
		manager.on_survivor_rescued(reward_coins)
	var fade := create_tween()
	fade.tween_interval(1.5)
	fade.tween_callback(queue_free)


func _play(anim: StringName) -> void:
	if _animation == null or not _animation.has_animation(anim):
		return
	if _animation.current_animation != anim:
		_animation.play(anim, 0.2)


func _build_model() -> void:
	if model_scene == null:
		push_warning("Survivor '%s': не задана model_scene" % name)
		return
	var model := model_scene.instantiate() as Node3D
	if model == null:
		return
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = PI  # модели Quaternius смотрят в +Z
	add_child(model)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0] as AnimationPlayer
		for anim: StringName in [&"Idle", &"Walk", &"Run", &"Wave"]:
			if _animation.has_animation(anim):
				_animation.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
