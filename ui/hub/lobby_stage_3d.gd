class_name LobbyStage3D
extends SubViewportContainer
## 3D-фон лобби: ночной лагерь у костра, вокруг — персонажи игроков лобби в своих скинах
## (анимации покоя, приветствие при входе, появление и уход с анимацией), имена цветом команды.
## Пока игра не создана — только свой персонаж и пульсирующий «радар» поиска сети.
## Отдельный мир (own_world_3d), половинное разрешение — дёшево для телефона.

const SLOT_RADIUS: float = 2.6
## Персонажи стоят полукругом за костром лицом к камере
const SLOT_ANGLES: Array[float] = [0.0, -0.55, 0.55, -1.1]
## Камера смотрит левее лагеря: слева панель лобби, персонажи — в правой части экрана
const CAMERA_POSITION: Vector3 = Vector3(-2.4, 2.4, 6.6)
const LOOK_AT: Vector3 = Vector3(-2.4, 1.0, -1.2)
const SWAY: float = 0.35
const FIRE_COLOR: Color = Color(1.0, 0.55, 0.22)
const PROPS: Array = [
	["res://models/environment/Container_Red.gltf", Vector3(-6.0, 0.0, -6.5), 20.0],
	["res://models/environment/Container_Green.gltf", Vector3(5.5, 0.0, -7.0), -15.0],
	["res://models/vehicles/Vehicle_Truck_Armored.gltf", Vector3(-7.5, 0.0, -1.0), 70.0],
	["res://models/environment/Barrel.gltf", Vector3(3.6, 0.0, -2.8), 0.0],
	["res://models/environment/Barrel.gltf", Vector3(4.2, 0.0, -2.2), 0.0],
	["res://models/environment/Wheels_Stack.gltf", Vector3(-3.8, 0.0, -3.4), 30.0],
	["res://models/environment/StreetLights.gltf", Vector3(6.5, 0.0, -2.0), -90.0],
	["res://models/survival/tent-canvas.glb", Vector3(-3.2, 0.0, -5.0), 25.0, 3.4],
]

var _viewport: SubViewport
var _camera: Camera3D
var _fire_light: OmniLight3D
var _radar: MeshInstance3D
var _slots: Dictionary = {}  # peer_id -> {"body": PlayerBody, "tag": Label3D, "root": Node3D}
var _time: float = 0.0


func _ready() -> void:
	stretch = true
	stretch_shrink = 2
	mouse_filter = MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_world()


## Показать игроков: [{"id": int, "name": String, "skin": String, "color": Color}]
func set_players(entries: Array) -> void:
	var present: Dictionary = {}
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var peer_id: int = int(entry["id"])
		present[peer_id] = true
		var slot_position: Vector3 = _slot_position(i)
		if _slots.has(peer_id):
			var slot: Dictionary = _slots[peer_id]
			var tag := slot["tag"] as Label3D
			tag.text = str(entry["name"])
			tag.modulate = entry["color"]
			var root := slot["root"] as Node3D
			if root.position.distance_to(slot_position) > 0.05:
				create_tween().tween_property(root, "position", slot_position, 0.5) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_add_character(peer_id, entry, slot_position)
	for peer_id: int in _slots.keys():
		if not present.has(peer_id):
			_remove_character(peer_id)
	if _radar != null:
		_radar.visible = entries.size() <= 1


func _process(delta: float) -> void:
	if _camera == null:
		return
	_time += delta
	# Лёгкое покачивание камеры и мерцание костра
	_camera.position = CAMERA_POSITION + Vector3(sin(_time * 0.3) * SWAY, sin(_time * 0.21) * SWAY * 0.3, 0.0)
	_camera.look_at(LOOK_AT, Vector3.UP)
	if _fire_light != null:
		_fire_light.light_energy = 2.2 + sin(_time * 11.0) * 0.25 + sin(_time * 7.3) * 0.2
	if _radar != null and _radar.visible:
		var pulse: float = fmod(_time * 0.6, 1.0)
		_radar.scale = Vector3.ONE * (0.4 + pulse * 2.4)
		(_radar.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - pulse)
	for peer_id: int in _slots:
		var body := _slots[peer_id]["body"] as PlayerBody
		body.update_motion(0.0, true, delta)


# ---------- Персонажи ----------

func _slot_position(index: int) -> Vector3:
	var angle: float = SLOT_ANGLES[index % SLOT_ANGLES.size()]
	return Vector3(sin(angle) * SLOT_RADIUS, 0.0, -cos(angle) * SLOT_RADIUS + 0.6)


func _add_character(peer_id: int, entry: Dictionary, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	_viewport.add_child(root)
	var body := PlayerBody.new()
	root.add_child(body)
	var skin: PlayerSkin = GameState.get_skin(str(entry["skin"]))
	body.set_skin(skin if skin != null else GameState.get_selected_skin())
	body.set_accessories(str(entry.get("acc", "")).split(",", false))
	body.set_weapon(SkinPreview.best_weapon())
	# Лицом к камере
	body.rotation.y = atan2(CAMERA_POSITION.x - at.x, CAMERA_POSITION.z - at.z) + PI
	var tag := Label3D.new()
	tag.text = str(entry["name"])
	tag.font_size = 64
	tag.outline_size = 14
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = entry["color"]
	tag.position = Vector3(0.0, 2.2, 0.0)
	root.add_child(tag)
	# Появление: «выпрыгивает» из земли и машет рукой
	root.scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(body.play_emote)
	_slots[peer_id] = {"body": body, "tag": tag, "root": root}


func _remove_character(peer_id: int) -> void:
	var slot: Dictionary = _slots[peer_id]
	_slots.erase(peer_id)
	var root := slot["root"] as Node3D
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(root.queue_free)


# ---------- Мир ----------

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.5, 0.62)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.1, 0.09, 0.1)
	environment.fog_density = 0.06
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.68, 0.95)
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_viewport.add_child(moon)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 60.0
	_viewport.add_child(_camera)
	_camera.position = CAMERA_POSITION
	_camera.look_at(LOOK_AT, Vector3.UP)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.16, 0.15, 0.13)
	ground_material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	plane.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	_viewport.add_child(ground)

	for entry: Array in PROPS:
		var path: String = entry[0]
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		var prop := scene.instantiate() as Node3D if scene != null else null
		if prop == null:
			continue
		prop.position = entry[1]
		prop.rotation_degrees.y = float(entry[2])
		if entry.size() > 3:
			prop.scale = Vector3.ONE * float(entry[3])
		_viewport.add_child(prop)

	# Костёр в центре
	var fire_at := Vector3(0.0, 0.0, -1.4)
	for path: String in ["res://models/survival/campfire-pit.glb", "res://models/survival/campfire-stand.glb"]:
		if ResourceLoader.exists(path):
			var pit := (load(path) as PackedScene).instantiate() as Node3D
			if pit != null:
				pit.position = fire_at
				pit.scale = Vector3.ONE * 3.4
				_viewport.add_child(pit)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = FIRE_COLOR
	_fire_light.light_energy = 2.2
	_fire_light.omni_range = 9.0
	_fire_light.position = fire_at + Vector3.UP * 0.9
	_viewport.add_child(_fire_light)
	var flames := GraveyardBuilder.make_flames()
	flames.position = fire_at + Vector3.UP * 0.25
	flames.amount = 24
	flames.scale = Vector3.ONE * 1.6
	_viewport.add_child(flames)

	# «Радар» поиска сети: расходящееся кольцо на земле
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 3
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.4, 0.85, 1.0, 0.7)
	_radar = MeshInstance3D.new()
	_radar.mesh = ring
	_radar.material_override = ring_material
	_radar.position = _slot_position(0) + Vector3.UP * 0.03
	_viewport.add_child(_radar)
