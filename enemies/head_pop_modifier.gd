class_name HeadPopModifier
extends SkeletonModifier3D
## Хедшот: голова зомби «лопается» — кость Head (и всё, что на ней) сжимается почти в ноль.
## Модификатор скелета работает после анимации, поэтому анимация смерти голову не возвращает.
## Создаёт Zombie при смерти от выстрела в голову.

## Индекс кости головы в скелете
var bone: int = -1
## Сжатие за доли секунды (не мгновенно — видно «хлопок»)
var pop_time: float = 0.06

var _elapsed: float = 0.0


## Godot 4.4+: модификация с delta
func _process_modification_with_delta(delta: float) -> void:
	_elapsed += delta
	_apply()


## Старый вариант API (без delta) — на случай другой версии движка
func _process_modification() -> void:
	_elapsed += 1.0 / 60.0
	_apply()


func _apply() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or bone < 0 or bone >= skeleton.get_bone_count():
		return
	var k: float = clampf(1.0 - _elapsed / maxf(pop_time, 0.001), 0.001, 1.0)
	skeleton.set_bone_pose_scale(bone, Vector3.ONE * k)
