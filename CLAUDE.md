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
  switch_weapon (Q), interact (E), aim (Z / правая кнопка мыши).
- Impacts — weapons/impacts.gd (class_name ImpactPool): пул CPUParticles3D искр попаданий и пул пятен
  крови spawn_blood() (Blood_1..3, контейнер внутри текущей сцены).
- GameState — autoload/game_state.gd: монеты, купленное оружие, улучшения (damage/magazine/reload),
  рекорды, звёзды и число побед миссий (уровень миссии → сложность x1.15/победу, награда x1.1),
  улучшения игрока (health/armor, player/player_stats.tres), ежедневная награда (серия до 7 дней)
  и задания (quests/quest_pool.tres, report_event(&"kill"...)), selected_mission, start_mission(),
  сохранение в user://save.json (атомарно через .tmp), F9 = +1000 монет в debug-сборке.
  Каталог: res://weapons/data/weapon_catalog.tres.
- Settings — autoload/settings.gd: user://settings.cfg (чувствительность, инверсия Y, автоогонь,
  громкость, тени, разрешение 3D, FPS, тряска камеры), set_value(key, value, save), сигнал changed.
  Окно ui/settings_panel.gd (SettingsPanel) — в убежище (кнопка НАСТРОЙКИ) и в меню паузы.
- Music — autoload/music.gd: фоновая и боевая музыка (боевая громче, когда рядом зомби в погоне),
  громкость Settings.music_volume.
- Sfx — autoload/sfx.gd: пулы AudioStreamPlayer/3D, play_2d/play_3d/pick, звуки в audio/game_sounds.tres
  (GameSounds); звуки оружия — поля fire_sound/reload_sound/reload_end_sound в WeaponData.

Слои физики (combat/physics_layers.gd, class PhysicsLayers): WORLD=1, PLAYER=2, ENEMY=3 (бит 4),
HITBOX=4 (бит 8), SHOT_MASK = WORLD|HITBOX. Скрипты сами выставляют свои слои в _ready.

Ключевые скрипты:
- player/player.gd (Player, CharacterBody3D): движение, обзор свайпом, отдача, aim assist,
  защита от падения за карту (ниже fall_limit_y — возврат на последнюю точку на полу),
  группа "player", поля touch_controls, weapon_manager, health, input_enabled.
- ui/touch/: touch_controls.gd (TouchControls, мультитач по индексам пальцев),
  virtual_joystick.gd (class_name TouchJoystick — встроенный VirtualJoystick в 4.7 занимает имя),
  touch_action_button.gd (TouchActionButton: поля action, label; 3D-стиль: тень, боковина, блик,
  вдавливание; цвет по действию ACTION_COLORS; show_aim_state подсвечивает кнопку прицела).
  В уровнях кнопки FIRE, JUMP, R, ⇄ и AimButton (action "aim", «ПРИЦЕЛ»). Кнопки меню UIKit —
  объёмные StyleBoxFlat (UIKit.apply_3d_style).
- weapons/: weapon_data.gd (WeaponData + группа Shop: id, price, улучшения, make_upgraded()),
  weapon_catalog.gd (WeaponCatalog), weapon_manager.gd (WeaponManager: стволы из GameState.get_loadout()).
- combat/: health.gd (Health), hitbox.gd (Hitbox), target_dummy.gd, target_dummy.tscn (тест).
- enemies/: zombie_data.gd (ZombieData), zombie.gd (Zombie: WANDER/CHASE/SEARCH/ATTACK/STAGGER/DEAD,
  видимость, слух выстрелов и бега, зов стаи, окружение по золотому углу, упреждение, очередь атак
  (MAX_ATTACKERS=3, остальные кружат на кольце), заход со спины и зигзаг (бегун), обыск точек вокруг
  последней позиции игрока (параметры — группа Tactics в ZombieData), notify_target(), анимации
  Idle/Walk/Run/Punch/HitReact/Death через AnimationPlayer внутри Visual).
- missions/: mission_data.gd (MissionData: WAVES/KILL_COUNT/SURVIVE, id, level_scene),
  spawn_point.gd (ZombieSpawnPoint, группа "zombie_spawn"), zombie_spawner.gd (ZombieSpawner),
  mission_manager.gd (MissionManager: берёт GameState.selected_mission, начисляет монеты).
- ui/: ammo_display.gd, health_display.gd (HealthLabel: рисованная 3D-полоска здоровья — градиент,
  след урона, значок аптечки, мигание при низком HP; сама ставит себя в левый верхний угол),
  crosshair.gd (рисованный динамический прицел: зазор = текущий разброс
  WeaponManager.get_current_spread() с учётом FOV; прицеливание — WeaponManager.set_aiming(),
  зум ads_fov_multiplier, разброс ads_spread_multiplier, расхождение bloom_per_shot в WeaponData), health_display.gd, damage_overlay.gd,
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

Сцены: player/player.tscn, enemies/zombie.tscn, combat/target_dummy.tscn, hub/hub.tscn,
levels/test_level.tscn, levels/street_level.tscn (улица, 60×60), levels/yard_level.tscn (стоянка
контейнеров, 56×56). В уровнях: NavigationRegion3D со скриптом levels/runtime_nav_region.gd (навмеш
строится при запуске по коллизиям WORLD — «Bake» в редакторе не нужен), Bounds (невидимые стены),
SpawnPoints, DefendPoint (missions/defend_point.gd), ItemPoints (missions/item_spawn_point.gd),
MissionManager+ZombieSpawner, HUD.

Инвентарь: items/item_data.gd (ItemData: medkit.tres, ammo_pack.tres), GameState.add_item/use_item/buy_item,
ненужный подбор кладётся в сумку; окно ui/inventory_panel.gd; «ПРИПАСЫ В СУМКУ» в оружейной.
Меню уровня ui/game_menus.gd (GameMenus в HUD всех уровней): кнопки «II» и «СУМКА», пауза
(продолжить, сумка, настройки, заново, в убежище — MissionManager.leave_mission() сохраняет монеты).
Режимы миссий ENDLESS (волны без конца, рекорд волн, босс каждые boss_every_waves) и FREE_ROAM
(открытый мир без цели). ZombieSpawner.dynamic_spawn — спавн на навмеше вокруг игрока, despawn далёких.
Машины: vehicles/drivable_car.gd (DrivableCar, аркадная езда, бампер сбивает зомби —
Zombie.hit_by_vehicle), vehicles/drive_controller.gd (кнопка СЕСТЬ/ВЫЙТИ, E, спидометр).
Город: levels/city_level.tscn, levels/city/city_generator.gd + city_config.tres (CityConfig): кварталы,
дороги и здания Kenney City Kit (models/city/commercial, suburban — у каждого своя Textures/colormap.png)
через MultiMesh, коробки коллизий в одном StaticBody, навмеш cell_size 0.5.

Расширение (код): типы зомби crawler/spitter/exploder/dog (ZombieData.behavior, anim_*, hitbox_lying,
tint, specials в MissionData), effects/explosion.gd, effects/thrown_item.gd (граната/коктейль, кнопка
ГРАНАТА и G), effects/fire_area.gd, огнемёт (WeaponData.is_flamethrower), лом и крафт (ItemData.craft_cost),
база base/*.tres (BuildingData, окно ui/hub/base_panel.gd, hub/base_visuals.gd), гараж (таран, двигатель),
стрельба из машины и фары, levels/day_night_cycle.gd (DayNightCycle.night_amount), levels/weather.gd,
город: LootSpot, Survivor, EvacPoint; игрок: выносливость, бег, подкат (sprint/slide);
события дня (DailyEventData в quest_pool.tres); музыка autoload/music.gd (Music, динамическая боевая).
Выбор миссий: терминал МИССИИ открывает ui/hub/mission_select.gd (MissionSelect, «КАРТА ЗАРАЖЕНИЯ»):
3D-фон ui/hub/mission_map_3d.gd (маяки миссий по кругу, камера облетает выбранную), список с
MissionIcon, досье (тип, локация, цель, враги, DangerMeter, награда, рекорд, звёзды, «В БОЙ»),
полосы ui/hazard_stripe.gd. Огнемёт — своя модель weapons/models/flamethrower.tscn (примитивы).

Этап 6 (код): вью-модель уменьшена в VIEW_MODEL_SHRINK=0.35 раз и придвинута к камере (не входит
в стены; камера near=0.02), спрайт вспышки; хитмаркер (ui/hit_marker.gd), индикатор урона
(ui/damage_indicator.gd, создаёт DamageOverlay); подборы pickups/pickup.gd (AMMO/HEALTH/MISSION_ITEM,
дропы из зомби по шансам MissionData); босс enemies/boss.tres (ZombieData.is_boss, рывок charge_*,
удар slam_*), полоска босса в MissionHUD; хитбоксы растут по высоте кости Head скелета модели
(эталон Zombie_Basic: 1.216 м), хитбокс головы следует за костью Head в анимации; типы миссий DEFEND и COLLECT;
звёзды (победа, здоровье ≥ star_health, точность ≥ star_accuracy); оружие smg.tres и axe.tres
(WeaponData.is_melee — веер лучей, замах модели); окно «ЕЖЕДНЕВНО» (ui/hub/daily_panel.gd);
карточка «ВЫЖИВШИЙ» в оружейной. Анимации: покачивание оружия при дыхании/ходьбе и наклон
при перезарядке (WeaponManager._animate_model), звёзды ui/star_rating.gd (StarRating, play()),
3D-превью оружия в оружейной ui/weapon_preview.gd (SubViewport с own_world_3d), «впрыгивающие»
объявления и окно итогов, счёт монет.

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
- Room: пол CSGBox3D 16×0.5×16 (y = -0.25, use_collision); стены — невидимые коллизии Room/Bounds
  (StaticBody3D, 4 бокса высотой 4 по краям ±8); OutsideGround — земля вокруг без коллизии.
- Perimeter: видимая ограда из контейнеров Quaternius снаружи коллизий, ворота — бронированный грузовик.
  Props: машина, бочки, ящики, фонари и т.п. (StaticProp); Props/Outside: башня, знак, дорога.
- Player: экземпляр player/player.tscn в (0, 0.1, 4), touch_controls → HUD/TouchControls.
- MissionTerminal (Interactable) в (-4, 0, -5): prompt «МИССИИ», action_id &"missions";
  дети: CollisionShape3D BoxShape3D 3×2×3 (y = 1), стол CSGBox3D 2×1×1 (y = 0.5, use_collision),
  Hologram (hub/hologram.gd: вращающийся полупрозрачный Zombie_Basic с анимацией Idle, y = 1.3),
  Label3D «МИССИИ» (font_size 64, outline 16, pixel_size 0.004, billboard, y = 2.7).
- ShopTerminal (Interactable) в (4, 0, -5): prompt «ОРУЖЕЙНАЯ», action_id &"shop", такие же дети,
  Hologram с моделью Rifle (y = 1.75), Label3D «ОРУЖЕЙНАЯ».
- HUD (CanvasLayer): TouchControls (скрипт touch_controls.gd, Full Rect, поле joystick → Joystick)
  с детьми Joystick (TouchJoystick, якоря 0,0,0.4,1, отступы 0) и JumpButton (TouchActionButton,
  action "jump", label "JUMP", якоря все 1, отступы -370,-170,-260,-60); последним ребёнком HUD —
  HubHUD (Control, скрипт ui/hub/hub_hud.gd, missions = [mission_waves, mission_kill, mission_survive]).
- project.godot: run/main_scene = boot/boot.tscn (экран загрузки: ui/splash/splash.png или 3D-зомби,
  3D-полоса boot/loading_bar_3d.gd, фоновая загрузка hub/hub.tscn). Промпт картинки — ui/splash/PROMPT.md.
- Иконка: res://icon.png (1024, углы залиты фоном, оригинал icons/icon_source.png); для экспорта Android —
  icons/icon_192.png, adaptive_foreground_432.png, adaptive_background_432.png (прописаны в export_presets.cfg,
  пресет «Android»: arm64, com.salamanderlab.deadzone, разрешения сети). Заставка Godot выключена.
  import_etc2_astc=true — сжатие текстур для Android (не GPU-сжатие, правило выше не нарушает).

## Статус и план
Готово: этапы 1–4 и код этапа 5 (GameState, магазин, доска миссий, HUD убежища).
Осталось по этапу 5: hub.tscn, проверка магазина и сохранений на устройстве.

Этап 6 — сделан в коде, нужна проверка в Godot: подбор view-модели топора и SMG, громкость звуков,
разметка звуков зомби (audio/game_sounds.tres), баланс босса и миссий.

Этап 7 — AdMob: rewarded (воскрешение, x2 монеты), баннер только в убежище, плагин, совместимый
с Godot 4.7, согласие UMP/GDPR.

Этап 8 — релиз: сплэш SalamanderLab; настройки (чувствительность, инверсия Y, автоогонь,
громкость, ссылки Telegram https://t.me/SalamanderLab и Instagram
https://www.instagram.com/salamandersec/); откат на OpenGL для Android без Vulkan; экспорт AAB,
подпись keystore, Play Console.

Этап 6, сделано: ассеты (models/environment, models/vehicles, audio/, CREDITS.md);
levels/static_prop.gd (StaticProp: StaticBody3D с моделью-ребёнком, коробка коллизии по мешам,
custom_size для фонарей/светофоров); props в hub.tscn и test_level.tscn (дороги, машины, контейнеры,
пятна крови в Decals); ZombieData.model_scene/model_scale — runner = Zombie_Arm, tank = Zombie_Chubby 1.9.

Кат-сцены (cutscene/): CutsceneData (id, shots, time_scale, once) из CutsceneShot (from/to, look_from/look_to,
duration, subtitle, relative_to WORLD/ANCHOR); CutscenePlayer.play(tree, data, anchor) — своя камера, чёрные
полосы, субтитры, «ПРОПУСТИТЬ», HUD скрыт, ввод игрока выключен; is_blocking_input() глушит паузу.
hub_intro.tres — вступление в убежище (hub/hub.gd), интро миссии и замедленное появление босса строятся кодом
в MissionManager (по разу; флаги GameState.has_seen_cutscene, сброс в настройках, Settings.cutscenes).

Управление (настройки): ui/touch/control_layout.gd (ControlLayout: стандартные места кнопок DEFAULTS —
держать в синхроне со сценами уровней, GameMenus и DriveController; apply_to_button/apply_to_joystick),
редактор раскладки ui/touch/control_layout_editor.gd (перетаскивание, ЗЕРКАЛО, СБРОС; Settings.button_layout —
центры в долях экрана, joystick_right). Settings: button_style (3D/ПЛОСКИЕ/КОНТУР), button_scale,
button_opacity, crosshair_scale, crosshair_color, гироскоп gyro_* (режим ВСЕГДА/В ПРИЦЕЛЕ, чувствительность X/Y,
инверсия, сглаживание, частота опроса gyro_rate Гц; Player._process_gyro; project.godot
input_devices/sensors/enable_gyroscope=true). Зомби: обход стен (_steer_around_wall), шаг на бордюры
(STEP_HEIGHT), выход из застревания по шагам и перенос на навмеш (_snap_to_navmesh).

Вид от 3-го лица: Settings.camera_mode (кнопка «ВИД» / V), Player: SpringArm3D «CameraArm» за плечом,
тело PlayerBody (player/player_body.gd: скин, анимации, оружие на BoneAttachment3D, вспышка), скины
PlayerSkin (player/skins/*.tres, GameState.SKIN_PATHS, покупка/выбор — окно ПЕРСОНАЖ ui/hub/skin_panel.gd).
Player.set_weapons_enabled() — убежище. Модели Kenney: models/characters/kenney (скины), models/graveyard
(скелет, гниляк — enemies/skeleton.tres, ghoul.tres; уровень levels/graveyard_level.tscn строит
levels/graveyard/graveyard_builder.gd через levels/prop_batch.gd), models/survival (лагерь hub/hub_camp.gd).
Оружие ближнего боя: knife, bat, saw_bat, spear (модели Quaternius).
Мультиплеер (ENet, Wi-Fi/точка доступа, до 4): автозагрузка Net (autoload/net.gd: лобби, поиск игр UDP 24681,
игра на порту 24680, join_hotspot — шлюз x.x.x.1, все RPC), окно ui/hub/lobby_panel.gd (кнопка «ПО СЕТИ»).
В матче MissionManager отключается и создаёт net/match_manager.gd (MatchManager): копии игроков —
player.tscn с is_remote (без WeaponManager, группа remote_player, PvP-хитбоксы врагам), состояние 20/с;
зомби ведёт хост (Zombie.multi_target — ближайший игрок), клиенты — копии Zombie.net_puppet;
урон уходит владельцу (Hitbox.applying — признак выстрела). Режимы Net.Mode: COOP_SCORE, FREE_FOR_ALL,
TEAMS, LAST_STANDING (AUTO по числу игроков). Интерфейс ui/match_hud.gd. Для Android в экспорте нужны
разрешения INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE.

Реклама (этап 7): плагин Poing Studios AdMob 5.1.0 (стабильная; у 5.2 нет Android-библиотек) в addons/admob (включён в editor_plugins; Android-бинарники
скачивает сам при включении → addons/admob/android/bin, в .gitignore). Нужна сборка Gradle (export_presets:
use_gradle_build=true, Project → Install Android Build Template, папка android/ в .gitignore).
App ID ca-app-pub-5010684167263731~1270406484 — project.godot [admob] general/android/app_id. Автозагрузка Ads (autoload/ads.gd): UMP-согласие,
баннер вверху только в убежище (HubHUD, меню сдвинуто на BANNER_RESERVE), межстраничная после миссии
(Ads.after_mission: каждая 2-я, не чаще 120 с), с наградой — воскрешение (MissionManager.revive_offered/revive)
и x2 монеты на экране итогов. В debug-сборке тестовые блоки Google. GameMenus не ставит паузу во время рекламы.
Прокрутка окон пальцем: ui/touch_scroll.gd (TouchScroll.attach(scroll), кнопка под свайпом отключается).

Сюжет: story/campaign.tres (CampaignData: пролог, эпилог, 7 глав ChapterData — место на карте, миссия
missions/data/story_1..7.tres, тексты до/после, награды: люди, дом, машина). GameState: _chapters_done,
get_campaign_progress (процент), get_rescued_count, get_house_count, get_owned_cars, pop_pending_story
(концовка главы показывается в убежище). Окно «СЮЖЕТ» ui/hub/campaign_panel.gd: карта ui/hub/campaign_map.gd,
лагерь в 3D ui/hub/camp_diorama_3d.gd, рассказы ui/hub/story_panel.gd (StoryPanel.open). Люди у костра в
убежище — hub/hub_camp.gd; своя машина — первая у старта в городе (city_generator).
Новые локации: levels/forest_level.tscn (ForestBuilder), levels/industrial_level.tscn (IndustrialBuilder) —
база levels/location_builder.gd (LocationBuilder: PropBatch, свободные места, видимая ограда, туман, земля
за краем); стены Bounds ±28 из шаблона уровня. Модели промзоны: models/industrial (Kenney).
Факел: items/torch.tres (GearData, items/gear_data.gd), GameState.gear/owns_gear/buy_gear, карточка
«СНАРЯЖЕНИЕ» в оружейной, player/torch.gd (Torch на Head), кнопка «ФАКЕЛ» / T.
Оружие по умолчанию: нож (бесплатно, первый в каталоге), пистолет (бесплатно, второй), остальное — покупка.

Настройки по вкладкам (ui/settings_panel.gd: колонка вкладок слева, SettingsPanel._tab запоминается).
Эффекты урона: Health.take_damage_from(amount, pos, head, Health.Kind, source_name, source) — тип урона
(MELEE/BULLET/EXPLOSION/FIRE/ACID) и источник; ui/damage_indicator.gd — свечение края, дуга, шеврон, значок,
имя стрелявшего, стрелка следит за атакующим; Player — толчок камеры (camera.rotation, _hit_roll/_hit_pitch).
Settings: damage_direction, damage_flash, hit_shake, attacker_marker (вкладка ЭФФЕКТЫ).
Сеть: карта матча грузится в фоне (Net._load_map, экран ЗАГРУЗКА КАРТЫ, снимает MatchManager), ENet timeout
30–60 с, Net.pending_go/loaded не теряются, опоздавшему досылаются зомби; метка ▼ над тем, кто стреляет
(MatchManager._mark_attacker), MatchHUD.show_attacker, кнопка В УБЕЖИЩЕ при долгом ожидании.
TouchControls.input_blocked — меню по сети блокирует касания. HubWindow.refresh() — отложенный, раз за кадр.
Ads: реклама грузится только после колбэка MobileAds.initialize (иначе краш на Android); hide_banner уничтожает AdView.

Взрывные бочки: effects/explosive_barrel.gd (ExplosiveBarrel — компонент StaticProp: Health, Hitbox flesh=false,
auto_target=false, шипение, Explosion + FireArea, цепная реакция через группу explosive_barrel, по сети
Net.rpc_barrel_explode по пути узла). StaticProp с Barrel.gltf взрывной сам (не в убежище), ExplosiveBarrel.spawn —
в городе, промзоне, лесу. Explosion.damage_zombies=false у клиента по сети.
Факел: Settings.torch_auto — Player._update_auto_torch зажигает ночью (DayNightCycle.night_amount ≥ 0.5),
гасит ≤ 0.3; превью ui/torch_preview.gd в оружейной.
Стройки в убежище нет (была и убрана по просьбе): в старых сохранениях ключ "blocks" игнорируется.

Озвучка: ui/voice_over.gd (VoiceOver — синтез речи устройства DisplayServer TTS, язык ru/en по
OS.get_locale_language и наличию голоса; project.godot audio/general/text_to_speech=true). CutsceneShot.voice_ru/
voice_en — смешные реплики рассказчика (hub_intro.tres; интро миссии и босс — случайные из
cutscene/voice_lines.tres, VoiceLines), текст реплики сверху, план ждёт конца фразы. Settings: voice_cutscenes,
voice_camp, voice_volume (вкладка СЮЖЕТ).
Разговоры у костра: hub/hub_camp.gd — у костра минимум 2 человека, диалоги hub/camp_chatter.tres (CampChatter:
ru/en, по очереди двух людей, solo для одного), Label3D над головой, поворот друг к другу, голос со своим тоном
(VOICE_PITCHES), если игрок ближе 6 м.

Хедшот: enemies/head_pop_modifier.gd (HeadPopModifier — SkeletonModifier3D сжимает кость Head), Zombie._headshot_death
(кровь из шеи на BoneAttachment3D Neck, брызги, откидывание), ui/headshot_popup.gd (череп, ХЕДШОТ ×N, миг
замедления — Settings.headshot_slowmo, не по сети). AWM: weapons/data/awm.tres (Rifle.gltf, WeaponData.has_scope,
bolt_sound), ui/scope_overlay.gd (оптика на весь экран; WeaponManager.is_scoped прячет модель и прицел).
Crosshair кладёт ХЕДШОТ и оптику в CanvasLayer HUD (прицел лежит в CenterContainer).
Город по сети: Net.MAPS + city_level («ГОРОД»), CityGenerator по сети ставит Marker3D группы mp_spawn (дворы)
вместо выживших/эвакуации, MatchManager берёт mp_spawn раньше item_spawn, ZombieSpawner в открытом мире
спавнит вокруг случайного игрока и убирает зомби далеко от всех, DriveController по сети выключен.

Бэклог: звуки взмаха топора и шагов по разным поверхностям, иконки звёзд вместо текста.
