class_name BearTrap
extends Deployable
## Капкан: зомби наступил — челюсти захлопываются, урон item.amount и держит HOLD_TIME секунд.
## Срабатывает CHARGES раз, между срабатываниями взводится заново.

const CHARGES: int = 3
const HOLD_TIME: float = 4.0
const TRIGGER_RADIUS: float = 0.75
const REARM_TIME: float = 2.5
## Челюсти: раскрытые лежат на земле, захлопнутые поднимаются и сходятся над центром
const OPEN_ANGLE: float = 0.0
const CLOSED_ANGLE: float = -1.45

var _charges: int = CHARGES
var _rearm_left: float = 0.0
var _jaw_a: Node3D
var _jaw_b: Node3D


func _build() -> void:
	var steel := Color(0.45, 0.43, 0.4)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.22
	plate.bottom_radius = 0.24
	plate.height = 0.04
	_add_mesh(plate, steel.darkened(0.3), Vector3(0.0, 0.02, 0.0))
	var pedal := CylinderMesh.new()
	pedal.top_radius = 0.1
	pedal.bottom_radius = 0.1
	pedal.height = 0.03
	_add_mesh(pedal, Color(0.55, 0.45, 0.25), Vector3(0.0, 0.05, 0.0))
	_jaw_a = _make_jaw(steel, 1.0)
	_jaw_b = _make_jaw(steel, -1.0)
	_set_open(true)


## Челюсть — дуга с зубьями на шарнире у края пластины
func _make_jaw(color: Color, side: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = Vector3(0.0, 0.04, 0.0)
	hinge.rotation.y = 0.0 if side > 0.0 else PI
	add_child(hinge)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.48, 0.025, 0.04)
	_add_mesh(bar, color, Vector3(0.0, 0.0, 0.26), hinge)
	for i in 5:
		var tooth := PrismMesh.new()
		tooth.size = Vector3(0.05, 0.08, 0.025)
		_add_mesh(tooth, color.lightened(0.2), Vector3(-0.18 + i * 0.09, 0.05, 0.26), hinge)
	return hinge


func _set_open(open: bool) -> void:
	var angle: float = OPEN_ANGLE if open else CLOSED_ANGLE
	_jaw_a.rotation.x = angle
	_jaw_b.rotation.x = angle


func _check(delta: float) -> void:
	if _rearm_left > 0.0:
		_rearm_left -= delta
		if _rearm_left <= 0.0:
			_animate_open()
		return
	var zombie: Zombie = _nearest_zombie(TRIGGER_RADIUS, 0.8)
	if zombie == null or zombie.is_held():
		return
	_snap(zombie)


func _snap(zombie: Zombie) -> void:
	_charges -= 1
	# Захлопнулись
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_jaw_a, "rotation:x", CLOSED_ANGLE, 0.06)
	tween.tween_property(_jaw_b, "rotation:x", CLOSED_ANGLE, 0.06)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), global_position, 2.0, 0.6)
	zombie.hold(HOLD_TIME)
	if zombie.health != null:
		zombie.health.take_damage(item.amount if item != null else 45.0, zombie.global_position + Vector3.UP * 0.3,
			false)
	Impacts.spawn_blood(global_position + Vector3.UP * 0.05)
	if _charges <= 0:
		remove()
	else:
		_rearm_left = REARM_TIME + HOLD_TIME


func _animate_open() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_jaw_a, "rotation:x", OPEN_ANGLE, 0.4)
	tween.tween_property(_jaw_b, "rotation:x", OPEN_ANGLE, 0.4)
	Sfx.play_3d(Sfx.pick(Sfx.sounds.metal_hits), global_position, -8.0, 1.3)
