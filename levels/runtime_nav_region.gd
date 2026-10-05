class_name RuntimeNavRegion
extends NavigationRegion3D
## Навмеш строится при запуске уровня по коллизиям мира (пол и стены CSGBox3D, StaticProp,
## StaticBody3D с формами). Геометрия собирается вручную из форм коллизий — без чтения
## визуальных мешей с видеокарты (это медленно и даёт предупреждение движка).
## Коллизии StaticProp создаются в их _ready, поэтому ждём пару физических кадров.

## Размер ячейки должен совпадать с картой навигации (по умолчанию 0.25)
const CELL_SIZE: float = 0.25
const CELL_HEIGHT: float = 0.25

## Строить навмеш при запуске (выключите, если навмеш запечён в редакторе вручную)
@export var bake_on_ready: bool = true
## Параметры агента кратны размерам ячейки, иначе движок округляет их с предупреждением
@export var agent_radius: float = 0.5
@export var agent_height: float = 2.0
@export var agent_max_climb: float = 0.25
@export_range(0.0, 60.0) var agent_max_slope: float = 35.0

var _skipped_warned: bool = false


func _ready() -> void:
	if not bake_on_ready:
		return
	# Своя копия: настройки и результат не меняют ресурс в файле сцены
	var mesh: NavigationMesh = navigation_mesh.duplicate() as NavigationMesh \
		if navigation_mesh != null else NavigationMesh.new()
	mesh.clear_polygons()
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = snappedf(agent_radius, CELL_SIZE)
	mesh.agent_height = snappedf(agent_height, CELL_HEIGHT)
	mesh.agent_max_climb = snappedf(agent_max_climb, CELL_HEIGHT)
	mesh.agent_max_slope = agent_max_slope
	navigation_mesh = mesh
	_bake.call_deferred()


func _bake() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or navigation_mesh == null:
		return
	var source := NavigationMeshSourceGeometryData3D.new()
	var to_region: Transform3D = global_transform.affine_inverse()
	for node: Node in find_children("*", "", true, false):
		_collect(node, source, to_region)
	if not source.has_data():
		push_warning("RuntimeNavRegion '%s': нет коллизий для навмеша" % name)
		return
	NavigationServer3D.bake_from_source_geometry_data_async(navigation_mesh, source, _on_baked)


func _on_baked() -> void:
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		push_warning("RuntimeNavRegion '%s': навмеш пустой — проверьте коллизии пола" % name)


## Добавляет геометрию коллизий ноды (в координатах региона)
func _collect(node: Node, source: NavigationMeshSourceGeometryData3D, to_region: Transform3D) -> void:
	var csg_box := node as CSGBox3D
	if csg_box != null:
		if csg_box.use_collision and (csg_box.collision_layer & PhysicsLayers.WORLD) != 0:
			_add_box(source, csg_box.size, to_region * csg_box.global_transform)
		return
	if node is CSGShape3D:
		_warn_skipped(node, "CSG-формы кроме CSGBox3D не учитываются")
		return

	var collision := node as CollisionShape3D
	if collision == null or collision.disabled or collision.shape == null:
		return
	var body := collision.get_parent() as StaticBody3D
	if body == null or (body.collision_layer & PhysicsLayers.WORLD) == 0:
		return
	var xform: Transform3D = to_region * collision.global_transform
	var shape: Shape3D = collision.shape
	if shape is BoxShape3D:
		_add_box(source, (shape as BoxShape3D).size, xform)
	elif shape is ConcavePolygonShape3D:
		source.add_faces((shape as ConcavePolygonShape3D).get_faces(), xform)
	elif shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		capsule.radius = (shape as CapsuleShape3D).radius
		capsule.height = (shape as CapsuleShape3D).height
		source.add_mesh_array(capsule.get_mesh_arrays(), xform)
	elif shape is CylinderShape3D:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = (shape as CylinderShape3D).radius
		cylinder.bottom_radius = (shape as CylinderShape3D).radius
		cylinder.height = (shape as CylinderShape3D).height
		source.add_mesh_array(cylinder.get_mesh_arrays(), xform)
	elif shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = (shape as SphereShape3D).radius
		sphere.height = (shape as SphereShape3D).radius * 2.0
		source.add_mesh_array(sphere.get_mesh_arrays(), xform)
	else:
		_warn_skipped(node, "форма %s не поддерживается" % shape.get_class())


func _add_box(source: NavigationMeshSourceGeometryData3D, box_size: Vector3, xform: Transform3D) -> void:
	# Массивы примитива считаются на процессоре — без обращения к видеокарте
	var box := BoxMesh.new()
	box.size = box_size
	source.add_mesh_array(box.get_mesh_arrays(), xform)


func _warn_skipped(node: Node, reason: String) -> void:
	if _skipped_warned:
		return
	_skipped_warned = true
	push_warning("RuntimeNavRegion '%s': '%s' пропущена — %s" % [name, node.name, reason])
