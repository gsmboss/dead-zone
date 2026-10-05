class_name GameSounds
extends Resource
## Общий набор звуков игры (зомби, игрок, попадания, интерфейс).
## Звуки оружия — в WeaponData. Файл данных: res://audio/game_sounds.tres.

@export_group("Player")
@export var footsteps: Array[AudioStream] = []
@export var player_hurt: Array[AudioStream] = []

@export_group("Impacts")
@export var flesh_hits: Array[AudioStream] = []
@export var world_hits: Array[AudioStream] = []
@export var metal_hits: Array[AudioStream] = []

@export_group("Zombies")
## Рычание и стоны во время ходьбы/погони
@export var zombie_idle: Array[AudioStream] = []
@export var zombie_attack: Array[AudioStream] = []
@export var zombie_hurt: Array[AudioStream] = []
@export var zombie_death: Array[AudioStream] = []

@export_group("World")
@export var explosions: Array[AudioStream] = []
## Петли: огонь (коктейль Молотова), дождь
@export var fire_loop: AudioStream
@export var rain_loop: AudioStream

@export_group("UI")
@export var ui_click: AudioStream
@export var ui_back: AudioStream
@export var ui_error: AudioStream
@export var ui_confirm: AudioStream
@export var purchase: AudioStream
@export var pickup: AudioStream
@export var hitmarker: AudioStream
## Щелчок пустого оружия
@export var dry_fire: AudioStream
