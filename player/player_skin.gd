class_name PlayerSkin
extends Resource
## Внешность игрока для вида от 3-го лица и мультиплеера: модель, анимации, кость руки.
## Размер подгоняется автоматически под height (по габаритам мешей).

@export var id: String = ""
@export var display_name: String = ""
@export var model_scene: PackedScene
## Цена в монетах (0 — бесплатно)
@export_range(0, 100000, 10) var price: int = 0
## Рост персонажа в метрах (модель масштабируется под него)
@export var height: float = 1.75

@export_group("Animations")
@export var anim_idle: StringName = &"Idle_Gun"
@export var anim_walk: StringName = &"Walk_Gun"
@export var anim_run: StringName = &"Run_Gun"
@export var anim_jump: StringName = &"Jump_Idle"
@export var anim_death: StringName = &"Death"
@export var anim_hit: StringName = &"HitReact"
@export var anim_melee: StringName = &"Slash"
## Без огнестрела (пустые руки или ближний бой) — обычные анимации, не стрелковая стойка
@export var anim_idle_unarmed: StringName = &"Idle"
@export var anim_walk_unarmed: StringName = &"Walk"
@export var anim_run_unarmed: StringName = &"Run"
## Приветствие в лобби
@export var anim_emote: StringName = &"Wave"
## Поза «сидя» (диван); нет такой анимации — присед или покой
@export var anim_sit: StringName = &"sit"
## Скорость (м/с), при которой анимация ходьбы и бега выглядит естественно
@export var walk_anim_speed: float = 1.6
@export var run_anim_speed: float = 4.5

@export_group("Hand")
## Не показывать оружие в руках (у блочных персонажей Kenney нет кисти — ствол висит криво)
@export var hide_weapon: bool = false
## Кость, к которой крепится оружие (пусто — оружие не показывается)
@export var hand_bone: StringName = &"LowerArm.R"
## Смещение и поворот оружия относительно кости (подгоняются в инспекторе)
@export var hand_offset: Vector3 = Vector3(0.0, 0.25, 0.0)
@export var hand_rotation_degrees: Vector3 = Vector3(-90.0, 0.0, 0.0)
## Длина оружия в руке, м
@export var weapon_length: float = 0.55
