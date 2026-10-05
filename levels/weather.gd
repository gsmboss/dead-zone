class_name Weather
extends Node3D
## Погода: ясно ↔ дождь. Дождь — частицы вокруг камеры, гуще туман, шум дождя.

@export var clear_time_min: float = 90.0
@export var clear_time_max: float = 180.0
@export var rain_time_min: float = 50.0
@export var rain_time_max: float = 110.0
## Шанс, что уровень начнётся с дождём
@export_range(0.0, 1.0, 0.05) var start_rain_chance: float = 0.25
@export var rain_fog_multiplier: float = 2.2

const FADE_SPEED: float = 0.15
const RAIN_HEIGHT: float = 9.0
const RAIN_VOLUME_DB: float = -6.0

var raining: bool = false
var _intensity: float = 0.0
var _timer: float = 0.0
var _particles: CPUParticles3D
## Материал капель: у CPUParticles3D нет amount_ratio — силу дождя показываем прозрачностью
var _rain_material: StandardMaterial3D
const RAIN_ALPHA: float = 0.35
var _sound: AudioStreamPlayer
var _environment: Environment
var _base_fog: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	raining = _rng.randf() < start_rain_chance
	_intensity = 1.0 if raining else 0.0
	_timer = _next_duration()
	_build_rain()
	_find_environment.call_deferred()


func _find_environment() -> void:
	for node: Node in get_tree().current_scene.find_children("*", "WorldEnvironment", true, false):
		_environment = (node as WorldEnvironment).environment
		break
	if _environment != null:
		_base_fog = _environment.fog_density


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		raining = not raining
		_timer = _next_duration()
	_intensity = move_toward(_intensity, 1.0 if raining else 0.0, FADE_SPEED * delta)

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3.UP * RAIN_HEIGHT
	_particles.emitting = _intensity > 0.05
	if _rain_material != null:
		_rain_material.albedo_color.a = RAIN_ALPHA * _intensity
	if _environment != null and _environment.fog_enabled:
		_environment.fog_density = _base_fog * lerpf(1.0, rain_fog_multiplier, _intensity)
	if _sound.stream != null:
		if _intensity > 0.02 and not _sound.playing:
			_sound.play()
		elif _intensity <= 0.02 and _sound.playing:
			_sound.stop()
		_sound.volume_db = RAIN_VOLUME_DB + linear_to_db(maxf(_intensity, 0.001))


func _next_duration() -> float:
	return _rng.randf_range(rain_time_min, rain_time_max) if raining \
		else _rng.randf_range(clear_time_min, clear_time_max)


func _build_rain() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.8, 0.9, RAIN_ALPHA)
	_rain_material = material
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var streak := QuadMesh.new()
	streak.size = Vector2(0.03, 0.7)
	streak.material = material
	_particles = CPUParticles3D.new()
	_particles.mesh = streak
	_particles.amount = 320
	_particles.lifetime = 0.9
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	_particles.direction = Vector3.DOWN
	_particles.spread = 3.0
	_particles.initial_velocity_min = 14.0
	_particles.initial_velocity_max = 18.0
	_particles.gravity = Vector3(0.0, -5.0, 0.0)
	_particles.emitting = false
	add_child(_particles)
	_sound = AudioStreamPlayer.new()
	_sound.stream = Sfx.sounds.rain_loop
	_sound.volume_db = RAIN_VOLUME_DB
	add_child(_sound)
	_sound.finished.connect(_sound.play)  # петля
