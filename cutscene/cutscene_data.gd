class_name CutsceneData
extends Resource
## Кат-сцена: последовательность планов. id — для отметки «уже показано» в сохранении.

@export var id: String = ""
@export var shots: Array[CutsceneShot] = []
## Замедление игрового времени во время сцены (1 — без замедления)
@export_range(0.05, 1.0, 0.05) var time_scale: float = 1.0
## Показывать один раз (флаг в GameState)
@export var once: bool = true
