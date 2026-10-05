class_name SkinPreview
extends SubViewportContainer
## 3D-превью персонажа (скина): медленно вращается, играет анимацию покоя.
## Отдельный мир (own_world_3d) — не мешает убежищу.

const VIEW_SIZE: Vector2i = Vector2i(360, 480)
const TURN_SPEED: float = 0.6

var _viewport: SubViewport
var _pivot: Node3D
var _body: PlayerBody


func _ready() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.72, 0.7)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.7)
	light.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	_viewport.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.0, 3.6)
	camera.fov = 38.0
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_body = PlayerBody.new()
	_pivot.add_child(_body)


func show_skin(skin: PlayerSkin) -> void:
	if _body == null or skin == null:
		return
	_body.set_skin(skin)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_pivot.rotation.y += TURN_SPEED * delta
	_body.update_motion(0.0, true, delta)
