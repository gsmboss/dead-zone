class_name DefendPoint
extends Marker3D
## Точка обороны для миссий DEFEND. Кольцо и надпись появляются, только когда
## миссия включает точку (activate). Группа "defend_point".

const RING_HEIGHT: float = 0.05
const LABEL_HEIGHT: float = 3.0
const IDLE_COLOR: Color = Color(1.0, 0.8, 0.2, 0.3)
const ACTIVE_COLOR: Color = Color(0.3, 1.0, 0.4, 0.35)

var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group(&"defend_point")


## Показать точку радиусом radius
func activate(radius: float) -> void:
	if _ring == null:
		_build(radius)
	_ring.visible = true
	_label.visible = true


## Подсветка: игрок на точке или нет
func set_occupied(occupied: bool) -> void:
	if _material != null:
		_material.albedo_color = ACTIVE_COLOR if occupied else IDLE_COLOR


func _build(radius: float) -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = IDLE_COLOR

	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = RING_HEIGHT
	disc.radial_segments = 32
	disc.rings = 1
	disc.material = _material

	_ring = MeshInstance3D.new()
	_ring.mesh = disc
	_ring.position.y = RING_HEIGHT
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_label = Label3D.new()
	_label.text = "ТОЧКА"
	_label.font_size = 64
	_label.outline_size = 16
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.85, 0.3)
	_label.position.y = LABEL_HEIGHT
	add_child(_label)
