class_name DayNightCycle
extends Node
## Смена дня и ночи: солнце ходит по небу, меняются свет, небо, туман и окружение.
## Ночью горят фонари (MultiMesh в группе night_glow), у машин включаются фары,
## зомби появляются чаще (MissionManager читает night_amount).

## 0 — день, 1 — глубокая ночь. Общая для всех (фары, спавн)
static var night_amount: float = 0.0

## Полный цикл (сутки), секунды
@export var cycle_length: float = 420.0
## Начальное время суток 0..1 (0.25 — рассвет, 0.5 — полдень, 0.75 — закат)
@export_range(0.0, 1.0, 0.01) var start_time: float = 0.42
## Пусто → первые DirectionalLight3D и WorldEnvironment в сцене
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

const DAY_SKY_TOP: Color = Color(0.38, 0.55, 0.8)
const DAY_HORIZON: Color = Color(0.66, 0.68, 0.7)
const NIGHT_SKY_TOP: Color = Color(0.02, 0.03, 0.08)
const NIGHT_HORIZON: Color = Color(0.08, 0.1, 0.16)
const SUNSET_COLOR: Color = Color(1.0, 0.6, 0.35)
const MOON_COLOR: Color = Color(0.5, 0.6, 0.9)
const SUN_YAW_DEGREES: float = 30.0
const UPDATE_INTERVAL: float = 0.1
const NIGHT_ANNOUNCE: float = 0.6

var time_of_day: float = 0.42
var _sky_material: ProceduralSkyMaterial
var _update_timer: float = 0.0
var _was_night: bool = false


func _ready() -> void:
	time_of_day = start_time
	var scene: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if sun == null:
		sun = scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if world_environment == null:
		for node: Node in scene.find_children("*", "WorldEnvironment", true, false):
			world_environment = node as WorldEnvironment
			break
	if world_environment != null and world_environment.environment != null:
		# Копия окружения: ресурс сцены не меняется
		world_environment.environment = world_environment.environment.duplicate(true) as Environment
		var sky: Sky = world_environment.environment.sky
		if sky != null:
			_sky_material = sky.sky_material as ProceduralSkyMaterial
	_apply()


func _exit_tree() -> void:
	night_amount = 0.0  # другие уровни — днём


func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / maxf(cycle_length, 1.0), 1.0)
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = UPDATE_INTERVAL
		_apply()


func _apply() -> void:
	var height: float = sin((time_of_day - 0.25) * TAU)  # 1 — полдень, -1 — полночь
	var daylight: float = smoothstep(-0.12, 0.3, height)
	night_amount = 1.0 - daylight
	var low_sun: float = clampf(1.0 - absf(height) * 3.0, 0.0, 1.0) * daylight

	if sun != null:
		var elevation: float = deg_to_rad(maxf(absf(height) * 65.0, 8.0))
		sun.rotation = Vector3(-elevation, deg_to_rad(SUN_YAW_DEGREES) + time_of_day * TAU * 0.25, 0.0)
		sun.light_energy = lerpf(0.12, 1.0, daylight)
		sun.light_color = Color.WHITE.lerp(SUNSET_COLOR, low_sun).lerp(MOON_COLOR, night_amount)

	if world_environment != null and world_environment.environment != null:
		var environment: Environment = world_environment.environment
		environment.ambient_light_energy = lerpf(0.25, 1.0, daylight)
		environment.background_energy_multiplier = lerpf(0.25, 1.0, daylight)
		var horizon: Color = DAY_HORIZON.lerp(SUNSET_COLOR, low_sun * 0.6).lerp(NIGHT_HORIZON, night_amount)
		environment.fog_light_color = horizon
		if _sky_material != null:
			_sky_material.sky_top_color = DAY_SKY_TOP.lerp(NIGHT_SKY_TOP, night_amount)
			_sky_material.sky_horizon_color = horizon
			_sky_material.ground_horizon_color = horizon

	for node: Node in get_tree().get_nodes_in_group(&"night_glow"):
		var glow := node as GeometryInstance3D
		if glow == null:
			continue
		var material := glow.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = night_amount * 4.0

	var is_night: bool = night_amount > NIGHT_ANNOUNCE
	if is_night != _was_night:
		_was_night = is_night
		var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
		if manager != null:
			manager.announcement.emit("НОЧЬ: ЗОМБИ АКТИВНЕЕ" if is_night else "РАССВЕТ")
