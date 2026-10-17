class_name MissionMap3D
extends SubViewportContainer
## 3D-карта заражения для выбора миссий: тёмная зона в тумане, обломки, машины;
## у каждой миссии — светящийся маяк её цвета и модель по типу. Камера облетает
## выбранную миссию (focus). Отдельный мир (own_world_3d) — не мешает убежищу.

const RING_RADIUS: float = 9.0
const CAMERA_DISTANCE: float = 7.0
const CAMERA_HEIGHT: float = 4.2
const ORBIT_SPEED: float = 0.18
const FOCUS_SPEED: float = 3.0
const BEACON_HEIGHT: float = 7.0

const ZOMBIE_MODEL: String = "res://models/zombies/Zombie_Basic.gltf"
const TANK_MODEL: String = "res://models/zombies/Zombie_Chubby.gltf"
const PROP_MODELS: Array[String] = [
	"res://models/environment/Container_Red.gltf",
	"res://models/environment/Container_Green.gltf",
	"res://models/vehicles/Vehicle_Truck_Armored.gltf",
	"res://models/vehicles/Vehicle_Sports.gltf",
	"res://models/environment/Barrel.gltf",
	"res://models/environment/TrafficBarrier_1.gltf",
	"res://models/environment/Wheels_Stack.gltf",
	"res://models/environment/StreetLights.gltf",
]

var _viewport: SubViewport
var _camera: Camera3D
var _markers: Array[Node3D] = []
var _focus_index: int = 0
var _focus_point: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	stretch = true
	stretch_shrink = 2  # половинное разрешение: фон, а не игра — экономим кадр на телефоне
	mouse_filter = MOUSE_FILTER_IGNORE
	_rng.seed = 2077
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_world()


## Расставить маяки миссий по кругу
func set_missions(missions: Array[MissionData]) -> void:
	for marker: Node3D in _markers:
		marker.queue_free()
	_markers.clear()
	var count: int = maxi(missions.size(), 1)
	for i in missions.size():
		var angle: float = TAU * i / count
		var marker := _make_marker(missions[i])
		marker.position = Vector3(cos(angle), 0.0, sin(angle)) * RING_RADIUS
		_viewport.add_child(marker)
		_markers.append(marker)
	focus(0, true)


func focus(index: int, instant: bool = false) -> void:
	if _markers.is_empty():
		return
	_focus_index = clampi(index, 0, _markers.size() - 1)
	if instant:
		_focus_point = _markers[_focus_index].position


func _process(delta: float) -> void:
	if _camera == null:
		return
	_time += delta
	_orbit_angle += ORBIT_SPEED * delta
	if not _markers.is_empty():
		_focus_point = _focus_point.lerp(_markers[_focus_index].position, clampf(FOCUS_SPEED * delta, 0.0, 1.0))
	# Камера смотрит на маяк снаружи круга, медленно облетая его
	var outward: Vector3 = _focus_point.normalized() if _focus_point.length() > 0.1 else Vector3.FORWARD
	var orbit: Vector3 = outward.rotated(Vector3.UP, sin(_orbit_angle) * 0.6)
	_camera.position = _focus_point + orbit * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	_camera.look_at(_focus_point + Vector3.UP * 1.2, Vector3.UP)
	# Выбранный маяк пульсирует
	for i in _markers.size():
		var beacon := _markers[i].get_node_or_null(^"Beacon") as MeshInstance3D
		if beacon != null:
			var selected: bool = i == _focus_index
			beacon.scale = Vector3.ONE * ((1.0 + 0.25 * sin(_time * 4.0)) if selected else 0.6)


# ---------- Мир ----------

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.05, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.45, 0.4)
	environment.ambient_light_energy = 0.7
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18, 0.1, 0.06)
	environment.fog_density = 0.05
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.6, 0.35)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	_viewport.add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 80.0
	_viewport.add_child(_camera)

	# Земля: тёмный асфальт с разметкой зоны
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.13, 0.12, 0.11)
	ground_material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	plane.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	_viewport.add_child(ground)

	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.6, 0.12, 0.08)
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.08
	torus.outer_radius = RING_RADIUS + 0.08
	torus.rings = 64
	torus.ring_segments = 4
	torus.material = ring_material
	var zone := MeshInstance3D.new()
	zone.mesh = torus
	zone.position.y = 0.02
	_viewport.add_child(zone)

	# Обломки вокруг зоны
	for i in 18:
		var path: String = PROP_MODELS[_rng.randi() % PROP_MODELS.size()]
		var prop := _instance(path)
		if prop == null:
			continue
		var angle: float = _rng.randf() * TAU
		var distance: float = _rng.randf_range(RING_RADIUS + 4.0, RING_RADIUS + 14.0)
		if _rng.randf() < 0.3:
			distance = _rng.randf_range(2.0, RING_RADIUS - 4.0)  # и немного в центре
		prop.position = Vector3(cos(angle), 0.0, sin(angle)) * distance
		prop.rotation.y = _rng.randf() * TAU
		_viewport.add_child(prop)


func _make_marker(mission: MissionData) -> Node3D:
	var marker := Node3D.new()
	var color: Color = MissionIcon.color_for(mission)

	# Световой столб-маяк
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.albedo_color = Color(color, 0.35)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.25
	cylinder.bottom_radius = 0.6
	cylinder.height = BEACON_HEIGHT
	cylinder.radial_segments = 12
	cylinder.rings = 1
	cylinder.material = beam_material
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	beacon.mesh = cylinder
	beacon.position.y = BEACON_HEIGHT * 0.5
	marker.add_child(beacon)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position.y = 1.5
	marker.add_child(light)

	# Модель по типу миссии
	var model_path: String = ZOMBIE_MODEL
	var model_scale: float = 1.2
	var extra: String = ""
	if mission.boss != null and mission.type == MissionData.Type.WAVES:
		model_path = TANK_MODEL
		model_scale = 2.0
	else:
		match mission.type:
			MissionData.Type.COLLECT:
				extra = "res://models/environment/Chest_Special.gltf"
			MissionData.Type.DEFEND:
				extra = "res://models/environment/TrafficBarrier_2.gltf"
			MissionData.Type.SURVIVE:
				extra = "res://models/environment/Barrel.gltf"
			MissionData.Type.FREE_ROAM:
				extra = "res://models/city/commercial/building-skyscraper-b.glb"
			MissionData.Type.ENDLESS:
				model_path = TANK_MODEL
				model_scale = 1.3
	var zombie := _instance(model_path)
	if zombie != null:
		zombie.scale = Vector3.ONE * model_scale
		zombie.rotation.y = PI
		marker.add_child(zombie)
		_play_idle(zombie)
	if not extra.is_empty():
		var prop := _instance(extra)
		if prop != null:
			prop.position = Vector3(1.4, 0.0, 0.6)
			if mission.type == MissionData.Type.FREE_ROAM:
				prop.scale = Vector3.ONE * 2.2
				prop.position = Vector3(2.2, 0.0, -1.5)
			marker.add_child(prop)

	var label := Label3D.new()
	label.text = mission.title
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.3)
	label.position.y = 3.6 if model_scale < 1.5 else 4.6
	marker.add_child(label)
	return marker


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _play_idle(model: Node3D) -> void:
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	if player.has_animation(&"Idle"):
		player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
		player.play(&"Idle")
