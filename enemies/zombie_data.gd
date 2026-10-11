class_name ZombieData
extends Resource
## Параметры типа зомби. Каждый тип — отдельный .tres файл.

## MELEE — бьёт вблизи; RANGED — плюётся кислотой издалека; EXPLODER — взрывается рядом с игроком;
## GUNNER — человек с оружием (бандит): стреляет очередями, держит дистанцию, вблизи бьёт кулаком;
## SCREAMER — крикун: держится поодаль и кричит (ускоряет зомби вокруг, зовёт подмогу)
enum Behavior { MELEE, RANGED, EXPLODER, GUNNER, SCREAMER }

@export var display_name: String = "WALKER"
@export var behavior: Behavior = Behavior.MELEE

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 1.6
@export var turn_speed: float = 8.0
## Случайный разброс скорости у каждого зомби (0.15 = ±15%)
@export_range(0.0, 0.5, 0.01) var speed_variation: float = 0.15

@export_group("Attack")
@export var attack_damage: float = 10.0
## Дистанция начала атаки (по горизонтали), метры
@export var attack_range: float = 1.4
## Время замаха до удара, сек (окно, чтобы увернуться)
@export var attack_windup: float = 0.5
## Пауза после удара, сек
@export var attack_cooldown: float = 0.8

@export_group("Senses")
## Видит игрока на этом расстоянии (при прямой видимости)
@export var detection_radius: float = 15.0
## Чует игрока вплотную даже без видимости
@export var close_sense_radius: float = 3.0
## Слышит выстрелы на этом расстоянии
@export var hearing_radius: float = 30.0
## Заметив игрока, зовёт других зомби в этом радиусе (0 = не зовёт)
@export var alert_radius: float = 10.0
## Через сколько секунд без видимости сдаётся и уходит бродить
@export var lose_interest_time: float = 6.0

@export_group("Behavior")
## Радиус блуждания вокруг точки появления (0 = стоит на месте)
@export var wander_radius: float = 6.0
## Скорость блуждания относительно move_speed
@export_range(0.1, 1.0, 0.05) var wander_speed_factor: float = 0.4
## Упреждение: бежит туда, где игрок будет через столько секунд
@export_range(0.0, 1.0, 0.05) var prediction_time: float = 0.3
## Длительность вздрагивания от попадания (0 = не вздрагивает)
@export_range(0.0, 1.0, 0.05) var stagger_time: float = 0.3

@export_group("Visual")
## Цвет капсулы-заглушки. На реальную модель не влияет
@export var body_color: Color = Color(0.35, 0.5, 0.3)
## Своя модель типа (glTF с анимациями Idle/Walk/Run/Punch/HitReact/Death).
## Пусто — остаётся модель из zombie.tscn (Visual/Model)
@export var model_scene: PackedScene
## Масштаб своей модели (модель зомби в zombie.tscn — 1.6)
@export var model_scale: float = 1.6

@export_group("Animations")
## Свои имена анимаций модели (пусто — как в zombie.tscn: Idle/Walk/Run/Punch/HitReact/Death)
@export var anim_idle: StringName = &""
@export var anim_walk: StringName = &""
@export var anim_run: StringName = &""
@export var anim_attack: StringName = &""
@export var anim_hit: StringName = &""
@export var anim_death: StringName = &""
## Хитбокс тела лежит вдоль земли (ползун, собака)
@export var hitbox_lying: bool = false
## Постоянный оттенок модели (альфа — сила), например зелёный у взрывного
@export var tint: Color = Color(0, 0, 0, 0)

@export_group("Ranged")
@export var ranged_min_distance: float = 6.0
@export var ranged_max_distance: float = 18.0
@export var ranged_cooldown: float = 2.8
@export var ranged_windup: float = 0.6
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 14.0

@export_group("Gunner")
## Человек, а не зомби: не стонет, кричит фразы (taunts) над головой
@export var human: bool = false
## Встроенный ствол модели Quaternius Characters_* (Pistol, Shotgun, SMG, Rifle); остальные прячутся
@export var held_weapon: String = "Pistol"
## Анимация стрельбы (прицеливание) — отдельно от удара кулаком anim_attack
@export var anim_shoot: StringName = &"Idle_Gun"
@export_range(1, 12) var burst_shots: int = 3
@export var shot_interval: float = 0.15
@export var shot_damage: float = 6.0
## Попадание на ближней дистанции; дальше и по бегущему — хуже
@export_range(0.05, 1.0, 0.05) var accuracy: float = 0.6
## Держится на такой дистанции от цели (ходит боком), метры
@export var preferred_distance: float = 9.0
@export var gun_sound: AudioStream
## Крики бандитов над головой (язык — как в телефоне)
@export var taunts_ru: PackedStringArray = []
@export var taunts_en: PackedStringArray = []

@export_group("Exploder")
## На этой дистанции до игрока поджигает фитиль
@export var explode_trigger_distance: float = 2.2
@export var explode_fuse: float = 0.7
@export var explode_radius: float = 4.5
@export var explode_damage: float = 45.0
## Взрывается и при смерти от выстрела (задевает соседей)
@export var explode_on_death: bool = true

@export_group("Armor")
## Каска: столько урона по голове принимает на себя, потом слетает (0 — каски нет)
@export var helmet_health: float = 0.0
@export var helmet_color: Color = Color(0.32, 0.38, 0.24)
## Урон по голове в каске проходит такой долей (оглушает, но не убивает)
@export_range(0.0, 1.0, 0.05) var helmet_pass: float = 0.15
## Броня спереди: урон по телу спереди умножается на это (1 — брони нет); сзади и в голову — полный
@export_range(0.05, 1.0, 0.05) var front_armor: float = 1.0
@export var armor_color: Color = Color(0.35, 0.36, 0.38)

@export_group("Screamer")
## Крик: зомби в радиусе бегут к игроку быстрее (scream_boost) scream_boost_time секунд.
## Перезарядка крика — ranged_cooldown, замах — ranged_windup, дистанции — ranged_min/max_distance
@export var scream_radius: float = 18.0
@export var scream_boost: float = 1.4
@export var scream_boost_time: float = 6.0
## Сколько зомби приходит на крик (сверх обычного спавна миссии)
@export_range(0, 6) var scream_reinforcements: int = 2
@export var anim_scream: StringName = &"Wave"

@export_group("Tactics")
## Участвует в очереди атак (не больше MAX_ATTACKERS бьют одновременно, остальные кружат)
@export var uses_attack_queue: bool = true
## Издалека заходит со спины игрока
@export var flank_from_behind: bool = false
## Зигзаг, когда игрок целится в зомби издалека (0 = бежит прямо), метры
@export var zigzag_amplitude: float = 0.0
@export var zigzag_frequency: float = 2.5
## Потеряв игрока, проверяет столько точек вокруг места, где видел его последним
@export_range(0, 8) var search_points: int = 3
@export var search_radius: float = 6.0
## Слышит бегущего игрока на этом расстоянии без прямой видимости (0 = не слышит)
@export var footstep_hearing_radius: float = 7.0

@export_group("Boss")
## Босс: полоска здоровья в HUD, задание «убить босса»
@export var is_boss: bool = false
## Рывок к игроку с дистанции
@export var charge_enabled: bool = false
@export var charge_speed: float = 9.0
@export var charge_min_distance: float = 5.0
@export var charge_max_distance: float = 16.0
## Замах перед рывком (окно, чтобы отскочить), сек
@export var charge_windup: float = 0.7
@export var charge_duration: float = 1.3
@export var charge_cooldown: float = 7.0
@export var charge_damage: float = 30.0
## Удар по площади вблизи (вместо обычного удара, когда готов)
@export var slam_enabled: bool = false
@export var slam_radius: float = 4.0
@export var slam_windup: float = 0.9
@export var slam_cooldown: float = 6.0
@export var slam_damage: float = 30.0
## Сила отбрасывания игрока рывком и ударом, м/с
@export var knockback: float = 9.0

@export_group("Audio")
## Высота голоса: танк ниже, бегун выше
@export_range(0.3, 2.0, 0.05) var voice_pitch: float = 1.0
## Громкость голоса, дБ
@export_range(-30.0, 10.0, 0.5) var voice_volume_db: float = 0.0

@export_group("Reward")
## Очки за убийство (понадобится на этапе 4)
@export var score: int = 10
