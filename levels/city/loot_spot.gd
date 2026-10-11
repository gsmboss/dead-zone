class_name LootSpot
extends Area3D
## Вход в магазин с припасами: постой в светящейся зоне — игрок обыскивает здание
## и получает лут (монеты, лом, аптечку, патроны, гранату или коктейль).

const SEARCH_TIME: float = 1.5
const RADIUS: float = 1.6
const MARKER_COLOR: Color = Color(1.0, 0.8, 0.25)

var _progress: float = 0.0
var _looted: bool = false
var _label: Label3D
var _marker: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 2.5
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position = Vector3.UP * 1.25
	add_child(shape)
	_build_marker()


func _process(delta: float) -> void:
	if _looted:
		return
	var inside: bool = false
	if has_overlapping_bodies():
		for body: Node3D in get_overlapping_bodies():
			if body is Player:
				inside = true
				break
	if inside:
		_progress += delta
		_label.text = UIKit.t("ОБЫСК %d%%") % roundi(minf(_progress / SEARCH_TIME, 1.0) * 100.0)
		if _progress >= SEARCH_TIME:
			_loot()
	elif _progress > 0.0:
		_progress = 0.0
		_label.text = "ПРИПАСЫ"


func _loot() -> void:
	_looted = true
	var found := PackedStringArray()
	var coins: int = _rng.randi_range(20, 60)
	GameState.add_coins(coins)
	found.append(UIKit.coins_text(coins))
	var scrap: int = _rng.randi_range(1, 4)
	if GameState.add_item(GameState.SCRAP_ID, scrap):
		found.append(UIKit.t("ЛОМ ×%d") % scrap)
	var extras: Array[String] = ["medkit", "ammo_pack", "grenade", "molotov"]
	var extra: String = extras[_rng.randi() % extras.size()]
	if _rng.randf() < 0.75 and GameState.add_item(extra):
		var item: ItemData = GameState.get_item(extra)
		found.append(UIKit.t(item.title) if item != null else UIKit.t(extra))
	Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if manager != null:
		manager.announcement.emit(UIKit.t("НАЙДЕНО: ") + ", ".join(found))
	_marker.queue_free()
	_label.queue_free()


func _build_marker() -> void:
	_marker = Node3D.new()
	add_child(_marker)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(MARKER_COLOR, 0.22)
	var ring := CylinderMesh.new()
	ring.top_radius = RADIUS
	ring.bottom_radius = RADIUS
	ring.height = 0.05
	ring.radial_segments = 24
	ring.rings = 1
	ring.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = ring
	disc.position.y = 0.05
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(disc)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.12
	beam.bottom_radius = 0.12
	beam.height = 5.0
	beam.radial_segments = 8
	beam.rings = 1
	var beam_material := material.duplicate() as StandardMaterial3D
	beam_material.albedo_color = Color(MARKER_COLOR, 0.3)
	beam.material = beam_material
	var beam_instance := MeshInstance3D.new()
	beam_instance.mesh = beam
	beam_instance.position.y = 2.5
	beam_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(beam_instance)
	_label = Label3D.new()
	_label.text = "ПРИПАСЫ"
	_label.font_size = 48
	_label.outline_size = 12
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = MARKER_COLOR
	_label.position.y = 2.6
	add_child(_label)
