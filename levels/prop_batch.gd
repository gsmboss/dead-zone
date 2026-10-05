class_name PropBatch
extends RefCounted
## Сборщик декораций уровня: одинаковые модели рисуются через MultiMesh (мало вызовов
## отрисовки на телефоне), коллизии — коробки в одном StaticBody3D слоя WORLD
## (по ним RuntimeNavRegion строит навмеш). Вызвать build() после всех add().

var _parent: Node3D
var _body: StaticBody3D
## PackedScene -> Array[Transform3D]
var _instances: Dictionary = {}
## PackedScene -> Array[Dictionary] {"mesh": Mesh, "xform": Transform3D}
var _parts_cache: Dictionary = {}
var _bounds_cache: Dictionary = {}
var _no_shadow: Dictionary = {}


func _init(parent: Node3D) -> void:
	_parent = parent
	_body = StaticBody3D.new()
	_body.name = "Colliders"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	parent.add_child(_body)


## Модель + коробка коллизии по габаритам (collide = false — только визуал).
## custom_box — свой размер коробки (например, ствол дерева), ставится от земли
func add(scene: PackedScene, xform: Transform3D, collide: bool = true, custom_box: Vector3 = Vector3.ZERO) -> void:
	if scene == null:
		return
	if not _instances.has(scene):
		_instances[scene] = []
	(_instances[scene] as Array).append(xform)
	if not collide:
		return
	if custom_box != Vector3.ZERO:
		add_box(xform.origin + Vector3.UP * custom_box.y * 0.5, custom_box)
		return
	var bounds: AABB = xform * get_bounds(scene)
	if bounds.size.x < 0.05 or bounds.size.z < 0.05:
		return
	add_box(bounds.get_center(), bounds.size)


func add_box(center: Vector3, box_size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(box_size.x, 0.1), maxf(box_size.y, 0.1), maxf(box_size.z, 0.1))
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = center
	_body.add_child(shape)


## Мелочь без теней (дешевле)
func set_no_shadow(scene: PackedScene) -> void:
	if scene != null:
		_no_shadow[scene] = true


func build() -> void:
	for scene: PackedScene in _instances:
		var transforms: Array = _instances[scene]
		var cast_shadows: bool = not _no_shadow.has(scene)
		for part: Dictionary in _scene_parts(scene):
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part["mesh"]
			multimesh.instance_count = transforms.size()
			var part_xform: Transform3D = part["xform"]
			for i in transforms.size():
				var instance_xform: Transform3D = transforms[i]
				multimesh.set_instance_transform(i, instance_xform * part_xform)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_parent.add_child(instance)
	_instances.clear()


## Габариты модели (в её координатах)
func get_bounds(scene: PackedScene) -> AABB:
	if _bounds_cache.has(scene):
		return _bounds_cache[scene]
	var result := AABB()
	var has_bounds: bool = false
	for part: Dictionary in _scene_parts(scene):
		var mesh: Mesh = part["mesh"]
		var bounds: AABB = (part["xform"] as Transform3D) * mesh.get_aabb()
		result = result.merge(bounds) if has_bounds else bounds
		has_bounds = true
	_bounds_cache[scene] = result
	return result


func _scene_parts(scene: PackedScene) -> Array:
	if _parts_cache.has(scene):
		return _parts_cache[scene]
	var parts: Array = []
	var root := scene.instantiate() as Node3D
	if root == null:
		push_warning("PropBatch: модель %s не Node3D" % scene.resource_path)
		_parts_cache[scene] = parts
		return parts
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != root:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		parts.append({"mesh": mesh_instance.mesh, "xform": xform})
	root.free()
	_parts_cache[scene] = parts
	return parts
