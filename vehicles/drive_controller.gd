class_name DriveController
extends Node
## Посадка в машины уровня (группа drivable_cars) и выход из них.
## Рядом с машиной появляется кнопка «СЕСТЬ» (или E), в машине — «ВЫЙТИ».
## Пока игрок за рулём: он спрятан на крыше машины (зомби видят и атакуют его),
## джойстик управляет машиной, кнопки стрельбы скрыты, показан спидометр.

const ENTER_DISTANCE: float = 3.8
const CHECK_INTERVAL: float = 0.15
const BUTTON_SIZE: float = 130.0
## Выйти можно только почти на месте
const MAX_EXIT_SPEED: float = 5.0
## Стрельба из окна: пистолет по ближайшему зомби впереди
const CAR_SHOT_INTERVAL: float = 0.25
const CAR_SHOT_RANGE: float = 30.0
const CAR_SHOT_CONE: float = 0.5  # косинус ~60°
const CAR_SHOT_DAMAGE: float = 22.0
const CAR_SHOT_SOUND: String = "res://audio/weapons/pistol_shot.ogg"

var _player: Player
var _touch_controls: TouchControls
var _button: TouchActionButton
var _speed_label: Label
var _hud_layer: CanvasLayer
var _car: DrivableCar          # машина, в которой сидим
var _nearby: DrivableCar       # ближайшая машина рядом
var _check_timer: float = 0.0
var _saved_layer: int = 0
var _saved_mask: int = 0
var _hidden_buttons: Array[TouchActionButton] = []
var _shot_cooldown: float = 0.0
var _shot_sound: AudioStream


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	# По сети машины не синхронизируются — за руль только в одиночной игре
	if Net.in_match:
		set_process(false)
		set_physics_process(false)
		return
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("DriveController: игрок не найден")
		set_process(false)
		set_physics_process(false)
		return
	if _player.health != null:
		_player.health.died.connect(_on_player_died)
	_touch_controls = _player.touch_controls
	if ResourceLoader.exists(CAR_SHOT_SOUND):
		_shot_sound = load(CAR_SHOT_SOUND) as AudioStream
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	_build_speed_label()
	if _touch_controls != null:
		_button = TouchActionButton.new()
		_button.action = &"interact"
		_button.label = "СЕСТЬ"
		_button.base_color = Color(0.2, 0.55, 0.35)
		_button.use_action_color = false
		_button.name = "DriveButton"
		_touch_controls.add_child(_button)
		_button.anchor_left = 1.0
		_button.anchor_right = 1.0
		_button.anchor_top = 0.5
		_button.anchor_bottom = 0.5
		_button.offset_left = -BUTTON_SIZE - 40.0
		_button.offset_right = -40.0
		_button.offset_top = -BUTTON_SIZE * 0.5 - 40.0
		_button.offset_bottom = BUTTON_SIZE * 0.5 - 40.0
		_button.visible = false
		_touch_controls.register_button(_button)


func _process(delta: float) -> void:
	if _player == null:
		return
	if _car == null:
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = CHECK_INTERVAL
			_nearby = _find_nearby_car()
			_update_button()
	else:
		_speed_label.text = "%d КМ/Ч" % roundi(_car.get_speed_kmh())
	if Input.is_action_just_pressed(&"interact"):
		if _car != null:
			_exit_car()
		elif _nearby != null:
			_enter_car(_nearby)


func _physics_process(delta: float) -> void:
	if _car == null or _player == null:
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if _touch_controls != null:
		var touch: Vector2 = _touch_controls.get_move_vector()
		if touch.length() > input.length():
			input = touch
	_car.set_input(input.x, -input.y)
	_shot_cooldown = maxf(_shot_cooldown - delta, 0.0)
	if Input.is_action_pressed(&"fire") and _shot_cooldown <= 0.0:
		_shoot_from_car()
	# Игрок едет на крыше (спрятан): зомби идут к машине и видят цель
	_player.global_position = _car.global_position + Vector3.UP * _car.get_roof_height()


func _find_nearby_car() -> DrivableCar:
	if _player.health != null and _player.health.is_dead:
		return null
	var best: DrivableCar
	var best_distance: float = ENTER_DISTANCE
	for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
		var car := node as DrivableCar
		if car == null or car.is_driven():
			continue
		var distance: float = car.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = car
	return best


func _update_button() -> void:
	if _button == null:
		return
	var should_show: bool = _car != null or _nearby != null
	var caption: String = "ВЫЙТИ" if _car != null else "СЕСТЬ"
	if _button.visible != should_show or _button.label != caption:
		_button.visible = should_show
		_button.label = caption
		_button.queue_redraw()


func _enter_car(car: DrivableCar) -> void:
	_car = car
	_saved_layer = _player.collision_layer
	_saved_mask = _player.collision_mask
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.input_enabled = false
	_player.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	if _player.weapon_manager != null:
		_player.weapon_manager.set_aiming(false)
	_set_combat_buttons_visible(false)
	car.enter()
	_speed_label.visible = true
	_update_button()
	Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 0.8, 0.0)


func _exit_car() -> void:
	if _car == null:
		return
	if absf(_car.speed) > MAX_EXIT_SPEED:
		Sfx.error()  # сначала притормози
		return
	var car: DrivableCar = _car
	_car = null
	car.exit()
	_restore_player(car)
	if _player.health == null or not _player.health.is_dead:
		_player.input_enabled = true
	if _touch_controls != null:
		_touch_controls.consume_look_delta()  # свайпы за рулём не крутят камеру после выхода
	_nearby = car
	_update_button()


## Вернуть игрока из машины: обработка, коллизии, видимость, камера, кнопки
func _restore_player(car: DrivableCar) -> void:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.global_position = car.get_exit_position()
	_player.set_safe_position(_player.global_position)
	_player.velocity = Vector3.ZERO
	_player.collision_layer = _saved_layer
	_player.collision_mask = _saved_mask
	_player.visible = true
	_player.camera.make_current()
	_set_combat_buttons_visible(true)
	_speed_label.visible = false


## Кнопки стрельбы, прыжка и т.п. в машине не нужны
func _set_combat_buttons_visible(visible_state: bool) -> void:
	if _touch_controls == null:
		return
	if not visible_state:
		_hidden_buttons.clear()
		for child: Node in _touch_controls.get_children():
			var button := child as TouchActionButton
			if button == null or button == _button or not button.visible:
				continue
			if button.action in [&"pause", &"inventory", &"fire"]:
				continue  # стрелять из окна машины можно
			button.force_release()
			button.visible = false
			_hidden_buttons.append(button)
	else:
		for button: TouchActionButton in _hidden_buttons:
			if is_instance_valid(button):
				button.visible = true
		_hidden_buttons.clear()


## Выстрел из окна: ближайший видимый зомби в конусе перед камерой машины
func _shoot_from_car() -> void:
	_shot_cooldown = CAR_SHOT_INTERVAL
	var camera: Camera3D = _car.camera
	if camera == null:
		return
	var origin: Vector3 = _car.global_position + Vector3.UP * _car.get_roof_height()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Zombie
	var best_distance: float = CAR_SHOT_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or zombie.health == null or zombie.health.is_dead:
			continue
		var offset: Vector3 = zombie.global_position - origin
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > best_distance or distance < 0.5 or forward.dot(offset / distance) < CAR_SHOT_CONE:
			continue
		best = zombie
		best_distance = distance
	Sfx.play_2d(_shot_sound, -6.0)
	if best == null:
		return
	var target: Vector3 = best.global_position + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(origin, target, PhysicsLayers.WORLD)
	query.exclude = [_car.get_rid()]
	if not _car.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return  # за стеной
	best.health.take_damage(CAR_SHOT_DAMAGE, target, false)
	var impacts := get_node_or_null(^"/root/Impacts") as ImpactPool
	if impacts != null:
		impacts.spawn(target, (origin - target).normalized(), true)


func _on_player_died() -> void:
	if _car == null:
		return
	# Погиб за рулём: игрок «выпадает» рядом с машиной — иначе после воскрешения за рекламу
	# он остался бы выключенным, невидимым и без коллизий
	var car: DrivableCar = _car
	_car = null
	car.exit()
	_restore_player(car)
	if _button != null:
		_button.visible = false


func _build_speed_label() -> void:
	_speed_label = Label.new()
	_speed_label.visible = false
	_speed_label.add_theme_font_size_override(&"font_size", 40)
	_speed_label.add_theme_constant_override(&"outline_size", 10)
	_speed_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_speed_label.modulate = UIKit.ACCENT
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_speed_label)
	_speed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_label.offset_left = -150.0
	_speed_label.offset_right = 150.0
	_speed_label.offset_top = -90.0
	_speed_label.offset_bottom = -30.0
