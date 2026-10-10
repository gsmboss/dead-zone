# Картинки для Dead Zone — что нужно и промпты

Готово: splash (ui/splash/splash.jpg), обложка Google Play (store/feature_graphic.png), prologue, chapter_1, chapter_2, chapter_3, chapter_4, chapter_bandits, chapter_5, chapter_6, chapter_baron, chapter_7, chapter_pharmacy, chapter_tower, chapter_rat, chapter_bridge, epilogue; локации (ui/hub/locations/*.jpg 960×540): все 8 (loc_street, loc_yard, loc_city, loc_graveyard, loc_forest, loc_industrial, loc_polygon, loc_shelter)

Часть третья (раздел 4) тоже готова: chapter_south, chapter_port, chapter_lighthouse, chapter_voyage, loc_harbor.
Раздел 5 — готовы: chapter_pass, chapter_keys, chapter_shepherd, chapter_home, loc_mountain. Ждут: chapter_siege, chapter_cold, chapter_hospital, chapter_mother, chapter_trail, chapter_crossing, chapter_feast, chapter_depot, chapter_resort.
(story/art/*.jpg — картинка главы фоном рассказа и сверху досье в окне СЮЖЕТ).

Все картинки — **без текста, букв, логотипов и водяных знаков** (надписи игра рисует сама, на двух языках).
Формат — PNG или JPG. Присылай как есть, я сам подрежу, сожму и подключу.

## Общий стиль (добавляй в начало каждого промпта)

```
Low-poly stylized 3D render, chunky simple shapes, flat-shaded polygons, bright saturated palette
like Quaternius / Kenney low poly game assets, cartoon green-skinned zombies, clean readable
silhouettes, cinematic lighting, volumetric fog, mobile game key art, no text, no letters,
no logos, no watermark, no UI, no frame
```

Негативный промпт (если есть поле):
```
text, letters, watermark, logo, signature, UI, frame, border, photorealistic, blurry,
gore close-up, extra limbs, distorted faces, deformed hands
```

---

## 1. ОБЯЗАТЕЛЬНО

### 1.1 Фон экрана загрузки — `splash.png`
Размер 1920×1080 (16:9). Промпт — в `ui/splash/PROMPT.md` (уже готов).

### 1.2 Обложка в Google Play — `feature_graphic.png`
Размер **1024×500** — без неё Google Play не опубликует игру.
```
Wide banner composition 1024x500. Center-left: a lone survivor in a cap and tactical vest with an
assault rifle, three-quarter view, heroic pose, rim light. Right side: a horde of green cartoon
zombies coming out of orange fog — walker, runner, a huge chubby brute in a construction helmet.
Background: ruined city street at sunset, burning car, shipping containers, broken traffic light.
Strong red-orange backlight against dark teal shadows. Leave the left third slightly calmer and
darker for the game title. High contrast, readable at small size.
```

---

## 2. ЖЕЛАТЕЛЬНО — картинки глав сюжета (15 шт.)

Размер **1600×900** (16:9). Будут сверху в окне главы и в рассказах.
Герой — парень лет 20 в кепке, разгрузке и с рюкзаком (как на обложке), брат Тёма — мальчик лет 10.

| Файл | Глава | Промпт (после общего стиля) |
|---|---|---|
| `prologue.png` | Пролог, день ноль | `Peaceful small city at golden hour suddenly in panic: people running down the street, a burning laboratory building "biotech" in the distance with black smoke, police car lights, first zombies emerging from the smoke. A mother holding two boys by the hand runs toward an old bridge in the foreground.` |
| `chapter_1.png` | Первый день | `Container yard by a highway at dusk, stacked rusty shipping containers, a crackling walkie-talkie on a crate in the foreground, a girl and her wounded brother hiding behind a container, zombies approaching between the rows.` |
| `chapter_2.png` | Улица молчания | `Quiet abandoned city street once cozy: an ice cream kiosk, a bicycle repair shop, empty park benches with fallen leaves, faded colors, a few zombies standing still in the middle of the road, eerie silence, pale overcast light.` |
| `chapter_3.png` | Лесной лагерь | `Survivor camp in a pine forest at evening: tents, a campfire with sparks, a guitar leaning on a log, four scouts sitting around the fire, warm firelight against blue forest shadows, zombie silhouettes between the distant trees.` |
| `chapter_4.png` | Ночь на кладбище | `Night cemetery near a small chapel, crooked crosses and gravestones, moonlight through fog, a survivor standing alone at one grave with a flashlight, skeletal zombies rising in the background, cold blue and green palette, touching sad mood.` |
| `chapter_bandits.png` | Стервятники | `Highway convoy of refugee cars and a bus stopped by bandits: armored pickup trucks with spikes, men in leather jackets with red bandanas holding guns, burning barrel, dusty orange evening light, tension.` |
| `chapter_5.png` | Промзона | `Industrial zone with a small gas station held by five workers in orange vests, fuel tanks, pipes, cranes, chimneys, a chain-link fence, a bandit warehouse behind the fence, zombies at the gates, hazy yellow light.` |
| `chapter_6.png` | Эвакуация | `City center plaza with a dry fountain in the middle, an old cinema building, a shawarma kiosk, survivors running toward a rescue truck with a red cross flag, a horde of zombies flooding in from the avenues, dramatic sunset.` |
| `chapter_baron.png` | Логово Барона | `A big old Soviet-style department store at night turned into a bandit fortress: barricades of cars, sandbags, spotlights, a broken neon sign glowing red, a fat bandit boss in a fur coat and gold chain on the balcony, bodyguards below.` |
| `chapter_7.png` | Источник | `Inside a ruined genetics laboratory complex: glass tanks with glowing green liquid, broken pipes, a pulsing organic zombie nest covering the walls, eerie green glow, a survivor with a rifle and a flamethrower stepping in.` |
| `chapter_pharmacy.png` | Рецепт вакцины | `Pharmacy warehouse with shelves of medicine boxes, a female doctor in a white coat holding a vial with glowing blue vaccine, a microscope and an old coffee machine on a table, survivors guarding the door, zombies scratching at the glass.` |
| `chapter_tower.png` | Голоса с юга | `Wooden radio tower on a forested hill at dawn, an old man with headphones and a radio at the top, antenna wires, survivors defending the base of the tower against a horde, distant sea and port visible on the horizon.` |
| `chapter_rat.png` | Крыса | `Container yard at night, a skinny bearded man in glasses running away with a silver briefcase, a red sports car with its headlights on, bandits with flashlights searching between containers, comic chase mood.` |
| `chapter_bridge.png` | Старый мост | `Old steel bridge over a river at sunset, abandoned cars on the bridge, a giant bandit boss with a shotgun on the far end, a zombie horde behind him, a survivor and his younger brother standing side by side in the foreground, emotional climax.` |
| `epilogue.png` | Эпилог | `Morning at a small harbor: a ship with survivors on deck, people waving, a young man and his little brother on the pier looking at the sunrise, seagulls, warm hopeful light, the ruined city far behind them in soft fog.` |

---

## 3. ПО ЖЕЛАНИЮ — карточки локаций (8 шт.)

Размер **1280×720**. Будут в досье миссии на «КАРТЕ ЗАРАЖЕНИЯ».

| Файл | Локация | Промпт (после общего стиля) |
|---|---|---|
| `loc_street.png` | Улица | `Wide view of an abandoned city street with crossroads, crashed cars, traffic lights, shop fronts, zombies walking, overcast evening.` |
| `loc_yard.png` | Стоянка контейнеров | `Container yard with stacked colorful shipping containers, cranes, forklifts, puddles, zombies between the rows, foggy morning.` |
| `loc_city.png` | Город | `Aerial three-quarter view of a big ruined city block grid with skyscrapers, wide avenues, burning cars, smoke columns, sunset.` |
| `loc_graveyard.png` | Кладбище | `Night cemetery with a chapel, iron fence, gravestones, glowing lanterns, skeletons and zombies in fog, moonlight.` |
| `loc_forest.png` | Лесной лагерь | `Pine forest clearing with abandoned tents, campfire smoke, a wooden watchtower, zombies between trees, cold blue dusk.` |
| `loc_industrial.png` | Промзона | `Industrial zone with factory buildings, pipes, tanks, chimneys, a gas station, conveyor belts, zombies, hazy yellow light.` |
| `loc_polygon.png` | Полигон | `Training ground with targets, sandbags, wooden walls, a small watchtower, military style, bright day.` |
| `loc_shelter.png` | Ворота убежища | `Survivor shelter gates made of shipping containers and a parked truck, floodlights, barbed wire, sandbags, a turret, a horde approaching at night.` |

---

## 4. НОВОЕ — часть третья «Южный порт» (5 шт.)

Главы — **1600×900**, карточка локации — **1280×720**. Общий стиль — как выше.

| Файл | Что | Промпт (после общего стиля) |
|---|---|---|
| `chapter_south.png` | Дорога на юг | `Forest highway heading south at morning, an armored pickup truck leading a small convoy, a big old refrigerator truck with an ice cream picture parked on the roadside, zombies blocking the road between tall pines, the sea faintly visible far ahead, hopeful light through fog.` |
| `chapter_port.png` | Южный порт | `Night seaport: frozen orange gantry crane over dark water, stacks of colorful shipping containers like dominoes, a big white passenger ship docked at the pier with one flashlight blinking on the bridge, zombies in dock worker overalls and a life vest shambling on the quay, fuel canisters scattered around.` |
| `chapter_lighthouse.png` | Маяк | `Stone lighthouse at the end of a breakwater at night, its rotating beam sweeping over the sea, an old bearded keeper in a knitted sweater at the top, survivors defending the base against a horde coming along the breakwater, in the beam far in the water a giant dark silhouette standing waist-deep.` |
| `chapter_voyage.png` | Последний рейс | `Dawn at the port: a white passenger ship with smoke from its funnels, people walking up the gangway, a captain in a white cap waving, a giant swollen sea-green zombie covered in seaweed and ropes rising from the water next to the pier, a young survivor and his little brother standing on the pier facing it.` |
| `loc_harbor.png` | Южный порт (карточка) | `Seaport quay at overcast day: orange gantry crane, stacked containers, a cargo ship at the pier, a wooden jetty with boats, a stone lighthouse on a breakwater, sunken sailing ship wreck, zombies on the docks.` |

---

## 5. НОВОЕ — 30 глав (13 новых глав + карточка гор, 14 шт.)

Главы — **1600×900**, карточка локации — **1280×720**. Общий стиль — как выше.

| Файл | Глава | Промпт (после общего стиля) |
|---|---|---|
| `chapter_siege.png` | Осада (ч.1) | `Night siege of a survivor camp made of shipping containers: a big bearded bandit leader with a red bandana banging two cooking pots, a zombie horde pushing against the welded gate, a former security guard in an old uniform holding the gate, a boy with a radio on a container roof, flares in the sky.` |
| `chapter_cold.png` | Холодная цепь (ч.2) | `Inside a frozen cold storage plant: frosty industrial freezers, icicles, pallets of ice cream boxes, a cheerful woman technologist in a puffy coat eating an ice cream cone, a young mechanic pulling a cooling unit, slow frozen zombies in the blue cold light.` |
| `chapter_hospital.png` | Больница (ч.2) | `Abandoned city hospital entrance at dusk, "appointments only" style sign without text, a nervous young male nurse in scrubs holding an aspirin bottle, a female doctor carrying a bag of syringes and a steel autoclave, zombies in hospital gowns behind the glass doors.` |
| `chapter_mother.png` | Голос мамы (ч.2) | `Night cemetery near an old ambulance station, scattered handwritten diary pages glowing in flashlight beams among gravestones, a young man and his little brother kneeling at a grave with candles, a warm ghostly image of their mother in a paramedic uniform in the clouds, emotional.` |
| `chapter_trail.png` | По следу Кабана (ч.2) | `Bandit hideout in an old industrial garage: a huge rusty air-raid siren on a truck, a fat bandit with a red bandana escaping through a hole behind a big barrel, a former guard swinging a wrench at the siren, sparks, smoke, orange industrial light.` |
| `chapter_crossing.png` | Переправа (ч.2) | `Old steel bridge jammed with wrecked cars from day zero: a bus, two trucks and a motorhome with garden gnomes on the roof, an armored truck towing a wreck with a chain, survivors defending the approach from zombies, a blue scarf tied to the railing.` |
| `chapter_feast.png` | Праздник (ч.2) | `Survivor camp coffee festival at night: string lights, a big coffee machine on a table, people dancing, a girl with a guitar, a goat, colorful flare fireworks in the sky, and a zombie horde appearing at the edge of the light, comedic chaos.` |
| `chapter_depot.png` | Портовые склады (ч.3) | `Long rows of port warehouses at sunset, a refrigerator truck with an ice cream picture, a trucker in a cap and his strict mother-in-law shouting from the cab with a radio, zombie dockers in overalls and hard hats, cranes visible in the distance.` |
| `chapter_resort.png` | Курорт «Чайка» (ч.3) | `Sunny seaside resort town promenade overrun by zombies in swimsuits, sun hats, flippers and inflatable rings, a resort animator in a bright costume dancing on a cafe roof to distract them, a pink tourist bus with palm trees painted on it, a white ship in the bay.` |
| `chapter_pass.png` | Горный перевал (ч.3) | `Snowy mountain pass with switchback road, a pink resort bus stuck in a snowdrift, a boy fixing the engine under the open hood, a young survivor with a rifle defending it, slow frosted zombies and zombie dogs coming down the slope, cold blue light.` |
| `chapter_keys.png` | Верхние Ключи (ч.3) | `Mountain village behind a wooden stockade with a big gate, a strict old woman former school principal in a shawl directing a queue of villagers, a boy giving vaccine shots at a table, cows, chimney smoke, a horde coming up the road below.` |
| `chapter_shepherd.png` | Пастух (ч.3) | `Top of a snowy mountain pass at an old ruined hikers lodge, a giant pale snow-white zombie twice human height howling at the sky, a herd of zombies following him like sheep, a young survivor and a dancer in a bright costume facing them, dramatic stormy sky.` |
| `chapter_home.png` | Домой (ч.3) | `Dawn over a survivor camp of containers by the sea with a small lighthouse, a white ship at the pier, everyone defending together: a mechanic on an armored truck, two former bandits with a gate and a serving tray, an old man with a thermos, a goat, a huge horde on the horizon, heroic final battle.` |
| `loc_mountain.png` | Горный перевал (карточка) | `Snowy mountain pass between huge grey rocks and pine trees, a dark road leading to a wooden stockade gate of a small village with smoking chimneys, wrecked cars and campfires on the pass, zombies on the slopes, cold clear day.` |

---

## Как прислать
Прикрепи картинки в чат с именами файлов из таблиц (или просто напиши, какая что). Я сам:
подрежу и сожму под телефон, положу в проект и подключу в окна сюжета и досье миссий.
