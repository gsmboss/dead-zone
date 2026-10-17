class_name Torch
extends Node3D
## Факел в левой руке: деревянная ручка, живой огонь (частицы) и тёплый мерцающий свет.
## Висит на голове игрока — виден и от 1-го, и от 3-го лица. Свет без теней (дёшево).

const LIGHT_COLOR: Color = Color(1.0, 0.62, 0.3)
const LIGHT_ENERGY: float = 1.9
const LIGHT_RANGE: float = 11.0
## Положение в руке относительно головы (слева-снизу, перед лицом)
const HELD_OFFSET: Vector3 = Vector3(-0.3, -0.32, -0.5)

var lit: bool = false

var _light: OmniLight3D
var _flames: CPUParticles3D
var _time: float = 0.0


func _ready() -> void:
	position = HELD_OFFSET
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.36, 0.22, 0.12)
	handle_material.roughness = 1.0
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.018
	handle_mesh.height = 0.34
	handle_mesh.radial_segments = 8
	handle_mesh.rings = 1
	handle_mesh.material = handle_material
	var handle := MeshInstance3D.new()
	handle.mesh = handle_mesh
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handle.rotation_degrees = Vector3(-20.0, 0.0, 10.0)
	add_child(handle)

	var cloth_material := StandardMaterial3D.new()
	cloth_material.albedo_color = Color(0.2, 0.15, 0.12)
	var cloth_mesh := CylinderMesh.new()
	cloth_mesh.top_radius = 0.04
	cloth_mesh.bottom_radius = 0.035
	cloth_mesh.height = 0.08
	cloth_mesh.radial_segments = 8
	cloth_mesh.rings = 1
	cloth_mesh.material = cloth_material
	var cloth := MeshInstance3D.new()
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.03, 0.17, -0.06)
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloth)

	_flames = GraveyardBuilder.make_flames()
	_flames.position = cloth.position + Vector3.UP * 0.05
	_flames.amount = 16
	_flames.scale = Vector3.ONE * 0.5
	add_child(_flames)

	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	_light.position = cloth.position + Vector3.UP * 0.15
	add_child(_light)
	set_lit(lit)


func set_lit(enabled: bool) -> void:
	lit = enabled
	visible = enabled
	set_process(enabled)
	if _flames != null:
		_flames.emitting = enabled


func toggle() -> void:
	set_lit(not lit)
	Sfx.click()


func _process(delta: float) -> void:
	_time += delta
	# Живое мерцание огня
	_light.light_energy = LIGHT_ENERGY + sin(_time * 13.0) * 0.18 + sin(_time * 7.1) * 0.14
