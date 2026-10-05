class_name StaticProp
extends StaticBody3D
## Статичный объект окружения (модель glTF дочерней нодой).
## В _ready сам создаёт коллизию-коробку по габаритам дочерних мешей,
## поэтому модели можно расставлять в сцене без ручной настройки форм.
## Для объектов с выносом (фонари, светофоры) задайте custom_size — тогда
## коробка берётся из custom_size/custom_center, а не из габаритов меша.

## Размер коробки вручную (ноль — авто по мешам)
@export var custom_size: Vector3 = Vector3.ZERO
## Центр коробки вручную (в локальных координатах), используется вместе с custom_size
@export var custom_center: Vector3 = Vector3.ZERO
## Минимальная толщина авто-коробки, чтобы плоские объекты не проваливались
@export var min_thickness: float = 0.1


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0

	var box_size: Vector3 = custom_size
	var box_center: Vector3 = custom_center
	if box_size == Vector3.ZERO:
		var bounds: AABB = _compute_local_bounds()
		if bounds.size == Vector3.ZERO:
			push_warning("StaticProp '%s': нет мешей, коллизия не создана" % name)
			return
		box_size = bounds.size
		box_center = bounds.get_center()

	box_size.x = maxf(box_size.x, min_thickness)
	box_size.y = maxf(box_size.y, min_thickness)
	box_size.z = maxf(box_size.z, min_thickness)

	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.name = "AutoCollision"
	collision.shape = shape
	collision.position = box_center
	add_child(collision)


## Габариты всех MeshInstance3D-потомков в локальных координатах этого тела
func _compute_local_bounds() -> AABB:
	var to_local: Transform3D = global_transform.affine_inverse()
	var result := AABB()
	var has_bounds: bool = false
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var bounds: AABB = (to_local * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if has_bounds:
			result = result.merge(bounds)
		else:
			result = bounds
			has_bounds = true
	return result
