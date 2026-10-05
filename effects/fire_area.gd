class_name FireArea
extends Area3D
## Лужа огня (коктейль Молотова): жжёт зомби и игрока внутри, пламя и треск огня.

const TICK: float = 0.25
## Игрока огонь жжёт слабее
const PLAYER_DAMAGE_SCALE: float = 0.4

var radius: float = 3.2
## Урон в секунду
var damage_per_second: float = 30.0
var duration: float = 6.0

var _time: float = 0.0
var _tick: float = 0.0
var _sound: AudioStreamPlayer3D
var _particles: CPUParticles3D


static func create(parent: Node, at: Vector3, fire_radius: float, dps: float, fire_duration: float) -> FireArea:
	if parent == null or not parent.is_inside_tree():
		return null
	var area := FireArea.new()
	area.radius = fire_radius
	area.damage_per_second = dps
	area.duration = fire_duration
	parent.add_child(area)
	area.global_position = Vector3(at.x, at.y, at.z)
	return area


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.ENEMY | PhysicsLayers.PLAYER
	monitorable = false
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 2.0
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position = Vector3.UP
	add_child(shape)
	_build_flames()
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.sounds.fire_loop
	_sound.unit_size = 5.0
	add_child(_sound)
	if _sound.stream != null:
		_sound.finished.connect(_sound.play)  # петля, даже если импорт без loop
		_sound.play()
	Sfx.play_3d(Sfx.pick(Sfx.sounds.explosions), global_position, -4.0, 1.6)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		if _particles != null:
			_particles.emitting = false
		if _time >= duration + 1.0:
			queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var amount: float = damage_per_second * TICK
	for body: Node3D in get_overlapping_bodies():
		var zombie := body as Zombie
		if zombie != null and zombie.health != null and zombie.state != Zombie.State.DEAD:
			zombie.health.take_damage(amount, zombie.global_position + Vector3.UP, false)
			continue
		var player := body as Player
		if player != null and player.health != null:
			player.health.take_damage(amount * PLAYER_DAMAGE_SCALE, global_position, false)


func _build_flames() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.7
	quad.material = material
	_particles = CPUParticles3D.new()
	_particles.mesh = quad
	_particles.amount = 40
	_particles.lifetime = 0.8
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(radius * 0.8, 0.1, radius * 0.8)
	_particles.direction = Vector3.UP
	_particles.spread = 15.0
	_particles.initial_velocity_min = 1.0
	_particles.initial_velocity_max = 2.5
	_particles.gravity = Vector3(0.0, 1.5, 0.0)
	_particles.scale_amount_min = 0.6
	_particles.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
	ramp.set_color(1, Color(0.6, 0.1, 0.0, 0.0))
	_particles.color_ramp = ramp
	_particles.position = Vector3.UP * 0.2
	add_child(_particles)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = radius * 2.0
	light.position = Vector3.UP
	add_child(light)
