class_name PlayerBody
extends Node3D
## Видимое тело игрока: модель скина (PlayerSkin), анимации по движению, оружие в руке,
## вспышка выстрела. Используется в виде от 3-го лица и для других игроков в мультиплеере.
## Модели Quaternius и Kenney смотрят в +Z — тело разворачивается к -Z (вперёд игрока).

const BLEND_TIME: float = 0.15
## Быстрее этого (м/с) — анимация ходьбы, ещё быстрее порога — бега
const MOVE_THRESHOLD: float = 0.3
const RUN_THRESHOLD: float = 3.2
const FLASH_TIME: float = 0.06

var skin: PlayerSkin

var _model: Node3D
var _animation_player: AnimationPlayer
var _hand: BoneAttachment3D
var _weapon_model: Node3D
var _flash: OmniLight3D
var _flash_left: float = 0.0
var _current_anim: StringName = &""
var _one_shot_left: float = 0.0
var _dead: bool = false
## Оружие, встроенное в модель (у выживших Quaternius все стволы уже в руке): имя → меш
var _builtin_weapons: Dictionary = {}
## В руках огнестрел — стрелковая стойка (Idle_Gun и т.п.)
var _armed: bool = false
var _shadow_only: bool = false


## Сменить скин. null — скин по умолчанию из GameState
func set_skin(new_skin: PlayerSkin) -> void:
	if new_skin == null or new_skin.model_scene == null:
		push_warning("PlayerBody: пустой скин")
		return
	skin = new_skin
	if _model != null:
		_model.queue_free()
	_model = new_skin.model_scene.instantiate() as Node3D
	if _model == null:
		push_warning("PlayerBody: модель скина '%s' не Node3D" % new_skin.id)
		return
	_model.name = "Model"
	add_child(_model)
	_model.rotation.y = PI
	_collect_builtin_weapons()
	_fit_height(_model, new_skin.height)
	_animation_player = _find_animation_player(_model)
	if _animation_player != null:
		for anim: StringName in [new_skin.anim_idle, new_skin.anim_walk, new_skin.anim_run,
				new_skin.anim_idle_unarmed, new_skin.anim_walk_unarmed, new_skin.anim_run_unarmed]:
			if _animation_player.has_animation(anim):
				_animation_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_create_hand()
	_current_anim = &""
	_play(new_skin.anim_idle)
	if _shadow_only:
		set_shadow_only(true)


## Оружие в руке (null — пустые руки)
func set_weapon(weapon: WeaponData) -> void:
	if _weapon_model != null:
		_weapon_model.queue_free()
		_weapon_model = null
	for builtin: Node3D in _builtin_weapons.values():
		builtin.visible = false
	_armed = weapon != null and not weapon.is_melee and (skin == null or not skin.hide_weapon)
	_current_anim = &""  # сменить стойку сразу
	if weapon == null or weapon.view_model == null or skin == null or skin.hide_weapon:
		return
	# Такой же ствол уже есть в модели и правильно лежит в руке — просто показываем его
	var key: String = weapon.view_model.resource_path.get_file().get_basename()
	if _builtin_weapons.has(key):
		(_builtin_weapons[key] as Node3D).visible = true
		return
	if _hand == null:
		return
	_weapon_model = weapon.view_model.instantiate() as Node3D
	if _weapon_model == null:
		return
	_hand.add_child(_weapon_model)
	# Кость внутри отмасштабированной модели: метры переводим в её единицы
	var model_scale: float = maxf(_model.scale.x, 0.001)
	_weapon_model.position = skin.hand_offset / model_scale
	_weapon_model.rotation_degrees = skin.hand_rotation_degrees
	_fit_length(_weapon_model, skin.weapon_length / model_scale)


## Анимация по движению: скорость по земле, на земле ли, жив ли
func update_motion(horizontal_speed: float, on_floor: bool, delta: float) -> void:
	if skin == null or _animation_player == null or _dead:
		return
	if _one_shot_left > 0.0:
		_one_shot_left -= delta
		return
	if not on_floor:
		_play(skin.anim_jump)
		_animation_player.speed_scale = 1.0
		return
	if horizontal_speed < MOVE_THRESHOLD:
		_play(skin.anim_idle if _armed else skin.anim_idle_unarmed)
		_animation_player.speed_scale = 1.0
	elif horizontal_speed < RUN_THRESHOLD:
		_play(skin.anim_walk if _armed else skin.anim_walk_unarmed)
		_animation_player.speed_scale = clampf(horizontal_speed / skin.walk_anim_speed, 0.5, 2.0)
	else:
		_play(skin.anim_run if _armed else skin.anim_run_unarmed)
		_animation_player.speed_scale = clampf(horizontal_speed / skin.run_anim_speed, 0.6, 1.8)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0 and _flash != null:
			_flash.visible = false


## Выстрел: вспышка у руки; удар ближнего боя — анимация замаха
func on_fired(weapon: WeaponData) -> void:
	if weapon != null and weapon.is_melee:
		_play_once(skin.anim_melee if skin != null else &"")
		return
	if _flash != null:
		_flash.visible = true
		_flash_left = FLASH_TIME


## Приветствие (лобби): один раз, потом снова покой
func play_emote() -> void:
	if skin != null and not _dead:
		_play_once(skin.anim_emote)


func on_hit() -> void:
	if skin != null and not _dead:
		_play_once(skin.anim_hit)


func on_died() -> void:
	if skin == null or _dead:
		return
	_dead = true
	if _animation_player != null and _animation_player.has_animation(skin.anim_death):
		_animation_player.get_animation(skin.anim_death).loop_mode = Animation.LOOP_NONE
		_animation_player.speed_scale = 1.0
		_animation_player.play(skin.anim_death, BLEND_TIME)


func revive() -> void:
	_dead = false
	_current_anim = &""
	if skin != null:
		_play(skin.anim_idle)


## Тени без отрисовки самого тела (вид от 1-го лица)
func set_shadow_only(enabled: bool) -> void:
	_shadow_only = enabled
	if _model == null:
		return
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
			if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _play(anim: StringName) -> void:
	if anim == _current_anim or _animation_player == null or not _animation_player.has_animation(anim):
		return
	_current_anim = anim
	_animation_player.play(anim, BLEND_TIME)


func _play_once(anim: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(anim):
		return
	var animation: Animation = _animation_player.get_animation(anim)
	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.speed_scale = 1.0
	_animation_player.play(anim, 0.05)
	_current_anim = anim
	_one_shot_left = animation.length * 0.8


func _create_hand() -> void:
	_hand = null
	_weapon_model = null
	if skin.hand_bone == &"":
		return
	var skeletons: Array[Node] = _model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.find_bone(skin.hand_bone) < 0:
		push_warning("PlayerBody: у скина '%s' нет кости %s" % [skin.id, skin.hand_bone])
		return
	_hand = BoneAttachment3D.new()
	_hand.bone_name = skin.hand_bone
	skeleton.add_child(_hand)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.light_energy = 3.0
	_flash.omni_range = 3.0
	_flash.visible = false
	_flash.position = (skin.hand_offset + Vector3(0.0, skin.weapon_length, 0.0)) / maxf(_model.scale.x, 0.001)
	_hand.add_child(_flash)


## Нескинованные меши в модели со скелетом — это оружие в руке: прячем, показываем нужное
func _collect_builtin_weapons() -> void:
	_builtin_weapons.clear()
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
			mesh_instance.visible = false
			_builtin_weapons[String(mesh_instance.name)] = mesh_instance


func _find_animation_player(root: Node) -> AnimationPlayer:
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


## Масштаб модели под рост: по габаритам всех мешей в позе покоя
func _fit_height(model: Node3D, target_height: float) -> void:
	var bounds: AABB = _measure(model)
	if bounds.size.y <= 0.01:
		return
	var k: float = target_height / bounds.size.y
	model.scale = Vector3.ONE * k
	model.position.y = -bounds.position.y * k  # ноги на полу


## Масштаб оружия: самая длинная сторона = length
func _fit_length(model: Node3D, length: float) -> void:
	var bounds: AABB = _measure(model)
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.001:
		return
	model.scale = Vector3.ONE * (length / longest)


## Габариты мешей; если в модели есть скинованные (тело) — только по ним, без оружия
func _measure(model: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds: bool = false
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	var has_skinned: bool = false
	for node: Node in meshes:
		if (node as MeshInstance3D).skin != null:
			has_skinned = true
			break
	for node: Node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if has_skinned and mesh_instance.skin == null:
			continue
		var local: AABB = _transform_to(mesh_instance, model) * mesh_instance.get_aabb()
		bounds = bounds.merge(local) if has_bounds else local
		has_bounds = true
	return bounds


## Трансформ node в координатах root без учёта трансформа самого root
func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		var current_3d := current as Node3D
		if current_3d != null:
			result = current_3d.transform * result
		current = current.get_parent()
	return result
