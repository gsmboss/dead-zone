class_name CampDiorama3D
extends SubViewportContainer
## 3D-макет лагеря выживших в окне сюжета: костёр, дома (по пройденным главам), свои машины
## и спасённые люди вокруг огня (до MAX_PEOPLE фигур). Растёт по мере прохождения кампании.
## Отдельный мир (own_world_3d), половинное разрешение — дёшево для телефона.

const MAX_PEOPLE: int = 10
const HOUSES: Array[String] = ["res://models/industrial/building-m.glb", "res://models/industrial/building-e.glb",
	"res://models/industrial/building-c.glb"]
const HOUSE_SCALE: float = 2.4
const HOUSE_SPOTS: Array[Vector3] = [Vector3(-4.0, 0.0, -3.5), Vector3(4.2, 0.0, -3.8), Vector3(0.2, 0.0, -6.0)]
const CAR_SPOTS: Array[Vector3] = [Vector3(-5.5, 0.0, 2.0), Vector3(5.6, 0.0, 1.6)]
const TENT: String = "res://models/survival/tent-canvas.glb"
const FIRE_PIT: String = "res://models/survival/campfire-pit.glb"

var _viewport: SubViewport
var _pivot: Node3D
var _people: Array[PlayerBody] = []
var _time: float = 0.0


func _ready() -> void:
	stretch = true
	stretch_shrink = 2
	mouse_filter = MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build()


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_time += delta
	_pivot.rotation.y = sin(_time * 0.2) * 0.6
	for body: PlayerBody in _people:
		body.update_motion(0.0, true, delta)


func _build() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.1, 0.09, 0.09)
	environment.fog_density = 0.04
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.75, 1.0)
	moon.light_energy = 0.5
	moon.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	_viewport.add_child(moon)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(0.0, 7.5, 12.5)
	camera.basis = Basis.looking_at(Vector3(0.0, 0.5, -1.0) - camera.position, Vector3.UP)
	_pivot.add_child(camera)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.18, 0.2, 0.15)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	plane.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	_viewport.add_child(ground)

	# Костёр в центре
	_add_model(FIRE_PIT, Vector3.ZERO, 0.0, 3.4)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.58, 0.25)
	fire.light_energy = 2.0
	fire.omni_range = 9.0
	fire.position = Vector3(0.0, 1.0, 0.0)
	_viewport.add_child(fire)
	var flames := GraveyardBuilder.make_flames()
	flames.position = Vector3(0.0, 0.3, 0.0)
	_viewport.add_child(flames)

	# Палатка — с первого дня; дома — за главы
	_add_model(TENT, Vector3(-1.5, 0.0, -4.5), 0.3, 3.4)
	var houses: int = mini(GameState.get_house_count(), HOUSE_SPOTS.size())
	for i in houses:
		_add_model(HOUSES[i % HOUSES.size()], HOUSE_SPOTS[i], PI * 0.1 * (i - 1), HOUSE_SCALE)

	var cars: Array[PackedScene] = GameState.get_owned_cars()
	for i in mini(cars.size(), CAR_SPOTS.size()):
		var car := cars[i].instantiate() as Node3D
		if car != null:
			car.position = CAR_SPOTS[i]
			car.rotation.y = PI * 0.5 if i == 0 else -PI * 0.4
			_viewport.add_child(car)

	# Люди у костра: скины Kenney по кругу
	var count: int = mini(GameState.get_rescued_count(), MAX_PEOPLE)
	var kenney: Array[PlayerSkin] = []
	for skin: PlayerSkin in GameState.skins:
		if skin.hide_weapon:
			kenney.append(skin)
	if kenney.is_empty():
		kenney = GameState.skins
	for i in count:
		var angle: float = TAU * i / maxf(count, 1.0) + 0.3
		var body := PlayerBody.new()
		_viewport.add_child(body)
		body.set_skin(kenney[i % kenney.size()])
		body.position = Vector3(cos(angle), 0.0, sin(angle)) * 2.4
		body.rotation.y = atan2(-body.position.x, -body.position.z) + PI  # лицом к огню
		_people.append(body)


func _add_model(path: String, at: Vector3, yaw: float, scale_value: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var model := scene.instantiate() as Node3D if scene != null else null
	if model == null:
		return
	model.position = at
	model.rotation.y = yaw
	model.scale = Vector3.ONE * scale_value
	_viewport.add_child(model)
