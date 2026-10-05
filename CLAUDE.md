# Dead Zone — мобильный зомби-FPS на Godot

## Цель
Мобильный FPS в стиле Dead Trigger 2 для Google Play. Студия: SalamanderLab.
Цикл игры: убежище (3D-хаб) → миссия → монеты → покупка и улучшение оружия → следующая миссия.

## Окружение (критично, не нарушать)
- Godot 4.7.2 stable, только GDScript.
- Разработка на macOS, MacBook Pro с Intel Iris Graphics 6100. Эта видеокарта НЕ поддерживает
  RenderingDevice (Vulkan/Metal падают с "Placement heap type is not supported").
- В project.godot обязательно и не менять:
  - renderer/rendering_method="gl_compatibility" (редактор и ПК)
  - textures/vram_compression/compress_with_gpu=false (иначе импорт текстур крашит редактор)
- renderer/rendering_method.mobile в project.godot не добавлять: "mobile" (Android) — значение
  по умолчанию, Godot его не сохраняет.
- Ничего, что требует RenderingDevice в редакторе: GPU-сжатие, compute shaders, SDFGI, VoxelGI.
- Работа в облаке (Claude Code on the web): Godot недоступен. Проверяй код особенно тщательно
  (типы, имена нод, пути ресурсов, uid в .tscn/.tres). В конце каждой задачи давай чек-лист
  проверки в редакторе. Ошибки из Godot я присылаю текстом.
- Локально (если когда-то будет CLI на Маке): Godot находится через
  mdfind "kMDItemCFBundleIdentifier == 'org.godotengine.godot'", проверка:
  "$GODOT" --headless --path . --import и "$GODOT" --headless --path . --quit-after 300.
- Цель: Android, альбомная ориентация, тач-управление, слабые телефоны (30–60 FPS).

## Архитектура (уже сделано)
Автозагрузки:
- InputSetup — autoload/input_setup.gd: действия move_*, jump, fire (F/Ctrl), reload (R),
  switch_weapon (Q), interact (E).
- Impacts — weapons/impacts.gd (class_name ImpactPool): пул CPUParticles3D искр попаданий.
- GameState — autoload/game_state.gd: монеты, купленное оружие, улучшения (damage/magazine/reload),
  рекорды миссий, selected_mission, start_mission(), сохранение в user://save.json
  (атомарно через .tmp), F9 = +1000 монет в debug-сборке. Каталог: res://weapons/data/weapon_catalog.tres.

Слои физики (combat/physics_layers.gd, class PhysicsLayers): WORLD=1, PLAYER=2, ENEMY=3 (бит 4),
HITBOX=4 (бит 8), SHOT_MASK = WORLD|HITBOX. Скрипты сами выставляют свои слои в _ready.

Ключевые скрипты:
- player/player.gd (Player, CharacterBody3D): движение, обзор свайпом, отдача, aim assist,
  группа "player", поля touch_controls, weapon_manager, health, input_enabled.
- ui/touch/: touch_controls.gd (TouchControls, мультитач по индексам пальцев),
  virtual_joystick.gd (class_name TouchJoystick — встроенный VirtualJoystick в 4.7 занимает имя),
  touch_action_button.gd (TouchActionButton: поля action, label).
- weapons/: weapon_data.gd (WeaponData + группа Shop: id, price, улучшения, make_upgraded()),
  weapon_catalog.gd (WeaponCatalog), weapon_manager.gd (WeaponManager: стволы из GameState.get_loadout()).
- combat/: health.gd (Health), hitbox.gd (Hitbox), target_dummy.gd, target_dummy.tscn (тест).
- enemies/: zombie_data.gd (ZombieData), zombie.gd (Zombie: WANDER/CHASE/SEARCH/ATTACK/STAGGER/DEAD,
  видимость, слух, зов стаи, окружение, упреждение, notify_target(), анимации
  Idle/Walk/Run/Punch/HitReact/Death через AnimationPlayer внутри Visual).
- missions/: mission_data.gd (MissionData: WAVES/KILL_COUNT/SURVIVE, id, level_scene),
  spawn_point.gd (ZombieSpawnPoint, группа "zombie_spawn"), zombie_spawner.gd (ZombieSpawner),
  mission_manager.gd (MissionManager: берёт GameState.selected_mission, начисляет монеты).
- ui/: ammo_display.gd, crosshair.gd, health_display.gd, damage_overlay.gd,
  mission_hud.gd (UI миссии создаётся кодом; кнопка «В УБЕЖИЩЕ» появляется, если есть res://hub/hub.tscn),
  ui_kit.gd (UIKit), ui/hub/: hub_window.gd (HubWindow), shop_panel.gd (ShopPanel),
  mission_board_panel.gd (MissionBoardPanel), hub_hud.gd (HubHUD: поле missions: Array[MissionData]).
- hub/interactable.gd (Interactable, Area3D: поля prompt, action_id "missions"/"shop";
  сам ставит collision_layer=0, collision_mask=PLAYER).

Ресурсы:
- weapons/data/: pistol.tres, shotgun.tres, rifle.tres (вью-модели подогнаны вручную, НЕ менять
  model_position/model_rotation_degrees/model_scale/muzzle_position), weapon_catalog.tres.
- enemies/: walker.tres, runner.tres, tank.tres.
- missions/data/: mission_waves.tres, mission_kill.tres, mission_survive.tres.
- models/zombies/ и models/weapons/: Quaternius Zombie Apocalypse Kit (CC0, glTF).
  Модель зомби в zombie.tscn: Visual/Model = Zombie_Basic.gltf, scale 1.6, rotation y 180.
  Модель типа задаётся в ZombieData (model_scene, model_scale) и подменяет Visual/Model при спавне:
  walker — Zombie_Basic (из сцены), runner — Zombie_Arm, tank — Zombie_Chubby (1.9).
  Хитбоксы масштабируются как model_scale / 1.6. Idle/Walk/Run зацикливаются в коде.

Сцены: player/player.tscn, enemies/zombie.tscn, combat/target_dummy.tscn,
levels/test_level.tscn (навмеш, 6 точек спавна, MissionManager+ZombieSpawner, HUD), hub/hub.tscn.

## Правила кода
- Статическая типизация везде, комментарии и тексты на русском, UI-надписи ЗАГЛАВНЫМИ.
- Production-ready: проверки null, push_warning/push_error с именем ноды, безопасные fallback.
- Данные — в Resource (.tres), логика — в скриптах.
- UI создавать кодом через UIKit (мне тяжело настраивать якоря вручную). Кнопки не ниже 72 px.
- Мобильная производительность: без аллокаций в каждом кадре, пулы, лимит живых зомби.
- Правка .tscn вручную: сохранять ext_resource uid и id, uid брать из .uid-файлов и заголовков.
  Если формат сцены сомнителен — дать мне пошаговую инструкцию для редактора.
- Не ломать настроенное: имена анимаций, вью-модели, автозагрузки, настройки рендера.

## Как работать со мной
- Отвечай по-русски, кратко, без вступлений.
- Перед задачей: план по шагам и список файлов. Если не хватает данных — спроси.
- Коммиты небольшие, с понятными сообщениями.
- В конце: что сделано и чек-лист, что мне проверить в Godot.

## Этап 5 — убежище (hub/hub.tscn)
- Корень Hub (Node3D, скрипт hub/hub.gd): в _ready через call_deferred находит игрока по группе
  "player" и отключает оружие: weapon_manager.process_mode = PROCESS_MODE_DISABLED, visible = false.
- Свет и небо: WorldEnvironment (ProceduralSky) + DirectionalLight3D с тенями. Потолок не нужен
  (открытый двор убежища), чтобы не было темно на Compatibility.
- Комната из CSGBox3D с use_collision = true: пол 16×0.5×16 (y = -0.25), четыре стены высотой 4
  и толщиной 0.4 по краям (±8).
- Player: экземпляр player/player.tscn в (0, 0.1, 4), touch_controls → HUD/TouchControls.
- MissionTerminal (Interactable) в (-4, 0, -5): prompt «МИССИИ», action_id &"missions";
  дети: CollisionShape3D BoxShape3D 3×2×3 (y = 1), стол CSGBox3D 2×1×1 (y = 0.5, use_collision),
  Label3D «МИССИИ» (font_size 96, billboard enabled, y = 2.2).
- ShopTerminal (Interactable) в (4, 0, -5): prompt «ОРУЖЕЙНАЯ», action_id &"shop", такие же дети,
  Label3D «ОРУЖЕЙНАЯ».
- HUD (CanvasLayer): TouchControls (скрипт touch_controls.gd, Full Rect, поле joystick → Joystick)
  с детьми Joystick (TouchJoystick, якоря 0,0,0.4,1, отступы 0) и JumpButton (TouchActionButton,
  action "jump", label "JUMP", якоря все 1, отступы -370,-170,-260,-60); последним ребёнком HUD —
  HubHUD (Control, скрипт ui/hub/hub_hud.gd, missions = [mission_waves, mission_kill, mission_survive]).
- project.godot: run/main_scene = hub/hub.tscn.

## Статус и план
Готово: этапы 1–4 и код этапа 5 (GameState, магазин, доска миссий, HUD убежища).
Осталось по этапу 5: hub.tscn, проверка магазина и сохранений на устройстве.

Этап 6 — контент: 2–3 карты из окружения Quaternius с навмешем и точками спавна; свои модели
для типов (Zombie_Basic — обычный, Zombie_Ribcage или Zombie_Arm — бегун, Zombie_Chubby — танк);
босс-зомби; новые типы миссий (защита точки, сбор предметов); подборы патронов и аптечек;
звуки (CC0); пятна крови.

Этап 7 — AdMob: rewarded (воскрешение, x2 монеты), баннер только в убежище, плагин, совместимый
с Godot 4.7, согласие UMP/GDPR.

Этап 8 — релиз: сплэш SalamanderLab; настройки (чувствительность, инверсия Y, автоогонь,
громкость, ссылки Telegram https://t.me/SalamanderLab и Instagram
https://www.instagram.com/salamandersec/); откат на OpenGL для Android без Vulkan; экспорт AAB,
подпись keystore, Play Console.

Бэклог: оружие не проваливается в стены (отдельный слой/камера вью-модели), спрайт вспышки,
звук хитмаркера, индикатор направления урона.
