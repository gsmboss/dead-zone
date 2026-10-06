class_name TorchPreview
extends SubViewportContainer
## Горящий факел в 3D для карточки снаряжения в оружейной: тёмная стена за ним освещается огнём.
## Отдельный мир (own_world_3d); рисуется, только пока карточка на экране.

const VIEW_SIZE: Vector2i = Vector2i(170, 170)

var _viewport: SubViewport
var _pivot: Node3D
var _time: float = 0.0


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
	environment.background_color = Color(0.05, 0.04, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.22, 0.2)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	# Стена за факелом — на ней видно тёплый свет
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.32, 0.28, 0.25)
	var wall_mesh := PlaneMesh.new()
	wall_mesh.size = Vector2(3.0, 3.0)
	wall_mesh.orientation = PlaneMesh.FACE_Z
	wall_mesh.material = wall_material
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 0.0, -0.6)
	_viewport.add_child(wall)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var torch := Torch.new()
	_pivot.add_child(torch)
	torch.position = Vector3(0.0, -0.12, 0.0)  # Torch ставит себя «в руку» — возвращаем в центр кадра
	torch.set_lit(true)

	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0.0, 0.05, 0.75)
	_viewport.add_child(camera)


func _process(delta: float) -> void:
	var on_screen: bool = is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect())
	var mode: int = SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	if _viewport.render_target_update_mode != mode:
		_viewport.render_target_update_mode = mode
	if not on_screen:
		return
	_time += delta
	_pivot.rotation.y = sin(_time * 0.8) * 0.5
