class_name LandMine
extends Deployable
## Мина: взводится ARM_TIME секунд (лампа мигает), потом взрывается, когда рядом зомби.
## Урон взрыва — item.amount; игроку достаётся меньше (PLAYER_SCALE).

const ARM_TIME: float = 1.5
const TRIGGER_RADIUS: float = 1.3
const BLAST_RADIUS: float = 5.0
const PLAYER_SCALE: float = 0.3
const BLINK_PERIOD: float = 0.8

var _arm_left: float = ARM_TIME
var _blink: float = 0.0
var _lamp: MeshInstance3D
var _exploded: bool = false


func _build() -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.17
	body.bottom_radius = 0.2
	body.height = 0.07
	_add_mesh(body, Color(0.24, 0.27, 0.2), Vector3(0.0, 0.035, 0.0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.06
	cap.bottom_radius = 0.07
	cap.height = 0.04
	_add_mesh(cap, Color(0.3, 0.32, 0.27), Vector3(0.0, 0.09, 0.0))
	var lamp := SphereMesh.new()
	lamp.radius = 0.025
	lamp.height = 0.05
	_lamp = _add_mesh(lamp, Color(1.0, 0.2, 0.15), Vector3(0.1, 0.08, 0.0), null, 4.0)


func _process(delta: float) -> void:
	if _lamp == null or _exploded:
		return
	# Пока взводится — мигает часто, потом редко
	_blink += delta
	var period: float = 0.2 if _arm_left > 0.0 else BLINK_PERIOD
	_lamp.visible = fmod(_blink, period) < period * 0.5


func _check(delta: float) -> void:
	if _exploded:
		return
	if _arm_left > 0.0:
		_arm_left -= delta
		if _arm_left <= 0.0:
			Sfx.play_3d(Sfx.sounds.ui_click, global_position, -6.0, 1.6)
		return
	if _nearest_zombie(TRIGGER_RADIUS, 1.0) != null:
		_detonate()


func _detonate() -> void:
	_exploded = true
	var scene: Node = get_tree().current_scene
	Explosion.create(scene if scene != null else get_parent(), global_position + Vector3.UP * 0.3,
		BLAST_RADIUS, item.amount if item != null else 120.0, PLAYER_SCALE)
	queue_free()
