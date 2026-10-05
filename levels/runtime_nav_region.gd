class_name RuntimeNavRegion
extends NavigationRegion3D
## Навмеш строится при запуске уровня по коллизиям мира (пол, CSG, StaticProp).
## Не нужно нажимать «Bake» в редакторе после перестановки объектов.
## Коллизии StaticProp создаются в их _ready, поэтому ждём пару физических кадров.

## Строить навмеш при запуске (выключите, если навмеш запечён в редакторе вручную)
@export var bake_on_ready: bool = true
@export var agent_radius: float = 0.4
@export var agent_height: float = 1.8
@export var agent_max_climb: float = 0.3
@export_range(0.0, 60.0) var agent_max_slope: float = 35.0


func _ready() -> void:
	if not bake_on_ready:
		return
	# Своя копия: настройки и результат не меняют ресурс в файле сцены
	var mesh: NavigationMesh = navigation_mesh.duplicate() as NavigationMesh \
		if navigation_mesh != null else NavigationMesh.new()
	mesh.clear_polygons()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = PhysicsLayers.WORLD
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	mesh.agent_max_climb = agent_max_climb
	mesh.agent_max_slope = agent_max_slope
	navigation_mesh = mesh
	bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	_bake.call_deferred()


func _bake() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		push_warning("RuntimeNavRegion '%s': навмеш пустой — проверьте коллизии пола" % name)
