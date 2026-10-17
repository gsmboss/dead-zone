class_name EvacPoint
extends Area3D
## Точка эвакуации: приведи сюда выживших. Зелёный дым-маяк и надпись видны издалека.

const RADIUS: float = 4.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0  # выжившие на слое 0 — проверяем расстояние вручную
	monitoring = false
	monitorable = false
	_build_marker()


func _physics_process(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(Survivor.GROUP):
		var survivor := node as Survivor
		if survivor == null or survivor.state != Survivor.State.FOLLOWING:
			continue
		var offset: Vector3 = survivor.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= RADIUS:
			survivor.rescue()


func _build_marker() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.3, 1.0, 0.4, 0.2)
	var ring := CylinderMesh.new()
	ring.top_radius = RADIUS
	ring.bottom_radius = RADIUS
	ring.height = 0.05
	ring.radial_segments = 32
	ring.rings = 1
	ring.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = ring
	disc.position.y = 0.04
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.2
	quad.material = smoke_material
	var smoke := CPUParticles3D.new()
	smoke.mesh = quad
	smoke.amount = 24
	smoke.lifetime = 4.0
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0.3, 0.4, 0.0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.4, 1.0, 0.45, 0.8))
	ramp.set_color(1, Color(0.4, 1.0, 0.45, 0.0))
	smoke.color_ramp = ramp
	add_child(smoke)

	var label := Label3D.new()
	label.text = "ЭВАКУАЦИЯ"
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.5, 1.0, 0.55)
	label.position.y = 3.5
	add_child(label)
