class_name BaseVisuals
extends Node3D
## Постройки базы во дворе убежища: дочерние Marker3D — места (по порядку
## GameState.buildings). Построенное появляется с моделью и табличкой, без — пустое место.

const LABEL_HEIGHT: float = 2.4

var _spawned: Dictionary = {}  # id постройки -> Node3D


func _ready() -> void:
	GameState.progress_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var slots: Array[Marker3D] = []
	for child: Node in get_children():
		if child is Marker3D:
			slots.append(child as Marker3D)
	for i in GameState.buildings.size():
		var building: BuildingData = GameState.buildings[i]
		if i >= slots.size():
			push_warning("BaseVisuals: мест (Marker3D) меньше, чем построек")
			return
		var owned: bool = GameState.has_building(building.id)
		if owned and not _spawned.has(building.id):
			_spawned[building.id] = _spawn(building, slots[i])


func _spawn(building: BuildingData, slot: Marker3D) -> Node3D:
	var root := StaticBody3D.new()
	root.name = building.id.capitalize()
	root.collision_layer = PhysicsLayers.WORLD
	slot.add_child(root)
	if building.hub_model != null:
		var model := building.hub_model.instantiate() as Node3D
		if model != null:
			model.scale = Vector3.ONE * building.hub_model_scale
			root.add_child(model)
			_add_collision(root, model)
	var label := Label3D.new()
	label.text = building.title
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = building.icon_color.lightened(0.3)
	label.position.y = LABEL_HEIGHT
	root.add_child(label)
	# Появление: вырастает из земли
	root.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


func _add_collision(body: StaticBody3D, model: Node3D) -> void:
	var bounds := AABB()
	var has_bounds: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var xform: Transform3D = Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != body:
			var current_3d := current as Node3D
			if current_3d != null:
				xform = current_3d.transform * xform
			current = current.get_parent()
		var part: AABB = xform * mesh_instance.get_aabb()
		bounds = bounds.merge(part) if has_bounds else part
		has_bounds = true
	if not has_bounds:
		return
	var box := BoxShape3D.new()
	box.size = bounds.size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
