class_name AccessoryBuilder
extends RefCounted
## Собирает аксессуар из простых фигур. Единица — ширина головы.
## HEAD: начало координат — макушка (по центру), +Y вверх. FACE: начало — лицо на уровне глаз, +Z от лица.

const BLACK: Color = Color(0.08, 0.08, 0.09)
const WHITE: Color = Color(0.95, 0.95, 0.93)
const GOLD: Color = Color(1.0, 0.78, 0.2)
const METAL: Color = Color(0.62, 0.64, 0.68)


## Модель аксессуара (null — неизвестная форма)
static func build(data: AccessoryData) -> Node3D:
	if data == null:
		return null
	var root := Node3D.new()
	root.name = "Accessory_%s" % data.id
	var c: Color = data.color
	match data.kind:
		"cap":
			_part(root, _sphere(0.52, 0.5), c, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			_part(root, _box(Vector3(0.62, 0.04, 0.42)), c.darkened(0.2), Vector3(0, -0.05, 0.42))
		"beanie":
			_part(root, _sphere(0.55, 0.55), c, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
			_part(root, _torus(0.5, 0.6), c.darkened(0.25), Vector3(0, -0.12, 0))
			_part(root, _sphere(0.1, 0.1), WHITE, Vector3(0, 0.38, 0))
		"cowboy":
			_part(root, _cylinder(0.85, 0.85, 0.04), c, Vector3(0, 0.0, 0))
			_part(root, _cylinder(0.36, 0.44, 0.42), c, Vector3(0, 0.22, 0))
			_part(root, _cylinder(0.45, 0.45, 0.07), BLACK, Vector3(0, 0.06, 0))
		"top_hat":
			_part(root, _cylinder(0.68, 0.68, 0.04), BLACK, Vector3(0, 0.0, 0))
			_part(root, _cylinder(0.38, 0.38, 0.8), BLACK, Vector3(0, 0.42, 0))
			_part(root, _cylinder(0.39, 0.39, 0.1), c, Vector3(0, 0.1, 0))
		"party_hat":
			_part(root, _cylinder(0.0, 0.34, 0.8), c, Vector3(0.05, 0.38, 0), Vector3(0, 0, -12))
			_part(root, _sphere(0.09, 0.09), WHITE, Vector3(-0.03, 0.8, 0))
		"crown":
			_part(root, _cylinder(0.42, 0.4, 0.22), GOLD, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, true)
			for i in 5:
				var angle: float = TAU * i / 5.0
				var at := Vector3(cos(angle) * 0.4, 0.25, sin(angle) * 0.4)
				_part(root, _cylinder(0.0, 0.08, 0.18), GOLD, at, Vector3.ZERO, Vector3.ONE, true)
				_part(root, _sphere(0.045, 0.045), c, Vector3(cos(angle) * 0.42, 0.1, sin(angle) * 0.42), Vector3.ZERO,
					Vector3.ONE, true)
		"halo":
			_part(root, _torus(0.34, 0.42), GOLD.lightened(0.3), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3.ONE, true)
		"bunny_ears":
			for side: float in [-1.0, 1.0]:
				_part(root, _capsule(0.09, 0.7), c, Vector3(side * 0.18, 0.3, 0), Vector3(0, 0, -side * 12.0))
				_part(root, _capsule(0.05, 0.5), Color(1.0, 0.65, 0.75), Vector3(side * 0.19, 0.3, 0.05),
					Vector3(0, 0, -side * 12.0))
		"viking":
			_part(root, _sphere(0.55, 0.55), METAL, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
			_part(root, _box(Vector3(0.08, 0.5, 0.06)), METAL.darkened(0.3), Vector3(0, 0.0, 0.45))
			for side: float in [-1.0, 1.0]:
				_part(root, _cylinder(0.0, 0.1, 0.5), WHITE.darkened(0.1), Vector3(side * 0.62, 0.15, 0),
					Vector3(0, 0, -side * 55.0))
		"chef":
			_part(root, _cylinder(0.4, 0.4, 0.22), WHITE, Vector3(0, 0.08, 0))
			_part(root, _sphere(0.46, 0.46), WHITE, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		"propeller":
			_part(root, _sphere(0.52, 0.5), c, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
			_part(root, _cylinder(0.025, 0.025, 0.2), METAL, Vector3(0, 0.3, 0))
			var blades := Node3D.new()
			blades.position = Vector3(0, 0.41, 0)
			root.add_child(blades)
			_part(blades, _box(Vector3(0.75, 0.02, 0.09)), Color(1.0, 0.85, 0.2), Vector3.ZERO)
			_part(blades, _box(Vector3(0.09, 0.02, 0.75)), Color(0.3, 0.6, 1.0), Vector3.ZERO)
			# Пропеллер крутится всегда
			blades.ready.connect(func() -> void:
				var spin := blades.create_tween().set_loops()
				spin.tween_property(blades, "rotation:y", TAU, 0.45).from(0.0), CONNECT_ONE_SHOT)
		"traffic_cone":
			_part(root, _cylinder(0.05, 0.42, 0.9), Color(1.0, 0.45, 0.1), Vector3(0, 0.42, 0), Vector3(0, 0, 8))
			_part(root, _cylinder(0.24, 0.29, 0.12), WHITE, Vector3(0.03, 0.42, 0), Vector3(0, 0, 8))
		"pot":
			_part(root, _cylinder(0.5, 0.46, 0.42), METAL, Vector3(0, 0.12, 0), Vector3(6, 0, 5))
			for side: float in [-1.0, 1.0]:
				_part(root, _box(Vector3(0.2, 0.05, 0.08)), BLACK, Vector3(side * 0.58, 0.25, 0))
		"headphones":
			_part(root, _torus(0.5, 0.58), BLACK, Vector3(0, -0.5, 0), Vector3(90, 0, 90))
			for side: float in [-1.0, 1.0]:
				_part(root, _cylinder(0.2, 0.2, 0.14), c, Vector3(side * 0.56, -0.6, 0), Vector3(0, 0, 90))
		"sunglasses":
			for side: float in [-1.0, 1.0]:
				_part(root, _box(Vector3(0.3, 0.17, 0.04)), BLACK, Vector3(side * 0.2, 0, 0.02))
				_part(root, _box(Vector3(0.03, 0.03, 0.5)), BLACK, Vector3(side * 0.47, 0.04, -0.25))
			_part(root, _box(Vector3(0.12, 0.03, 0.03)), BLACK, Vector3(0, 0.05, 0.02))
		"glasses_round":
			for side: float in [-1.0, 1.0]:
				_part(root, _torus(0.1, 0.13), c, Vector3(side * 0.2, 0, 0.02), Vector3(90, 0, 0))
				_part(root, _box(Vector3(0.03, 0.03, 0.5)), c, Vector3(side * 0.47, 0.0, -0.25))
			_part(root, _box(Vector3(0.12, 0.025, 0.025)), c, Vector3(0, 0.02, 0.02))
		"clown_nose":
			_part(root, _sphere(0.11, 0.11), Color(1.0, 0.08, 0.05), Vector3(0, -0.16, 0.06))
		"mustache":
			for side: float in [-1.0, 1.0]:
				_part(root, _capsule(0.05, 0.3), c, Vector3(side * 0.13, -0.27, 0.03), Vector3(0, 0, side * 70.0))
		"bandana":
			_part(root, _box(Vector3(1.04, 0.38, 0.06)), c, Vector3(0, -0.33, 0.0))
			_part(root, _cylinder(0.0, 0.2, 0.26), c, Vector3(0, -0.6, 0.02), Vector3(180, 0, 0))
		"eyepatch":
			_part(root, _box(Vector3(0.2, 0.17, 0.04)), BLACK, Vector3(0.2, 0, 0.03))
			_part(root, _box(Vector3(1.06, 0.03, 0.03)), BLACK, Vector3(0, 0.1, -0.01), Vector3(0, 0, -12))
		_:
			push_warning("AccessoryBuilder: неизвестная форма '%s' у %s" % [data.kind, data.id])
			root.free()
			return null
	return root


static func _part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, rotation_degrees: Vector3 = Vector3.ZERO,
		part_scale: Vector3 = Vector3.ONE, glow: bool = false) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation_degrees
	instance.scale = part_scale
	parent.add_child(instance)
	return instance


static func _sphere(radius: float, half_height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = half_height * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return mesh


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 8
	return mesh


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	return mesh
