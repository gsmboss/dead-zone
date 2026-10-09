class_name DriveController
extends Node
## Посадка в машины уровня (группа drivable_cars) и выход из них.
## Рядом с машиной появляется кнопка «СЕСТЬ» (или E), в машине — «ВЫЙТИ».
## Пока игрок в машине: он спрятан на крыше (зомби видят и атакуют его), джойстик рулит,
## кнопка прыжка становится «ДРИФТ» (ручник, Space), показаны спидометр и очки дрифта.
## По сети: место просим у хоста (Net.request_car_seat), садимся по рассылке мест;
## второй и следующие садятся пассажирами — едут вместе и стреляют из окна.
## Зомби бьют машину (DrivableCar.take_damage): полоска КУЗОВ, дым, на нуле — поломка.
## Рядом с побитой машиной кнопка «ЧИНИТЬ» (H): держать, пока не починится; с ломом — быстрее.

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
## Дрифт: очки = скорость × время в заносе × множитель; занос прервался дольше паузы — очки в копилку
const DRIFT_POINTS_RATE: float = 12.0
const DRIFT_END_PAUSE: float = 0.7
## Монеты за дрифт (только в одиночной игре): очки / делитель, не больше максимума за раз
const DRIFT_COINS_DIVISOR: float = 400.0
const DRIFT_COINS_MAX: int = 25
## Запрос места по сети: повторно не раньше
const SEAT_REQUEST_COOLDOWN: float = 1.0
## Ремонт с нуля: с ломом (тратится 1) и без него, секунд; частично побитая — быстрее
const REPAIR_TIME_SCRAP: float = 3.0
const REPAIR_TIME_BARE: float = 8.0
const REPAIR_MIN_SHARE: float = 0.3
const REPAIR_TICK: float = 0.35
const REPAIR_DISTANCE: float = 4.5

var _player: Player
var _touch_controls: TouchControls
var _button: TouchActionButton
var _speed_label: Label
var _drift_label: Label
var _hud_layer: CanvasLayer
var _car: DrivableCar          # машина, в которой сидим
var _nearby: DrivableCar       # ближайшая машина рядом
var _check_timer: float = 0.0
var _saved_layer: int = 0
var _saved_mask: int = 0
var _hidden_buttons: Array[TouchActionButton] = []
var _drift_button: TouchActionButton
var _drift_button_label: String = ""
var _drift_button_icon: Texture2D
var _shot_cooldown: float = 0.0
var _shot_sound: AudioStream
var _drift_points: float = 0.0
var _drift_pause: float = 0.0
var _request_cooldown: float = 0.0
var _repair_button: TouchActionButton
var _repair_target: DrivableCar
var _repair_progress: float = 0.0
var _repair_tick: float = 0.0
var _health_bar: CarHealthBar
var _status_label: Label


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
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
	_build_drift_label()
	_build_damage_hud()
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
		_repair_button = TouchActionButton.new()
		_repair_button.action = &"repair"
		_repair_button.label = "ЧИНИТЬ"
		_repair_button.base_color = Color(0.75, 0.45, 0.12)
		_repair_button.use_action_color = false
		_repair_button.name = "RepairButton"
		_touch_controls.add_child(_repair_button)
		_repair_button.anchor_left = 1.0
		_repair_button.anchor_right = 1.0
		_repair_button.anchor_top = 0.5
		_repair_button.anchor_bottom = 0.5
		_repair_button.offset_left = -BUTTON_SIZE - 40.0
		_repair_button.offset_right = -40.0
		_repair_button.offset_top = -BUTTON_SIZE * 1.5 - 60.0
		_repair_button.offset_bottom = -BUTTON_SIZE * 0.5 - 60.0
		_repair_button.visible = false
		_touch_controls.register_button(_repair_button)
	# По сети садимся по рассылке мест от хоста
	for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
		var car := node as DrivableCar
		if car != null:
			car.seats_changed.connect(_on_seats_changed.bind(car))


func _process(delta: float) -> void:
	if _player == null:
		return
	_request_cooldown = maxf(_request_cooldown - delta, 0.0)
	if _car == null:
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = CHECK_INTERVAL
			_nearby = _find_nearby_car()
			_update_button()
			_update_repair_target()
		_process_repair(delta)
	else:
		_speed_label.text = "%d КМ/Ч" % roundi(_car.get_speed_kmh())
		_update_drift(delta)
		_health_bar.value = _car.get_health_ratio()
		_status_label.visible = _car.is_broken()
		if _car.is_broken():
			_status_label.text = "МАШИНА СЛОМАНА — ВЫЙДИ И ПОЧИНИ"
	if Input.is_action_just_pressed(&"interact"):
		if _car != null:
			_exit_car()
		elif _nearby != null:
			_enter_car(_nearby)


func _physics_process(delta: float) -> void:
	if _car == null or _player == null:
		return
	if _car.is_driven():
		var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		if _touch_controls != null:
			var touch: Vector2 = _touch_controls.get_move_vector()
			if touch.length() > input.length():
				input = touch
		_car.set_input(input.x, -input.y)
		_car.set_handbrake(Input.is_action_pressed(&"jump"))
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
		if car == null:
			continue
		# В одиночной игре — только пустая; по сети — есть свободное место (можно пассажиром)
		if (Net.in_match and not car.has_free_seat()) or (not Net.in_match and car.is_driven()):
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
	var caption: String = "СЕСТЬ"
	if _car != null:
		caption = "ВЫЙТИ"
	elif _nearby != null and _nearby.has_driver():
		caption = "ПАССАЖИР"
	if _button.visible != should_show or _button.label != caption:
		_button.visible = should_show
		_button.label = caption
		# Значок: ключ — сесть за руль, сиденье — пассажиром, дверь — выйти
		_button.set_icon_name({"СЕСТЬ": "car-key", "ПАССАЖИР": "car-seat"}.get(caption, "exit-door"))


## Сесть: в одиночной игре — сразу за руль, по сети — попросить место у хоста
func _enter_car(car: DrivableCar) -> void:
	if Net.in_match:
		if _request_cooldown <= 0.0:
			_request_cooldown = SEAT_REQUEST_COOLDOWN
			Net.request_car_seat(car, 0)
		return
	_sit_in(car, true)


## Посадка своего игрока: водителем или пассажиром
func _sit_in(car: DrivableCar, as_driver: bool) -> void:
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
	_set_repair_target(null)
	_health_bar.visible = true
	_health_bar.value = car.get_health_ratio()
	car.enter(as_driver)
	_setup_drift_button(as_driver)
	_speed_label.visible = true
	_drift_points = 0.0
	_drift_label.visible = false
	_update_button()
	Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 0.8, 0.0)


func _exit_car() -> void:
	if _car == null:
		return
	if _car.is_driven() and absf(_car.speed) > MAX_EXIT_SPEED:
		Sfx.error()  # сначала притормози
		return
	if Net.in_match:
		if _request_cooldown <= 0.0:
			_request_cooldown = SEAT_REQUEST_COOLDOWN
			Net.request_car_seat(_car, -1)  # выйдем по рассылке мест
		return
	_leave_car()


## Выход своего игрока из машины (места уже освобождены)
func _leave_car() -> void:
	var car: DrivableCar = _car
	_car = null
	_bank_drift()
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
	var seat: int = car.get_seat_of(Net.my_id()) if Net.in_match else 0
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.global_position = car.get_exit_position(maxi(seat, 0))
	_player.set_safe_position(_player.global_position)
	_player.velocity = Vector3.ZERO
	_player.collision_layer = _saved_layer
	_player.collision_mask = _saved_mask
	_player.visible = true
	_player.camera.make_current()
	_set_combat_buttons_visible(true)
	_restore_drift_button()
	_speed_label.visible = false
	_drift_label.visible = false
	_health_bar.visible = false
	_status_label.visible = false


## По сети сменились места в машине: садимся, пересаживаемся или выходим
func _on_seats_changed(car: DrivableCar) -> void:
	_refresh_remote_players()
	if _player == null:
		return
	var seat: int = car.get_seat_of(Net.my_id())
	if seat >= 0:
		if _player.health != null and _player.health.is_dead:
			Net.request_car_seat(car, -1)
			return
		if _car == null:
			_sit_in(car, seat == 0)
		elif _car == car and car.is_driven() != (seat == 0):
			car.enter(seat == 0)  # водитель вышел — пассажир остаётся пассажиром, и наоборот
			_setup_drift_button(seat == 0)
	elif _car == car:
		_leave_car()


## Копии других игроков в машинах прячем
func _refresh_remote_players() -> void:
	if not Net.in_match or Net.match_manager == null or not is_instance_valid(Net.match_manager):
		return
	var manager := Net.match_manager as MatchManager
	if manager == null:
		return
	var seated: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
		var car := node as DrivableCar
		if car == null:
			continue
		for peer_id: int in car.seats:
			if peer_id != 0:
				seated[peer_id] = true
	for peer_id: int in Net.players:
		if peer_id != Net.my_id():
			manager.set_proxy_in_car(peer_id, seated.has(peer_id))


## Кнопки стрельбы, прыжка и т.п. в машине не нужны (прыжок водителю — «ДРИФТ»)
func _set_combat_buttons_visible(visible_state: bool) -> void:
	if _touch_controls == null:
		return
	if not visible_state:
		_hidden_buttons.clear()
		for child: Node in _touch_controls.get_children():
			var button := child as TouchActionButton
			if button == null or button == _button or not button.visible:
				continue
			if button.action in [&"pause", &"inventory", &"fire", &"jump"]:
				continue  # стрелять из окна машины можно, прыжок станет ручником
			button.force_release()
			button.visible = false
			_hidden_buttons.append(button)
	else:
		for button: TouchActionButton in _hidden_buttons:
			if is_instance_valid(button):
				button.visible = true
		_hidden_buttons.clear()


## Кнопка прыжка за рулём — «ДРИФТ» (ручник); пассажиру не нужна
func _setup_drift_button(as_driver: bool) -> void:
	if _drift_button == null and _touch_controls != null:
		for child: Node in _touch_controls.get_children():
			var button := child as TouchActionButton
			if button != null and button.action == &"jump":
				_drift_button = button
				_drift_button_label = button.label
				_drift_button_icon = button.icon
				break
	if _drift_button == null:
		return
	_drift_button.force_release()
	_drift_button.label = "ДРИФТ"
	_drift_button.set_icon_name("car-wheel")
	_drift_button.visible = as_driver


func _restore_drift_button() -> void:
	if _drift_button == null or not is_instance_valid(_drift_button):
		return
	_drift_button.force_release()
	_drift_button.label = _drift_button_label
	_drift_button.icon = _drift_button_icon
	_drift_button.visible = true
	_drift_button.queue_redraw()


# ---------- Дрифт ----------

## Очки копятся, пока машина в заносе; занос кончился — очки в копилку (и монеты в одиночной игре)
func _update_drift(delta: float) -> void:
	if not _car.is_driven():
		return
	if _car.is_drifting():
		_drift_pause = DRIFT_END_PAUSE
		_drift_points += _car.get_speed_kmh() * DRIFT_POINTS_RATE * delta * 0.1
		_drift_label.visible = true
		_drift_label.text = "ДРИФТ  %d" % roundi(_drift_points)
		_drift_label.modulate = UIKit.ACCENT.lerp(Color(1.0, 0.3, 0.2), clampf(_drift_points / 3000.0, 0.0, 1.0))
	elif _drift_points > 0.0:
		_drift_pause -= delta
		if _drift_pause <= 0.0:
			_bank_drift()


func _bank_drift() -> void:
	if _drift_points < 1.0:
		_drift_points = 0.0
		return
	var points: int = roundi(_drift_points)
	_drift_points = 0.0
	var coins: int = 0 if Net.in_match else mini(floori(points / DRIFT_COINS_DIVISOR), DRIFT_COINS_MAX)
	_drift_label.text = "ДРИФТ  %d  +%s" % [points, UIKit.coins_text(coins)] if coins > 0 else "ДРИФТ  %d" % points
	_drift_label.modulate = UIKit.GOOD
	_drift_label.visible = true
	if coins > 0:
		GameState.add_coins(coins)
		Sfx.play_2d(Sfx.sounds.purchase, -8.0, 1.2, 0.0)
	_drift_label.pivot_offset = _drift_label.size * 0.5
	_drift_label.scale = Vector2.ONE * 1.3
	var tween := _drift_label.create_tween()
	tween.tween_property(_drift_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void:
		if _drift_points <= 0.0:
			_drift_label.visible = false)


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
	# Погиб в машине: игрок «выпадает» рядом с ней — иначе после воскрешения за рекламу
	# он остался бы выключенным, невидимым и без коллизий
	var car: DrivableCar = _car
	if Net.in_match:
		Net.request_car_seat(car, -1)
	_car = null
	_drift_points = 0.0
	car.exit()
	_restore_player(car)
	if _button != null:
		_button.visible = false


# ---------- Поломка и ремонт ----------

## Ближайшая побитая машина рядом (на ногах) — для кнопки ЧИНИТЬ
func _update_repair_target() -> void:
	var best: DrivableCar
	if _player.health == null or not _player.health.is_dead:
		var best_distance: float = REPAIR_DISTANCE
		for node: Node in get_tree().get_nodes_in_group(DrivableCar.GROUP):
			var car := node as DrivableCar
			if car == null or not car.is_damaged() or (Net.in_match and car.has_driver()):
				continue
			var distance: float = car.distance_to_body(_player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = car
	_set_repair_target(best)


func _set_repair_target(car: DrivableCar) -> void:
	if car != _repair_target:
		_repair_target = car
		_repair_progress = 0.0
	var has_target: bool = car != null
	if _repair_button != null and _repair_button.visible != has_target:
		_repair_button.visible = has_target
	if _car == null:
		_health_bar.visible = has_target
		if has_target:
			_health_bar.value = car.get_health_ratio()
		else:
			_status_label.visible = false


## Держим ЧИНИТЬ: прогресс растёт, стук инструмента; готово — машина целая (с ломом быстрее, лом тратится)
func _process_repair(delta: float) -> void:
	if _repair_target == null or not is_instance_valid(_repair_target):
		return
	_health_bar.value = _repair_target.get_health_ratio()
	if not _repair_target.is_damaged():
		_set_repair_target(null)
		return
	if not Input.is_action_pressed(&"repair"):
		_status_label.visible = _repair_target.is_broken()
		_status_label.text = "МАШИНА СЛОМАНА — ДЕРЖИ «ЧИНИТЬ»"
		return
	var has_scrap: bool = GameState.get_item_count(GameState.SCRAP_ID) > 0
	var full_time: float = REPAIR_TIME_SCRAP if has_scrap else REPAIR_TIME_BARE
	var needed: float = full_time * maxf(1.0 - _repair_target.get_health_ratio(), REPAIR_MIN_SHARE)
	_repair_progress += delta / maxf(needed, 0.1)
	_repair_tick -= delta
	if _repair_tick <= 0.0:
		_repair_tick = REPAIR_TICK
		Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), _repair_target.global_position + Vector3.UP, -6.0,
			randf_range(1.1, 1.4))
	_status_label.visible = true
	_status_label.text = "РЕМОНТ %d%%%s" % [mini(roundi(_repair_progress * 100.0), 100),
		"" if has_scrap else "  (БЕЗ ЛОМА — ДОЛЬШЕ)"]
	if _repair_progress < 1.0:
		return
	if has_scrap:
		GameState.remove_item(GameState.SCRAP_ID, 1)
	if Net.in_match:
		Net.request_car_repair(_repair_target)
	else:
		_repair_target.repair()
	Sfx.play_2d(Sfx.sounds.ui_confirm, -2.0, 1.1, 0.0)
	_status_label.text = "ПОЧИНЕНО!"
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if _status_label != null and _status_label.text == "ПОЧИНЕНО!":
			_status_label.visible = false)
	_set_repair_target(null)


func _build_damage_hud() -> void:
	_health_bar = CarHealthBar.new()
	_health_bar.visible = false
	_hud_layer.add_child(_health_bar)
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_health_bar.offset_left = -160.0
	_health_bar.offset_right = 160.0
	_health_bar.offset_top = -132.0
	_health_bar.offset_bottom = -96.0
	_status_label = UIKit.label("", 34)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(1.0, 0.55, 0.3)
	_status_label.visible = false
	_hud_layer.add_child(_status_label)
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_label.offset_left = -460.0
	_status_label.offset_right = 460.0
	_status_label.offset_top = 150.0
	_status_label.offset_bottom = 200.0


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


func _build_drift_label() -> void:
	_drift_label = Label.new()
	_drift_label.visible = false
	_drift_label.add_theme_font_size_override(&"font_size", 46)
	_drift_label.add_theme_constant_override(&"outline_size", 12)
	_drift_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_drift_label)
	_drift_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_drift_label.offset_left = -300.0
	_drift_label.offset_right = 300.0
	_drift_label.offset_top = 150.0
	_drift_label.offset_bottom = 210.0


## Полоска прочности кузова: зелёная → жёлтая → красная, подпись КУЗОВ N%
class CarHealthBar extends Control:
	var value: float = 1.0:
		set(new_value):
			if not is_equal_approx(value, new_value):
				value = new_value
				queue_redraw()

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
		var fill: Color = Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.8, 0.2), clampf(value * 2.0, 0.0, 1.0)) \
			if value < 0.5 else Color(0.95, 0.8, 0.2).lerp(Color(0.35, 0.85, 0.35), (value - 0.5) * 2.0)
		draw_rect(Rect2(Vector2(3.0, 3.0), Vector2((size.x - 6.0) * clampf(value, 0.0, 1.0), size.y - 6.0)), fill)
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.5), false, 2.0)
		var font: Font = ThemeDB.fallback_font
		var text: String = "КУЗОВ %d%%" % roundi(value * 100.0)
		var font_size: int = 22
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at := Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.0, 0.0, 0.0, 0.8))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
