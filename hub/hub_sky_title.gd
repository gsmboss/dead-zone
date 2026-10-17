class_name HubSkyTitle
extends Node3D
## Надпись DEAD ZONE в небе над убежищем (на севере, по взгляду игрока со старта): картинка
## ui/splash/title.png на плоскости без света и тумана, медленно покачивается. Без картинки — Label3D.

const TITLE_IMAGE: String = "res://ui/splash/title.png"
## Где висит надпись (за оградой убежища, над облаками у горизонта) и её ширина в метрах
const SKY_POSITION: Vector3 = Vector3(0.0, 21.0, -62.0)
const WIDTH: float = 46.0
## Покачивание: высота (м) и период (с)
const BOB_HEIGHT: float = 0.8
const BOB_PERIOD: float = 5.0
## Наклон к игроку (надпись чуть смотрит вниз — читается снизу без искажений)
const TILT_DEGREES: float = 12.0


func _ready() -> void:
	position = SKY_POSITION
	rotation_degrees.x = TILT_DEGREES
	var texture: Texture2D = load(TITLE_IMAGE) as Texture2D if ResourceLoader.exists(TITLE_IMAGE) else null
	if texture != null:
		_add_picture(texture)
	else:
		push_warning("%s: нет %s — надпись текстом" % [name, TITLE_IMAGE])
		_add_label()
	var bob: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, ^"position:y", SKY_POSITION.y + BOB_HEIGHT, BOB_PERIOD * 0.5)
	bob.tween_property(self, ^"position:y", SKY_POSITION.y, BOB_PERIOD * 0.5)


func _add_picture(texture: Texture2D) -> void:
	var aspect: float = float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, WIDTH * aspect)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material = material
	var picture := MeshInstance3D.new()
	picture.name = "Title"
	picture.mesh = quad
	picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(picture)


func _add_label() -> void:
	var label := Label3D.new()
	label.name = "Title"
	label.text = "DEAD ZONE"
	label.font_size = 256
	label.outline_size = 48
	label.pixel_size = 0.04
	label.modulate = Color(0.95, 0.3, 0.15)
	label.outline_modulate = Color(0.05, 0.03, 0.02)
	label.shaded = false
	label.fixed_size = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
