# Картинки для Dead Zone — что нужно и промпты

Готово: splash (ui/splash/splash.jpg), обложка Google Play (store/feature_graphic.png), prologue, chapter_1, chapter_2, chapter_3, chapter_4, chapter_bandits, chapter_5, chapter_6, chapter_baron, chapter_7
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

## Как прислать
Прикрепи картинки в чат с именами файлов из таблиц (или просто напиши, какая что). Я сам:
подрежу и сожму под телефон, положу в проект и подключу в окна сюжета и досье миссий.
