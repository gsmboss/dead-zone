class_name CarPreview
extends SubViewportContainer
## 3D-превью машины автосалона: медленно вращается на подиуме, с покраской и неоном.
## Отдельный мир (own_world_3d); рисуется, только пока окно на экране.

const VIEW_SIZE: Vector2i = Vector2i(460, 300)
const TURN_SPEED: float = 0.5

var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _neon: OmniLight3D


func _ready() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.82)
	light.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	_viewport.add_child(light)

	# Подиум
	var podium_material := StandardMaterial3D.new()
	podium_material.albedo_color = Color(0.16, 0.17, 0.2)
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 3.4
	podium_mesh.bottom_radius = 3.5
	podium_mesh.height = 0.2
	podium_mesh.material = podium_material
	var podium := MeshInstance3D.new()
	podium.mesh = podium_mesh
	podium.position = Vector3.DOWN * 0.1
	_viewport.add_child(podium)

	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0.0, 2.6, 8.2)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)

	_pivot = Node3D.new()
	_pivot.rotation.y = 0.7
	_viewport.add_child(_pivot)
	_neon = OmniLight3D.new()
	_neon.light_energy = 3.0
	_neon.omni_range = 4.0
	_neon.position = Vector3(0.0, 0.2, 0.0)
	_neon.visible = false
	_pivot.add_child(_neon)


## Показать машину с покраской; neon_color.a = 0 — без неона
func show_car(car: CarData, paint_color: Color, neon_color: Color) -> void:
	if _pivot == null or car == null:
		return
	if _model != null:
		_model.queue_free()
		_model = null
	if car.model_scene != null:
		_model = car.model_scene.instantiate() as Node3D
	if _model != null:
		_model.scale = Vector3.ONE * car.model_scale
		_pivot.add_child(_model)
		DrivableCar.paint_body(_model, paint_color)
	_neon.visible = neon_color.a > 0.0
	_neon.light_color = Color(neon_color, 1.0)


func _process(delta: float) -> void:
	var on_screen: bool = is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect())
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	if _viewport.render_target_update_mode != mode:
		_viewport.render_target_update_mode = mode
	if on_screen and _pivot != null:
		_pivot.rotation.y += TURN_SPEED * delta
