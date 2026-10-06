class_name Explosion
extends Node3D
## Взрыв: урон зомби и игроку с ослаблением к краю, отбрасывание, вспышка, огонь и дым, звук.
## Создаётся через Explosion.create(); удаляет себя после эффекта.

const LIFETIME: float = 1.6
const FLASH_TIME: float = 0.18

var radius: float = 4.5
var damage: float = 60.0
## Доля урона по игроку (своя граната бьёт слабее)
var player_damage_scale: float = 0.5

var _light: OmniLight3D
var _time: float = 0.0


## Взрыв в точке at. parent — куда добавить эффект (обычно текущая сцена)
static func create(parent: Node, at: Vector3, blast_radius: float, blast_damage: float,
		player_scale: float = 0.5) -> Explosion:
	if parent == null or not parent.is_inside_tree():
		return null
	var explosion := Explosion.new()
	explosion.radius = blast_radius
	explosion.damage = blast_damage
	explosion.player_damage_scale = player_scale
	parent.add_child(explosion)
	explosion.global_position = at
	return explosion


func _ready() -> void:
	# create() ставит позицию после add_child — урон и звук считаем, когда она уже задана
	_start.call_deferred()


func _start() -> void:
	if not is_inside_tree():
		return
	_apply_damage()
	_spawn_effects()
	_play_sound()


func _process(delta: float) -> void:
	_time += delta
	if _light != null:
		_light.light_energy = maxf(0.0, 1.0 - _time / FLASH_TIME) * 8.0
	if _time >= LIFETIME:
		queue_free()


func _apply_damage() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null or zombie.state == Zombie.State.DEAD:
			continue
		var offset: Vector3 = zombie.global_position - global_position
		var distance: float = offset.length()
		if distance > radius:
			continue
		var falloff: float = 1.0 - distance / radius
		var push: Vector3 = offset.normalized() * 14.0 * falloff if distance > 0.01 else Vector3.UP
		zombie.apply_blast(damage * (0.35 + 0.65 * falloff), push)

	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health == null or player.health.is_dead:
		return
	var to_player: Vector3 = player.global_position - global_position
	var player_distance: float = to_player.length()
	if player_distance <= radius:
		var player_falloff: float = 1.0 - player_distance / radius
		player.health.take_damage_from(damage * player_damage_scale * player_falloff, global_position, false,
			Health.Kind.EXPLOSION)
		if player_distance > 0.01:
			player.apply_knockback(to_player.normalized() * 8.0 * player_falloff + Vector3.UP * 3.0 * player_falloff)
	if player_distance <= radius * 4.0:
		player.shake(clampf(1.0 - player_distance / (radius * 4.0), 0.0, 1.0))


func _spawn_effects() -> void:
	# Огненный шар и дым — разовые частицы
	add_child(_make_particles(Color(1.0, 0.55, 0.15), 28, 0.5, 6.0, 0.45, Vector3(0.0, 1.0, 0.0)))
	add_child(_make_particles(Color(0.25, 0.23, 0.22, 0.8), 18, 1.4, 2.5, 0.9, Vector3(0.0, 2.5, 0.0)))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.omni_range = radius * 2.5
	_light.position = Vector3.UP
	add_child(_light)


func _make_particles(color: Color, amount: int, lifetime: float, speed: float, size: float,
		gravity: Vector3) -> CPUParticles3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	var particles := CPUParticles3D.new()
	particles.mesh = quad
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = gravity
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	particles.color_ramp = ramp
	particles.emitting = true
	particles.position = Vector3.UP * 0.5
	return particles


func _play_sound() -> void:
	Sfx.play_3d(Sfx.pick(Sfx.sounds.explosions), global_position, 4.0, 1.0, 0.1)
