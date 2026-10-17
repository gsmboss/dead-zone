class_name HubLounge
extends Node3D
## Зона отдыха в восточной части двора (мебель Kenney Furniture Kit): два дивана — на них можно сесть
## (кнопка СЕСТЬ / ВСТАТЬ), телевизор, ковёр, лампа, колонки, книжный шкаф.
## Видеокамера на штативе: кнопка КАМЕРА открывает режим съёмки персонажа (VideoMode),
## а телевизор показывает живую картинку с камеры, пока игрок рядом. Создаётся кодом (hub.gd).

const DIR: String = "res://models/furniture/"
const SCALE: float = 2.1
## Центр зоны (для «игрок рядом»)
const CENTER: Vector3 = Vector3(12.8, 0.0, -2.6)
## Диваны: позиция и поворот (лицом в +Z дивана, повёрнутого на yaw)
const SOFAS: Array = [
	[Vector3(10.6, 0.0, -2.8), 90.0],
	[Vector3(12.9, 0.0, 0.5), 180.0],
]
## Места на диване (loungeDesignSofa ×2.1, центр по габаритам): ноги тела — поза «сидя» поднимает таз
const SOFA_SEATS: Array[Vector3] = [Vector3(-0.59, 0.41, 0.05), Vector3(0.59, 0.41, 0.05)]
## Куда встать — перед диваном
const STAND_OFFSET: Vector3 = Vector3(0.0, 0.05, 0.95)
## [модель, позиция, поворот, масштаб, коллизия]
const LAYOUT: Array = [
	["rugRectangle", Vector3(12.9, 0.01, -2.8), 0.0, SCALE, false],
	["tableCoffee", Vector3(12.5, 0.0, -2.8), 90.0, SCALE, true],
	["cabinetTelevision", Vector3(15.3, 0.0, -2.8), -90.0, SCALE, true],
	["televisionModern", Vector3(15.3, 0.65, -2.8), -90.0, SCALE, false],
	["speaker", Vector3(15.35, 0.0, -4.3), -90.0, SCALE, true],
	["speaker", Vector3(15.35, 0.0, -1.3), -90.0, SCALE, true],
	["lampRoundFloor", Vector3(10.5, 0.0, -4.7), 0.0, SCALE, true],
	["bookcaseOpen", Vector3(13.0, 0.0, -5.9), 0.0, SCALE, true],
	["pottedPlant", Vector3(15.2, 0.0, -5.6), 0.0, SCALE, true],
	["plantSmall1", Vector3(12.5, 0.48, -2.6), 0.0, SCALE, false],
	["rugRound", Vector3(14.6, 0.012, 1.3), 0.0, SCALE, false],
]
const LAMP_LIGHT: Vector3 = Vector3(10.5, 1.75, -4.7)
## Экран телевизора (поверх модели, смотрит в -X): центр и размер
const SCREEN_CENTER: Vector3 = Vector3(15.15, 1.22, -2.8)
const SCREEN_SIZE: Vector2 = Vector2(1.25, 0.72)
const FEED_SIZE: Vector2i = Vector2i(320, 180)
## Видеокамера на штативе и куда она смотрит по умолчанию
const TRIPOD_POSITION: Vector3 = Vector3(14.6, 0.0, 1.6)
const TRIPOD_LOOK: Vector3 = Vector3(11.0, 0.0, -2.8)
const LENS_HEIGHT: float = 1.52
## Ближе этого к зоне — камера снимает игрока и ТВ показывает картинку
const LIVE_DISTANCE: float = 11.0
const FEED_FPS: float = 15.0

var _player: Player
var _sofa_zones: Array[Interactable] = []
var _feed_viewport: SubViewport
var _feed_camera: Camera3D
var _rec_lamp: StandardMaterial3D
var _rec_label: Label3D
var _live: bool = false
var _feed_timer: float = 0.0
var _blink: float = 0.0
var _look_target: Vector3 = TRIPOD_LOOK + Vector3.UP


func _ready() -> void:
	var batch := PropBatch.new(self)
	for entry: Array in LAYOUT:
		HubCamp.add_centered(batch, DIR + str(entry[0]) + ".glb", entry[1], float(entry[2]), float(entry[3]),
			bool(entry[4]))
	for sofa: Array in SOFAS:
		HubCamp.add_centered(batch, DIR + "loungeDesignSofa.glb", sofa[0], float(sofa[1]), SCALE, true)
	batch.build()
	_build_lamp_light()
	_build_sofa_zones()
	_build_tripod()
	_build_tv_feed()
	_build_sign()
	_find_player.call_deferred()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		push_warning("HubLounge: игрок (группа \"player\") не найден")
		return
	_player.seated_changed.connect(_on_seated_changed)


func _process(delta: float) -> void:
	# Мигает лампа записи на камере и «● REC» на экране
	_blink += delta
	var on: bool = fmod(_blink, 1.0) < 0.6
	if _rec_lamp != null:
		_rec_lamp.emission_energy_multiplier = 3.0 if on else 0.3
	if _rec_label != null:
		_rec_label.visible = on and _live
	if _player == null or not is_instance_valid(_player):
		return
	var near: bool = _player.global_position.distance_to(CENTER) < LIVE_DISTANCE and not VideoMode.is_open
	if near != _live:
		_set_live(near)
	if _live:
		_aim_feed_camera(delta)
		# Картинка ТВ — FEED_FPS кадров в секунду, а не каждый кадр игры (второй рендер сцены дорогой)
		_feed_timer -= delta
		if _feed_timer <= 0.0:
			_feed_timer = 1.0 / FEED_FPS
			_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _exit_tree() -> void:
	if _live:
		_set_live(false)


# ---------- Диваны ----------

func _build_sofa_zones() -> void:
	for i in SOFAS.size():
		var sofa: Array = SOFAS[i]
		var zone := Interactable.new()
		zone.name = "Sofa%d" % (i + 1)
		zone.prompt = "СЕСТЬ"
		zone.action_id = &"sofa"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.0, 2.6)
		shape.shape = box
		shape.position = Vector3(0.0, 1.0, 0.6)
		zone.add_child(shape)
		zone.position = sofa[0]
		zone.rotation.y = deg_to_rad(float(sofa[1]))
		add_child(zone)
		zone.interacted.connect(_on_sofa.bind(i))
		_sofa_zones.append(zone)


func _on_sofa(index: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.seated:
		_player.stand_up()
		return
	var sofa: Array = SOFAS[index]
	var sofa_position: Vector3 = sofa[0]
	var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(float(sofa[1]))), sofa_position)
	# Ближайшее к игроку место
	var best: Vector3 = xform * SOFA_SEATS[0]
	for seat: Vector3 in SOFA_SEATS:
		var world: Vector3 = xform * seat
		if world.distance_squared_to(_player.global_position) < best.distance_squared_to(_player.global_position):
			best = world
	var stand: Vector3 = best + xform.basis * STAND_OFFSET
	stand.y = sofa_position.y + STAND_OFFSET.y
	# Лицом от спинки: перёд дивана — его +Z, у игрока «вперёд» — -Z
	_player.sit_at(best, deg_to_rad(float(sofa[1])) + PI, stand)


func _on_seated_changed(is_seated: bool) -> void:
	for zone: Interactable in _sofa_zones:
		zone.set_prompt("ВСТАТЬ" if is_seated else "СЕСТЬ")


# ---------- Видеокамера и телевизор ----------

## Штатив с камерой из простых фигур; лампа записи мигает. Зона КАМЕРА открывает режим съёмки
func _build_tripod() -> void:
	var tripod := Node3D.new()
	tripod.name = "VideoCamera"
	tripod.position = TRIPOD_POSITION
	add_child(tripod)
	var look: Vector3 = TRIPOD_LOOK - TRIPOD_POSITION
	tripod.rotation.y = atan2(-look.x, -look.z)  # «вперёд» камеры — -Z
	var metal := _material(Color(0.12, 0.12, 0.13), 0.6)
	var body_material := _material(Color(0.2, 0.21, 0.23), 0.3)
	for i in 3:
		var angle: float = TAU * float(i) / 3.0
		var foot := Vector3(cos(angle), 0.0, sin(angle)) * 0.42
		var top := Vector3(0.0, 1.38, 0.0)
		var leg := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.016
		tube.bottom_radius = 0.022
		tube.height = foot.distance_to(top)
		tube.radial_segments = 6
		leg.mesh = tube
		leg.material_override = metal
		tripod.add_child(leg)
		leg.position = (foot + top) * 0.5
		leg.basis = _axis_basis((top - foot).normalized())
	_add_box(tripod, Vector3(0.12, 0.08, 0.12), Vector3(0.0, 1.41, 0.0), metal)
	_add_box(tripod, Vector3(0.2, 0.22, 0.38), Vector3(0.0, LENS_HEIGHT, 0.0), body_material)
	# Объектив вперёд (-Z) и стекло
	var lens := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.075
	barrel.bottom_radius = 0.065
	barrel.height = 0.18
	lens.mesh = barrel
	lens.material_override = metal
	lens.rotation.x = -PI * 0.5
	lens.position = Vector3(0.0, LENS_HEIGHT, -0.27)
	tripod.add_child(lens)
	var glass := _material(Color(0.1, 0.2, 0.35), 0.1)
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.45, 0.8)
	glass.emission_energy_multiplier = 0.6
	_add_box(tripod, Vector3(0.12, 0.12, 0.01), Vector3(0.0, LENS_HEIGHT, -0.365), glass)
	# Откидной экранчик сбоку
	var screen := _material(Color(0.1, 0.3, 0.2), 0.2)
	screen.emission_enabled = true
	screen.emission = Color(0.3, 0.8, 0.5)
	screen.emission_energy_multiplier = 0.8
	_add_box(tripod, Vector3(0.015, 0.1, 0.14), Vector3(0.115, LENS_HEIGHT + 0.02, -0.05), screen)
	# Лампа записи
	_rec_lamp = _material(Color(0.6, 0.0, 0.0), 0.3)
	_rec_lamp.emission_enabled = true
	_rec_lamp.emission = Color(1.0, 0.05, 0.05)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.022
	bulb.height = 0.044
	bulb.radial_segments = 8
	bulb.rings = 4
	lamp.mesh = bulb
	lamp.material_override = _rec_lamp
	lamp.position = Vector3(0.06, LENS_HEIGHT + 0.12, -0.15)
	tripod.add_child(lamp)
	# Коллизия и зона «КАМЕРА»
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.7, 0.7)
	shape.shape = box
	shape.position.y = 0.85
	body.add_child(shape)
	tripod.add_child(body)
	var zone := Interactable.new()
	zone.name = "CameraZone"
	zone.prompt = "КАМЕРА"
	zone.action_id = &"video"
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(2.4, 2.0, 2.4)
	zone_shape.shape = zone_box
	zone_shape.position.y = 1.0
	zone.add_child(zone_shape)
	tripod.add_child(zone)
	zone.interacted.connect(_open_video_mode)
	var label := Label3D.new()
	label.text = "КАМЕРА"
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.1
	tripod.add_child(label)


func _open_video_mode() -> void:
	if _player == null or VideoMode.is_open:
		return
	var lens: Transform3D = _lens_transform()
	VideoMode.open(get_tree(), lens)


## Положение объектива в мире (смотрит на диван)
func _lens_transform() -> Transform3D:
	var tripod := get_node_or_null(^"VideoCamera") as Node3D
	if tripod == null:
		return Transform3D(Basis.IDENTITY, TRIPOD_POSITION + Vector3.UP * LENS_HEIGHT)
	return tripod.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, LENS_HEIGHT, -0.37))


## Телевизор показывает картинку с камеры: свой SubViewport в общем мире, обновляется только рядом
func _build_tv_feed() -> void:
	_feed_viewport = SubViewport.new()
	_feed_viewport.name = "TvFeed"
	_feed_viewport.size = FEED_SIZE
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_feed_viewport.positional_shadow_atlas_size = 0
	add_child(_feed_viewport)
	_feed_camera = Camera3D.new()
	_feed_camera.fov = 45.0
	_feed_camera.near = 0.1
	_feed_camera.far = 80.0
	_feed_viewport.add_child(_feed_camera)
	_feed_camera.global_transform = _lens_transform()
	_feed_camera.look_at(_look_target, Vector3.UP)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _feed_viewport.get_texture()
	var screen := MeshInstance3D.new()
	screen.name = "TvScreen"
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	screen.mesh = quad
	screen.material_override = material
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = SCREEN_CENTER
	screen.rotation.y = -PI * 0.5  # лицом в -X, к диванам
	add_child(screen)
	_rec_label = Label3D.new()
	_rec_label.text = "● REC"
	_rec_label.modulate = Color(1.0, 0.2, 0.2)
	_rec_label.font_size = 40
	_rec_label.outline_size = 8
	_rec_label.pixel_size = 0.003
	_rec_label.position = SCREEN_CENTER + Vector3(-0.01, SCREEN_SIZE.y * 0.38, SCREEN_SIZE.x * 0.36)
	_rec_label.rotation.y = -PI * 0.5
	_rec_label.visible = false
	add_child(_rec_label)


func _set_live(enabled: bool) -> void:
	_live = enabled
	if _feed_viewport != null:
		_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if enabled \
			else SubViewport.UPDATE_DISABLED
		_feed_timer = 0.0
	# Пока камера снимает — тело игрока видно ей и от 1-го лица
	if _player != null and is_instance_valid(_player):
		if enabled:
			_player.add_body_viewer()
		else:
			_player.remove_body_viewer()


## Камера плавно ведёт игрока; приближение — чтобы человек был в кадре целиком
func _aim_feed_camera(delta: float) -> void:
	if _feed_camera == null:
		return
	var target: Vector3 = _player.head.global_position + Vector3.DOWN * 0.55
	_look_target = _look_target.lerp(target, clampf(4.0 * delta, 0.0, 1.0))
	var origin: Vector3 = _feed_camera.global_position
	if origin.distance_squared_to(_look_target) > 0.01:
		_feed_camera.look_at(_look_target, Vector3.UP)
	_feed_camera.fov = VideoMode.framing_fov(origin.distance_to(_look_target), 1.0)


# ---------- Оформление ----------

func _build_lamp_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = LAMP_LIGHT
	add_child(light)


func _build_sign() -> void:
	var title := Label3D.new()
	title.text = "ЗОНА ОТДЫХА"
	title.font_size = 64
	title.outline_size = 16
	title.pixel_size = 0.005
	title.modulate = Color(0.7, 0.9, 1.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(15.3, 2.6, -2.8)
	add_child(title)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.3
	return material


func _add_box(parent: Node3D, box_size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


## Поворот, при котором ось Y смотрит вдоль up (ножка штатива)
func _axis_basis(up: Vector3) -> Basis:
	var side: Vector3 = up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward: Vector3 = side.cross(up).normalized()
	return Basis(side, up, forward)
