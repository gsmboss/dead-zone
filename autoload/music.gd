extends Node
## Автозагрузка "Music": фоновая музыка и динамическая боевая.
## Боевая плавно нарастает, когда рядом зомби гонятся за игроком, и стихает без них.

const CHECK_INTERVAL: float = 0.5
## Зомби в погоне ближе этого считаются «боем»
const COMBAT_DISTANCE: float = 25.0
## Столько преследователей — боевая музыка на полную
const FULL_COMBAT_ZOMBIES: int = 4
const FADE_SPEED: float = 0.6
const SILENT_DB: float = -60.0
const AMBIENT_DB: float = -10.0
const COMBAT_DB: float = -6.0

var _ambient: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _intensity: float = 0.0
var _target_intensity: float = 0.0
var _timer: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ambient = _make_player(Sfx.sounds.music_ambient)
	_combat = _make_player(Sfx.sounds.music_combat)
	_combat.volume_db = SILENT_DB


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_INTERVAL
		_target_intensity = _measure_combat()
	_intensity = move_toward(_intensity, _target_intensity, FADE_SPEED * delta)
	var music: float = Settings.music_volume
	var music_db: float = linear_to_db(maxf(music, 0.0001))
	_ambient.volume_db = lerpf(AMBIENT_DB, SILENT_DB * 0.5, _intensity) + music_db
	_combat.volume_db = lerpf(SILENT_DB, COMBAT_DB, _intensity) + music_db
	_ambient.stream_paused = music <= 0.001
	_combat.stream_paused = music <= 0.001 or _intensity <= 0.01


func _measure_combat() -> float:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return 0.0
	var chasing: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var zombie := node as Zombie
		if zombie == null:
			continue
		var hunting: bool = zombie.state == Zombie.State.CHASE or zombie.state == Zombie.State.ATTACK \
			or zombie.state == Zombie.State.CHARGE or zombie.state == Zombie.State.SLAM
		if hunting and zombie.global_position.distance_to(player.global_position) <= COMBAT_DISTANCE:
			chasing += 1
	return clampf(float(chasing) / FULL_COMBAT_ZOMBIES, 0.0, 1.0)


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	add_child(player)
	if stream != null:
		player.finished.connect(player.play)  # петля, если зацикливание не сработало
		player.play()
	return player
