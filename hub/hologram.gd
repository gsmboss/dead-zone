class_name Hologram
extends Node3D
## Голограмма над терминалом убежища: вращающаяся полупрозрачная модель,
## покачивается вверх-вниз, проигрывает анимацию модели (если есть), под ней — луч.

@export var model_scene: PackedScene
@export var model_scale: float = 1.0
## Анимация модели (например, Idle у зомби). Пусто — без анимации
@export var animation: StringName = &""
@export var spin_speed: float = 0.8
@export var bob_height: float = 0.08
@export var bob_speed: float = 1.8
@export var color: Color = Color(0.3, 0.9, 1.0, 0.55)
## Полупрозрачный «голографический» материал вместо родного
@export var hologram_look: bool = true
## Высота (в координатах родителя), откуда светит луч: верх стола терминала
@export var beam_bottom: float = 1.0

var _model: Node3D
var _time: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y
	if model_scene == null:
		push_warning("Hologram '%s': не задана model_scene" % name)
		return
	_model = model_scene.instantiate() as Node3D
	if _model == null:
		push_warning("Hologram '%s': model_scene не Node3D" % name)
		return
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	if hologram_look:
		_apply_hologram_material(_model)
	_play_animation()
	_add_beam()


func _process(delta: float) -> void:
	_time += delta
	rotation.y += spin_speed * delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height


func _apply_hologram_material(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.rim_enabled = false
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.material_override = material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _play_animation() -> void:
	if animation == &"":
		return
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	if player.has_animation(animation):
		var anim: Animation = player.get_animation(animation)
		anim.loop_mode = Animation.LOOP_LINEAR
		player.play(animation)
	else:
		push_warning("Hologram '%s': нет анимации %s" % [name, animation])


## Световой конус от стола к модели
func _add_beam() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, 0.12)
	var beam_height: float = maxf(_base_y - beam_bottom + 0.1, 0.1)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.08
	cone.height = beam_height
	cone.radial_segments = 16
	cone.rings = 1
	cone.material = material
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Луч не вращается и не прыгает вместе с моделью — вешаем на родителя
	beam.position = Vector3(0.0, beam_bottom + beam_height * 0.5, 0.0)
	get_parent().add_child.call_deferred(beam)
