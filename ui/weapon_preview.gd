class_name WeaponPreview
extends SubViewportContainer
## Вращающаяся 3D-модель оружия для карточки оружейной.
## Отдельный мир (own_world_3d): свет и камера не мешают убежищу.

const VIEW_SIZE: Vector2i = Vector2i(260, 140)
## Модель масштабируется так, чтобы самая длинная сторона была такой
const FIT_LENGTH: float = 1.0
const SWING_DEGREES: float = 35.0
const SWING_SPEED: float = 0.9

var _pivot: Node3D
var _time: float = 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)


## Создать мир с моделью оружия. Без view_model остаётся пустым
func setup(weapon: WeaponData) -> void:
	if weapon == null or weapon.view_model == null:
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.12, 1.35)
	camera.fov = 40.0
	viewport.add_child(camera)

	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	var model := weapon.view_model.instantiate() as Node3D
	if model == null:
		push_warning("WeaponPreview: view_model у '%s' не Node3D" % weapon.display_name)
		return
	_pivot.add_child(model)
	_fit_model(model)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_time += delta
	# Вид сбоку с покачиванием, чтобы оружие было узнаваемо
	_pivot.rotation.y = deg_to_rad(90.0 + sin(_time * SWING_SPEED) * SWING_DEGREES)


## Центрирует модель и подгоняет размер под кадр.
## Трансформы считаются по цепочке родителей: карточка может быть ещё не в дереве
func _fit_model(model: Node3D) -> void:
	var bounds := AABB()
	var has_bounds: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local: AABB = _transform_to(mesh_instance, model) * mesh_instance.get_aabb()
		bounds = bounds.merge(local) if has_bounds else local
		has_bounds = true
	if not has_bounds:
		return
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit: float = FIT_LENGTH / maxf(longest, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -bounds.get_center() * fit


## Трансформ node в координатах root (root — предок node)
func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		var current_3d := current as Node3D
		if current_3d != null:
			result = current_3d.transform * result
		current = current.get_parent()
	return result
