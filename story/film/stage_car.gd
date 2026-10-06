class_name StageCar
extends Node3D
## Машина кино-сцены: едет по маршруту по кругу (или стоит), крутит колёса, светит фарами,
## у полиции и скорой — мигалка. Модели Kenney Car Kit (перед +Z) и Quaternius.

const WIDTH: float = 2.1
const FLASH_RATE: float = 6.0

var path := PackedVector3Array()
var speed: float = 9.0
var headlights: bool = false
## Мигалка: красно-синяя (полиция) или красно-белая (скорая); прозрачный — нет
var flasher: Color = Color(0.0, 0.0, 0.0, 0.0)

var _model: Node3D
var _wheels: Array[Node3D] = []
var _target: int = 0
var _flash_lights: Array[OmniLight3D] = []
var _time: float = 0.0
var _wheel_radius: float = 0.35


## Машина: модель, маршрут (пусто — стоит), скорость, поворот на месте (градусы), оттенок (обгоревшая)
static func create(scene: PackedScene, route: PackedVector3Array, drive_speed: float, yaw_degrees: float = 0.0,
		burnt: bool = false, start_t: float = 0.0) -> StageCar:
	var car := StageCar.new()
	car.path = route
	car.speed = drive_speed
	if scene != null:
		car._model = scene.instantiate() as Node3D
	if car._model != null:
		car.add_child(car._model)
		car._fit_width()
		if burnt:
			car._burn()
	if not route.is_empty():
		car.position = route[0] if route.size() < 2 else route[0].lerp(route[1], clampf(start_t, 0.0, 1.0))
		car._target = mini(1, route.size() - 1)
		if route.size() > 1:
			car._face(route[car._target])
	else:
		car.rotation.y = deg_to_rad(yaw_degrees)
	return car


func _ready() -> void:
	if _model != null:
		for node: Node in _model.find_children("*wheel*", "Node3D", true, false):
			_wheels.append(node as Node3D)
	if headlights:
		_add_headlights()
	if flasher.a > 0.0:
		for side: float in [-1.0, 1.0]:
			var light := OmniLight3D.new()
			light.omni_range = 9.0
			light.light_energy = 3.0
			light.shadow_enabled = false
			light.position = Vector3(side * 0.5, 2.2, 0.0)
			add_child(light)
			_flash_lights.append(light)


func _process(delta: float) -> void:
	_time += delta
	if not _flash_lights.is_empty():
		var phase: bool = fmod(_time * FLASH_RATE, 2.0) < 1.0
		_flash_lights[0].light_color = Color(1.0, 0.1, 0.1) if phase else Color(0.0, 0.0, 0.0)
		_flash_lights[1].light_color = flasher if not phase else Color(0.0, 0.0, 0.0)
	if path.size() < 2:
		return
	var goal: Vector3 = path[_target]
	var to_goal: Vector3 = goal - position
	var step: float = speed * delta
	for wheel: Node3D in _wheels:
		wheel.rotate_object_local(Vector3.RIGHT, step / _wheel_radius)
	if to_goal.length() <= step:
		position = goal
		_target += 1
		if _target >= path.size():
			position = path[0]
			_target = 1
		_face(path[_target])
		return
	position += to_goal.normalized() * step


## Перед модели (+Z) — по направлению движения
func _face(point: Vector3) -> void:
	var direction := Vector3(point.x - position.x, 0.0, point.z - position.z)
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)


func _fit_width() -> void:
	var bounds := AABB()
	var has_bounds: bool = false
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != _model:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		var mesh_bounds: AABB = xform * mesh_instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	if not has_bounds or bounds.size.x <= 0.01:
		return
	var k: float = WIDTH / bounds.size.x
	_model.scale = Vector3.ONE * k
	_model.position.y = -bounds.position.y * k
	_wheel_radius = maxf(0.35 * k / 1.6, 0.2)


## Обгоревшая брошенная машина: тёмный полупрозрачный слой поверх
func _burn() -> void:
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.05, 0.04, 0.035, 0.7)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = soot


func _add_headlights() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.95, 0.8)
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = glow
	for side: float in [-1.0, 1.0]:
		var bulb := MeshInstance3D.new()
		bulb.mesh = sphere
		bulb.position = Vector3(side * WIDTH * 0.33, 0.7, 2.25)
		add_child(bulb)
	var light := SpotLight3D.new()
	light.light_color = Color(1.0, 0.94, 0.8)
	light.light_energy = 6.0
	light.spot_range = 22.0
	light.spot_angle = 35.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.9, 2.3)
	light.rotation = Vector3(deg_to_rad(-8.0), PI, 0.0)  # прожектор светит в -Z — разворот вперёд (+Z)
	add_child(light)
