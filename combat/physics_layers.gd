class_name PhysicsLayers
extends RefCounted
## Битовые маски слоёв физики (слой N = 1 << (N - 1)).

const WORLD: int = 1 << 0   # слой 1: пол, стены, препятствия
const PLAYER: int = 1 << 1  # слой 2: игрок
const ENEMY: int = 1 << 2   # слой 3: тела врагов (для движения)
const HITBOX: int = 1 << 3  # слой 4: зоны попадания

## Что видит луч выстрела: мир (стены закрывают цели) и хитбоксы
const SHOT_MASK: int = WORLD | HITBOX
