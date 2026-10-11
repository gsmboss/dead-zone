#!/usr/bin/env python3
# Вертикальный ролик YouTube Shorts 1080×1920: python3 tools/trailer/shorts.py ru|en [папка с клипами v_*.avi]
# Запускать из корня проекта. Клипы снимаются вертикально (override.cfg 1080×1920, см. README.md).
# Монтаж в такт музыке: склейки по долям, зум-удар, цветовой сдвиг, вспышка, смаз, замедление,
# «впрыгивающие» надписи, анимированная концовка. Звук: музыка + звук игры + удары на надписях.
import math, os, random, subprocess, sys, urllib.request
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS, SR = 1080, 1920, 30, 48000
LANG = sys.argv[1] if len(sys.argv) > 1 else 'ru'
D = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
ROOT = os.getcwd()
MUSIC = os.path.join(ROOT, 'audio', 'music', 'combat.ogg')
# Музыка combat.ogg: 152 удара в минуту, первая доля на 0.255 с
BPM, PHASE = 152.0, 0.255
BEAT = 60.0 / BPM
FONT_URL = 'https://raw.githubusercontent.com/google/fonts/main/ofl/russoone/RussoOne-Regular.ttf'
FALLBACK_FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
YELLOW, RED, WHITE = (255, 206, 60), (235, 52, 40), (255, 255, 255)
random.seed(7)

T = {
    'ru': {'fall': 'ГОРОД ПАЛ', 'night': 'ЗА ОДНУ НОЧЬ', 'everywhere': 'ОНИ ПОВСЮДУ', 'grab': 'ХВАТАЙ\nОРУЖИЕ',
           'chop': 'РУБИ', 'burn': 'ЖГИ', 'shoot': 'СТРЕЛЯЙ', 'head': 'ХЕДШОТ!', 'bandits': 'БАНДИТЫ', 'boss': 'И БОССЫ',
           'city': 'ОГРОМНЫЙ\nГОРОД', 'shelter': 'СТРОЙ\nУБЕЖИЩЕ', 'story': '30 ГЛАВ\nСЮЖЕТА',
           'soon': 'СКОРО В GOOGLE PLAY', 'sub': 'ПОДПИШИСЬ'},
    'en': {'fall': 'THE CITY FELL', 'night': 'IN ONE NIGHT', 'everywhere': "THEY'RE EVERYWHERE", 'grab': 'GRAB\nA GUN',
           'chop': 'CHOP', 'burn': 'BURN', 'shoot': 'SHOOT', 'head': 'HEADSHOT!', 'bandits': 'BANDITS', 'boss': 'AND BOSSES',
           'city': 'HUGE\nOPEN CITY', 'shelter': 'BUILD YOUR\nSHELTER', 'story': '30 STORY\nCHAPTERS',
           'soon': 'COMING SOON TO GOOGLE PLAY', 'sub': 'SUBSCRIBE'},
}[LANG]
FILM = 'v_film_en.avi' if LANG == 'en' else 'v_film.avi'
# Кино снято с чёрными полосами — крупнее, чтобы заполнить вертикальный кадр (субтитры уходят за край)
FILM_ZOOM = 1.33

# Сегменты: клип, начало в клипе (с), длина в долях, вход (punch/flash/rgb/whip/cut), скорость [(доля, x)], надписи
# Надпись: (доля от начала сегмента, ключ T, цвет, стиль slam/pop, звук)
SEGMENTS = [
    (FILM, 53.0, 4, 'cut', None, [(0, 'fall', WHITE, 'slam', 'hit')]),
    (FILM, 55.8, 4, 'rgb', None, [(0, 'night', RED, 'slam', 'hit')]),
    ('v_harbor.avi', 11.5, 4, 'flash', None, [(0, 'everywhere', YELLOW, 'pop', 'moan')]),
    ('v_street.avi', 9.0, 4, 'whip', None, [(0, 'grab', WHITE, 'slam', 'hit')]),
    ('v_axe.avi', 9.5, 2, 'punch', None, [(0, 'chop', YELLOW, 'slam', 'hit')]),
    ('v_grave.avi', 9.0, 2, 'punch', None, [(0, 'shoot', RED, 'slam', 'hit')]),
    ('v_bridge.avi', 9.0, 2, 'punch', None, []),
    ('v_mountain.avi', 12.55, 6, 'rgb', [(0, 1.0), (0.3, 1.0), (0.36, 0.3), (0.8, 0.3), (0.9, 1.0)],
     [(2, 'head', RED, 'slam', 'boom')]),
    ('v_baron.avi', 10.0, 4, 'whip', None, [(0, 'bandits', WHITE, 'slam', 'hit'), (2, 'boss', RED, 'slam', 'hit')]),
    ('v_city.avi', 5.0, 4, 'flash', None, [(0, 'city', YELLOW, 'pop', 'hit')]),
    ('v_hub.avi', 1.5, 6, 'whip', None, [(0, 'shelter', YELLOW, 'pop', 'hit')]),
    (FILM, 18.0, 4, 'rgb', None, [(0, 'story', WHITE, 'pop', 'hit')]),
    ('END', 0, 12, 'flash', None, []),
]
TOTAL_BEATS = sum(s[2] for s in SEGMENTS)
DURATION = TOTAL_BEATS * BEAT
NFRAMES = int(round(DURATION * FPS))


def font(size):
    path = os.path.join(D, 'RussoOne-Regular.ttf')
    if not os.path.exists(path):
        try:
            urllib.request.urlretrieve(FONT_URL, path)
        except Exception as e:  # без сети — запасной шрифт
            print('шрифт не скачан:', e)
            return ImageFont.truetype(FALLBACK_FONT, size)
    return ImageFont.truetype(path, size)


# ---------- Надписи ----------
_text_cache = {}


def text_image(text, color, size=150):
    key = (text, color, size)
    if key in _text_cache:
        return _text_cache[key]
    f = font(size)
    lines = text.split('\n')
    tmp = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    widths = [tmp.textlength(l, font=f) for l in lines]
    # Длинная строка — уменьшаем шрифт, чтобы влезла в 960 px
    if max(widths) > 960:
        _text_cache[key] = text_image(text, color, int(size * 960 / max(widths)))
        return _text_cache[key]
    lh = int(size * 1.12)
    pad = 40
    im = Image.new('RGBA', (int(max(widths)) + pad * 2, lh * len(lines) + pad * 2), (0, 0, 0, 0))
    shadow = Image.new('RGBA', im.size, (0, 0, 0, 0))
    ds, d = ImageDraw.Draw(shadow), ImageDraw.Draw(im)
    for i, l in enumerate(lines):
        x = pad + (max(widths) - widths[i]) / 2
        y = pad + i * lh
        ds.text((x + 8, y + 12), l, font=f, fill=(0, 0, 0, 170))
        d.text((x, y), l, font=f, fill=color + (255,), stroke_width=max(6, size // 16), stroke_fill=(0, 0, 0, 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    shadow.alpha_composite(im)
    _text_cache[key] = shadow
    return shadow


def ease_out_back(x, s=2.2):
    x -= 1.0
    return 1.0 + (s + 1.0) * x ** 3 + s * x ** 2


def draw_caption(frame, img, age, life, style, cy):
    """Надпись: вход (slam — сверху крупно, pop — из точки), лёгкое дыхание, быстрый уход."""
    if age < 0 or age > life:
        return
    t_in = 0.16 if style == 'slam' else 0.22
    if age < t_in:
        k = age / t_in
        scale = 2.3 - 1.3 * (1 - (1 - k) ** 3) if style == 'slam' else max(0.05, ease_out_back(k))
        alpha = min(1.0, k * 2.5)
    else:
        scale = 1.0 + 0.025 * math.sin((age - t_in) * 7.0) + 0.02 * (age - t_in)
        alpha = 1.0
    out = life - age
    if out < 0.12:
        scale *= 1.0 + (0.12 - out) * 1.5
        alpha *= out / 0.12
    rot = -3.0 if style == 'slam' else 0.0
    # Тряска сразу после удара
    sx = sy = 0
    if style == 'slam' and t_in <= age < t_in + 0.2:
        a = (t_in + 0.2 - age) / 0.2 * 14
        sx, sy = int(random.uniform(-a, a)), int(random.uniform(-a, a))
    im = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.BILINEAR)
    if rot:
        im = im.rotate(rot, resample=Image.BILINEAR, expand=True)
    if alpha < 1.0:
        a = im.getchannel('A').point(lambda v: int(v * alpha))
        im.putalpha(a)
    frame.alpha_composite(im, (int(W / 2 - im.width / 2 + sx), int(cy - im.height / 2 + sy)))


# ---------- Чтение клипов ----------
class Reader:
    """Кадры клипа по порядку (ffmpeg → rawvideo); можно запрашивать кадр по номеру не назад."""

    def __init__(self, path, start, span):
        self.p = subprocess.Popen(['ffmpeg', '-v', 'error', '-ss', str(start), '-t', str(span + 0.5), '-i', path,
                                   '-vf', 'scale=%d:%d,fps=%d' % (W, H, FPS), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                                  stdout=subprocess.PIPE)
        self.idx = -1
        self.cur = None
        self.prev = None

    def get(self, i):
        while self.idx < i:
            raw = self.p.stdout.read(W * H * 3)
            if len(raw) < W * H * 3:
                break
            self.prev = self.cur
            self.cur = np.frombuffer(raw, np.uint8).reshape(H, W, 3)
            self.idx += 1
        return self.cur

    def close(self):
        self.p.kill()


def source_time(curve, frac, length):
    """Время в клипе для доли сегмента frac по кривой скорости [(доля, скорость)]."""
    if not curve:
        return frac * length
    t, steps = 0.0, 60
    for k in range(steps):
        f = (k + 0.5) / steps * frac
        sp = np.interp(f, [c[0] for c in curve], [c[1] for c in curve])
        t += sp * frac / steps * length
    return t


# ---------- Эффекты кадра ----------
VIGNETTE = None


def vignette():
    global VIGNETTE
    if VIGNETTE is None:
        y, x = np.mgrid[0:H, 0:W]
        r = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
        VIGNETTE = np.clip(1.0 - 0.45 * np.clip(r - 0.55, 0, 1) ** 1.5, 0.5, 1.0)[..., None].astype(np.float32)
    return VIGNETTE


def zoom(arr, z, ox=0, oy=0):
    if abs(z - 1.0) < 1e-3 and ox == 0 and oy == 0:
        return arr
    cw, ch = W / z, H / z
    x0, y0 = (W - cw) / 2 - ox / z, (H - ch) / 2 - oy / z
    im = Image.fromarray(arr).transform((W, H), Image.EXTENT, (x0, y0, x0 + cw, y0 + ch), Image.BILINEAR)
    return np.asarray(im)


def rgb_split(arr, px):
    if px < 1:
        return arr
    out = arr.copy()
    out[:, px:, 0] = arr[:, :-px, 0]
    out[:, :-px, 2] = arr[:, px:, 2]
    return out


def grade(arr):
    f = arr.astype(np.float32) / 255.0
    f = np.clip((f - 0.5) * 1.12 + 0.5, 0, 1)  # контраст
    lum = f.mean(axis=2, keepdims=True)
    f = np.clip(lum + (f - lum) * 1.18, 0, 1)  # насыщенность
    return f * vignette()


# ---------- Концовка ----------
END_BG = None


def end_frame(age):
    global END_BG
    if END_BG is None:
        bg = Image.open(os.path.join(ROOT, 'ui/splash/splash.jpg')).convert('RGB')
        s = max(W * 1.15 / bg.width, H * 1.15 / bg.height)
        bg = bg.resize((int(bg.width * s), int(bg.height * s)), Image.LANCZOS).filter(ImageFilter.GaussianBlur(5))
        END_BG = Image.blend(bg, Image.new('RGB', bg.size), 0.5)
    z = 1.0 + age * 0.012
    cw, ch = W * 1.12 / z, H * 1.12 / z
    x0, y0 = (END_BG.width - cw) / 2, (END_BG.height - ch) / 2
    fr = END_BG.transform((W, H), Image.EXTENT, (x0, y0, x0 + cw, y0 + ch), Image.BILINEAR).convert('RGBA')
    title = Image.open(os.path.join(ROOT, 'ui/splash/title.png')).convert('RGBA')
    tw = 980
    title = title.resize((tw, int(title.height * tw / title.width)), Image.LANCZOS)
    k = min(1.0, age / 0.35)
    sc = max(0.05, ease_out_back(k, 1.8)) * (1.0 + 0.02 * math.sin(age * 3.0))
    t2 = title.resize((int(title.width * sc), int(title.height * sc)), Image.BILINEAR)
    fr.alpha_composite(t2, (W // 2 - t2.width // 2, 620 - t2.height // 2))
    if age > 0.5:
        img = text_image(T['soon'], YELLOW, 70)
        a = min(1.0, (age - 0.5) / 0.3)
        y = int(960 + (1 - a) * 80)
        im = img.copy()
        im.putalpha(im.getchannel('A').point(lambda v: int(v * a)))
        fr.alpha_composite(im, (W // 2 - im.width // 2, y))
    if age > 1.1:
        # Кнопка «ПОДПИШИСЬ» пульсирует
        k = min(1.0, (age - 1.1) / 0.25)
        pulse = 1.0 + 0.05 * math.sin((age - 1.1) * 8.0)
        sc = max(0.05, ease_out_back(k)) * pulse
        bw, bh = int(620 * sc), int(150 * sc)
        btn = Image.new('RGBA', (bw + 20, bh + 20), (0, 0, 0, 0))
        bd = ImageDraw.Draw(btn)
        bd.rounded_rectangle((10, 18, bw + 10, bh + 18), radius=bh // 2, fill=(0, 0, 0, 140))
        bd.rounded_rectangle((10, 10, bw + 10, bh + 10), radius=bh // 2, fill=(220, 30, 30, 255))
        f = font(max(10, int(64 * sc)))
        tw2 = bd.textlength(T['sub'], font=f)
        bd.text((10 + (bw - tw2) / 2, 10 + bh / 2 - 64 * sc * 0.62), T['sub'], font=f, fill=(255, 255, 255, 255))
        fr.alpha_composite(btn, (W // 2 - btn.width // 2, 1180 - btn.height // 2))
    if age > 1.6:
        img = text_image('SALAMANDERLAB', WHITE, 44)
        fr.alpha_composite(img, (W // 2 - img.width // 2, 1330))
    return np.asarray(fr.convert('RGB'))


# ---------- Звук ----------
def load_audio(path, start=0.0, length=None):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-i', path]
    if length is not None:
        cmd += ['-t', str(length)]
    cmd += ['-ac', '2', '-ar', str(SR), '-f', 'f32le', '-']
    raw = subprocess.run(cmd, capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()


def mix_at(track, clip, t, gain):
    i = int(t * SR)
    if i >= len(track) or len(clip) == 0:
        return
    n = min(len(clip), len(track) - i)
    track[i:i + n] += clip[:n] * gain


def build_audio(cuts):
    total = int(DURATION * SR) + SR
    track = np.zeros((total, 2), np.float32)
    # Музыка: кусок ровно в 15 тактов от первой доли, по кругу с короткой склейкой
    music = load_audio(MUSIC)
    a = int(PHASE * SR)
    loop = music[a:a + int(60 * BEAT * SR)]
    xf = int(0.02 * SR)
    pos = 0
    while pos < total:
        n = min(len(loop), total - pos)
        chunk = loop[:n].copy()
        if pos > 0:
            chunk[:xf] *= np.linspace(0, 1, xf)[:, None]
        track[pos:pos + n] += chunk * 0.85
        pos += len(loop) - xf
    # Звук игры под музыкой (без кино — там обрывки фраз, и без замедления)
    for c in cuts:
        if c['src'] == 'END' or c['curve'] or c['src'].startswith('v_film'):
            continue
        g = load_audio(os.path.join(D, c['src']), c['start'], c['len'])
        if len(g):
            f = min(len(g), int(0.03 * SR))
            g[:f] *= np.linspace(0, 1, f)[:, None]
            g[-f:] *= np.linspace(1, 0, f)[:, None]
            mix_at(track, g, c['t0'], 0.4)
    sfx = {
        'hit': load_audio(os.path.join(ROOT, 'audio/impacts/world_02.ogg')),
        'boom': load_audio(os.path.join(ROOT, 'audio/world/explosion_01.ogg')),
        'moan': load_audio(os.path.join(ROOT, 'audio/zombies/moan_02.ogg')),
        'shot': load_audio(os.path.join(ROOT, 'audio/weapons/shotgun_shot.ogg')),
    }
    for c in cuts:
        for (b, _key, _col, _st, snd) in c['caps']:
            if snd:
                mix_at(track, sfx[snd], c['t0'] + b * BEAT, 0.7 if snd != 'boom' else 0.6)
    mix_at(track, sfx['shot'], cuts[-1]['t0'], 0.6)
    track = track[:int(DURATION * SR)]
    # Затухание в конце, мягкий лимитер
    fo = int(1.5 * SR)
    track[-fo:] *= np.linspace(1, 0, fo)[:, None]
    track = np.tanh(track * 1.1) / np.tanh(1.1)
    out = os.path.join(D, 'shorts_audio_%s.wav' % LANG)
    pcm = (np.clip(track, -1, 1) * 32767).astype('<i2')
    import wave
    with wave.open(out, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return out


# ---------- Сборка ----------
def main():
    cuts = []
    t = 0.0
    for src, start, beats, trans, curve, caps in SEGMENTS:
        length = beats * BEAT
        cuts.append({'src': src, 'start': start, 'len': length, 't0': t, 'trans': trans, 'curve': curve, 'caps': caps})
        t += length
    video = os.path.join(D, 'shorts_video_%s.mp4' % LANG)
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                            '-pix_fmt', 'yuv420p', video], stdin=subprocess.PIPE)
    prev_last = None
    for ci, c in enumerate(cuts):
        f0 = int(round(c['t0'] * FPS))
        f1 = int(round((c['t0'] + c['len']) * FPS)) if ci < len(cuts) - 1 else NFRAMES
        span = source_time(c['curve'], 1.0, c['len'])
        reader = Reader(os.path.join(D, c['src']), c['start'], span) if c['src'] != 'END' else None
        caps = [(b * BEAT, text_image(T[key], col), st) for (b, key, col, st, _s) in c['caps']]
        last = None
        for fi in range(f0, f1):
            age = fi / FPS - c['t0']
            frac = age / c['len']
            if reader is None:
                arr = end_frame(age)
            else:
                st = source_time(c['curve'], frac, c['len'])
                pos = st * FPS
                a = reader.get(int(pos))
                b = reader.get(int(pos) + 1) if c['curve'] and pos % 1 > 0.05 else None
                if b is not None and reader.prev is not None:
                    w = pos % 1  # смешивание соседних кадров в замедлении
                    arr = (reader.prev.astype(np.float32) * (1 - w) + b.astype(np.float32) * w).astype(np.uint8)
                else:
                    arr = a
                if arr is None:
                    arr = last if last is not None else np.zeros((H, W, 3), np.uint8)
            last = arr
            # Камера: медленный наезд + удар на входе
            z = (FILM_ZOOM if c['src'].startswith('v_film') else 1.0) + 0.04 * frac
            ox = oy = 0
            if c['trans'] in ('punch', 'flash', 'rgb') and age < 0.25:
                z += 0.14 * (1 - age / 0.25) ** 2
            if c['curve']:  # в замедлении — крупнее
                sp = np.interp(frac, [p[0] for p in c['curve']], [p[1] for p in c['curve']])
                z += (1.0 - sp) * 0.18
            if reader is not None:
                for (cb, _img, st) in caps:  # тряска кадра на ударе надписи
                    d = age - cb
                    if st == 'slam' and 0.16 <= d < 0.36:
                        amp = (0.36 - d) / 0.2 * 18
                        ox += random.uniform(-amp, amp)
                        oy += random.uniform(-amp, amp)
            arr = zoom(arr, z, ox, oy)
            # Смаз-переход: сдвиг с размытием в начале сегмента и в конце предыдущего
            if c['trans'] == 'whip' and age < 0.16 and prev_last is not None:
                k = age / 0.16
                src = arr if k > 0.5 else prev_last
                shift = int((1 - k) * W * 0.6) if k > 0.5 else -int(k * W * 0.6)
                rolled = [np.roll(src, shift + s, axis=1).astype(np.float32) for s in range(-60, 61, 30)]
                arr = (sum(rolled) / len(rolled)).astype(np.uint8)
            if c['trans'] == 'rgb' and age < 0.2:
                arr = rgb_split(arr, int(26 * (1 - age / 0.2)))
            f = grade(arr) if reader is not None else arr.astype(np.float32) / 255.0
            if c['trans'] == 'flash' and age < 0.15:
                f = f + (1 - f) * (0.85 * (1 - age / 0.15))
            if c['trans'] == 'cut' and ci == 0 and age < 0.3:
                f = f * (age / 0.3)
            frame = Image.fromarray((np.clip(f, 0, 1) * 255).astype(np.uint8)).convert('RGBA')
            for (cb, img, st) in caps:
                # Надпись живёт до следующей надписи сегмента или до конца сегмента
                nxt = [x[0] for x in caps if x[0] > cb]
                life = (nxt[0] if nxt else c['len']) - cb
                draw_caption(frame, img, age - cb, life, st, H * 0.34)
            enc.stdin.write(frame.convert('RGB').tobytes())
        prev_last = last
        if reader is not None:
            reader.close()
        print('сегмент %d/%d' % (ci + 1, len(cuts)), flush=True)
    enc.stdin.close()
    enc.wait()
    audio = build_audio(cuts)
    final = os.path.join(D, 'DeadZone_shorts_%s.mp4' % LANG)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-i', audio, '-map', '0:v', '-map', '1:a', '-c:v', 'copy',
                    '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', final], check=True)
    print(final, '%.1f s' % DURATION)


if __name__ == '__main__':
    main()
