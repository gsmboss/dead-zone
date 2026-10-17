#!/usr/bin/env python3
# Запуск из корня проекта: python3 tools/make_hero_skin.py → models/characters/hero/
# Персонаж «Разработчик» по фото: перекраска Characters_Matt (Quaternius, CC0) — светлее кожа, чёрные пышные волосы
# без бороды, белая рубашка, тёмно-синие брюки, чёрные туфли. Текстура — внешний PNG, геометрия — тот же буфер.
import json, base64, numpy as np, sys
from PIL import Image
SRC = 'models/zombies/Characters_Matt.gltf'
OUT_DIR = 'models/characters/hero/'
j = json.load(open(SRC))
buf = bytearray(base64.b64decode(j['buffers'][0]['uri'].split(',', 1)[1]))

def view(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    assert a['componentType'] == 5126
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0)
    assert stride in (0, n * 4)
    return np.frombuffer(buf, np.float32, count=a['count'] * n, offset=off).reshape(a['count'], n)

# Атлас
img = j['images'][0]; bv = j['bufferViews'][img['bufferView']]
import io
atlas = Image.open(io.BytesIO(bytes(buf[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))).convert('RGB')
CELL = atlas.width // 32
SKIN, HAIR, SHIRT, PANTS, DARK = (198, 146, 110), (26, 21, 18), (238, 236, 228), (28, 30, 44), (20, 20, 22)
RECOLOR = {(9, 0): SKIN, (1, 0): SKIN, (2, 0): HAIR, (3, 0): DARK, (4, 0): SHIRT, (5, 0): SHIRT, (6, 0): (226, 224, 216),
           (7, 0): PANTS, (8, 0): SHIRT, (10, 0): PANTS}
# Свободная клетка под кожу на месте бороды (чтобы не путать с волосами) — та же кожа
for (cx, cy), col in RECOLOR.items():
    atlas.paste(col, (cx * CELL, cy * CELL, (cx + 1) * CELL, (cy + 1) * CELL))
# Лёгкий градиент на рубашке (складки) — светлее сверху
for (cx, cy) in [(4, 0), (5, 0), (8, 0)]:
    for y in range(CELL):
        k = 1.0 - 0.05 * y / CELL
        for x in range(CELL):
            atlas.putpixel((cx * CELL + x, cy * CELL + y), tuple(int(c * k) for c in SHIRT))

m = j['meshes'][0]['primitives'][0]
uv = view(m['attributes']['TEXCOORD_0'])
pos = view(m['attributes']['POSITION'])
cell = np.floor(uv * 32).astype(int)
# Кость с наибольшим весом → часть тела
def view_any(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    dt = {5126: np.float32, 5123: np.uint16, 5121: np.uint8}[a['componentType']]
    return np.frombuffer(bytes(buf), dt, count=a['count'] * 4, offset=bv.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], 4)
joints = view_any(m['attributes']['JOINTS_0']); weights = view_any(m['attributes']['WEIGHTS_0'])
bone_names = [j['nodes'][k]['name'] for k in j['skins'][0]['joints']]
main = [bone_names[k] for k in joints[np.arange(len(joints)), weights.argmax(1)]]
is_hand = np.array([any(b.startswith(x) for x in ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky', 'Hand', 'Palm')) for b in main])
is_arm = np.array([('Arm' in b or 'Shoulder' in b) for b in main]) & ~is_hand
is_torso = np.array([b in ('Torso', 'Chest', 'Spine', 'Hips', 'Abdomen', 'Neck') for b in main])
shirt_uv = np.array([5.5 / 32, 0.5 / 32], np.float32)
skin_cell = (cell[:, 0] == 1) & (cell[:, 1] == 0)
dark_cell = (cell[:, 0] == 3) & (cell[:, 1] == 0)
# Длинные рукава и никакой голой кожи на плечах; капюшон, напульсники и ремень — в цвет рубашки
uv[skin_cell & (is_arm | is_torso)] = shirt_uv
uv[dark_cell & (is_arm | is_torso)] = shirt_uv
hair = (cell[:, 0] == 2) & (cell[:, 1] == 0)
# Борода: волосяная клетка ниже глаз и спереди → кожа
beard = hair & (pos[:, 1] < 1.175) & (pos[:, 2] > -0.12)
skin_uv = np.array([1.5 / 32, 0.5 / 32], np.float32)
uv[beard] = skin_uv
# Пышная причёска: волосы выше бровей и сзади — раздуть от центра головы
head_c = np.array([0.0, 1.27, -0.08], np.float32)
top = hair & ~beard & ((pos[:, 1] > 1.33) | (pos[:, 2] < -0.12))
pos[top] = head_c + (pos[top] - head_c) * np.array([1.12, 1.14, 1.12], np.float32)
# Границы позиций (min/max аксессора) обновить
a = j['accessors'][m['attributes']['POSITION']]
a['min'] = [float(v) for v in pos.min(0)]; a['max'] = [float(v) for v in pos.max(0)]
print('борода', int(beard.sum()), 'волосы раздуты', int(top.sum()))

atlas.save(OUT_DIR + 'Hero_Atlas.png')
j['images'][0] = {'uri': 'Hero_Atlas.png', 'name': 'Hero_Atlas'}
j['buffers'][0]['uri'] = 'data:application/octet-stream;base64,' + base64.b64encode(bytes(buf)).decode()
for n in j['nodes']:
    if n.get('name') == 'Matt':
        n['name'] = 'Hero'
json.dump(j, open(OUT_DIR + 'Characters_Hero.gltf', 'w'))
print('ok')
