extends Node
## Автозагрузка "Sfx": пулы плееров звука без аллокаций во время игры.
## 2D — интерфейс и своё оружие, 3D — зомби и попадания в мире.

const SOUNDS_PATH: String = "res://audio/game_sounds.tres"
const POOL_2D: int = 10
const POOL_3D: int = 16
const DEFAULT_PITCH_JITTER: float = 0.06

## Набор звуков (зомби, игрок, UI). Никогда не null
var sounds: GameSounds

var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d: int = 0
var _next_3d: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_rng.randomize()
	if ResourceLoader.exists(SOUNDS_PATH):
		sounds = load(SOUNDS_PATH) as GameSounds
	if sounds == null:
		push_warning("Sfx: не найден набор звуков %s, игра будет без звука" % SOUNDS_PATH)
		sounds = GameSounds.new()

	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players_2d.append(player)
	for i in POOL_3D:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.unit_size = 6.0
		player_3d.max_distance = 45.0
		player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player_3d)
		_players_3d.append(player_3d)


## Случайный звук из списка (null, если список пуст)
func pick(list: Array[AudioStream]) -> AudioStream:
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()]


## Звук без позиции (UI, своё оружие, шаги игрока). Возвращает плеер (можно остановить)
func play_2d(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0,
		pitch_jitter: float = DEFAULT_PITCH_JITTER) -> AudioStreamPlayer:
	if stream == null or _players_2d.is_empty():
		return null
	var player: AudioStreamPlayer = _players_2d[_take_index(_players_2d.size(), true)]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch + _rng.randf_range(-pitch_jitter, pitch_jitter), 0.1)
	player.play()
	return player


## Звук в точке мира (зомби, попадания)
func play_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0,
		pitch_jitter: float = DEFAULT_PITCH_JITTER) -> void:
	if stream == null or _players_3d.is_empty():
		return
	var player: AudioStreamPlayer3D = _players_3d[_take_index(_players_3d.size(), false)]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch + _rng.randf_range(-pitch_jitter, pitch_jitter), 0.1)
	player.global_position = position
	player.play()


func click() -> void:
	play_2d(sounds.ui_click, -6.0, 1.0, 0.0)


func error() -> void:
	play_2d(sounds.ui_error, -4.0, 1.0, 0.0)


## Свободный плеер, иначе самый старый по кругу
func _take_index(count: int, is_2d: bool) -> int:
	var start: int = _next_2d if is_2d else _next_3d
	var chosen: int = start
	for offset in count:
		var index: int = (start + offset) % count
		var busy: bool = _players_2d[index].playing if is_2d else _players_3d[index].playing
		if not busy:
			chosen = index
			break
	if is_2d:
		_next_2d = (chosen + 1) % count
	else:
		_next_3d = (chosen + 1) % count
	return chosen
