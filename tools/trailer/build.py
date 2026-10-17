#!/usr/bin/env python3
# Сборка трейлера: сегменты (клип, начало, длина, титр) → xfade → музыка
import subprocess, sys, os
# Папка с клипами (*.avi), титрами (cap_*.png) и заставками (card_*.png): второй аргумент или ./out
D = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
LANG = sys.argv[1] if len(sys.argv) > 1 else 'ru'
SEGMENTS = [
    # (источник, начало, длина, титр или None)
    ('card_logo.png', 0, 2.6, None),
    ('c_film%s.avi' % ('_en' if LANG == 'en' else ''), 41.5, 6.5, None),
    ('c_film%s.avi' % ('_en' if LANG == 'en' else ''), 55.5, 5.5, None),
    ('c_film%s.avi' % ('_en' if LANG == 'en' else ''), 63.5, 5.5, None),
    ('c_street.avi', 8.0, 4.6, 'guns'),
    ('c_baron.avi', 8.5, 4.4, 'bandits'),
    ('c_harbor.avi', 9.0, 4.0, 'world'),
    ('c_mountain.avi', 9.0, 4.0, 'boss'),
    ('c_grave.avi', 9.0, 4.0, 'story'),
    ('c_hub.avi', 1.0, 6.0, 'shelter'),
    ('card_end_%s.png' % LANG, 0, 4.5, None),
]
FADE = 0.4
MUSIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'audio', 'music', 'combat.ogg')

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:]); sys.exit(1)

parts = []
for i, (src, start, length, cap) in enumerate(SEGMENTS):
    out = os.path.join(D, 'seg_%s_%02d.mp4' % (LANG, i))
    srcp = os.path.join(D, src)
    if src.endswith('.png'):
        inp = ['-loop', '1', '-t', str(length), '-i', srcp]
    else:
        inp = ['-ss', str(start), '-t', str(length), '-i', srcp]
    vf = 'scale=1920:1080,fps=30,format=yuv420p'
    cmd = ['ffmpeg', '-v', 'error', '-y'] + inp
    if cap:
        cmd += ['-loop', '1', '-t', str(length), '-i', os.path.join(D, 'cap_%s_%s.png' % (cap, LANG))]
        fc = '[0:v]scale=1920:1080,fps=30[b];[1:v]format=rgba,fade=t=in:st=0:d=0.3:alpha=1[c];[b][c]overlay=0:0,format=yuv420p[v]'
        cmd += ['-filter_complex', fc, '-map', '[v]']
    else:
        cmd += ['-vf', vf]
    cmd += ['-t', str(length), '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', out]
    run(cmd)
    parts.append((out, length))

# xfade цепочкой
inputs = []
for p, _ in parts:
    inputs += ['-i', p]
fc = ''
prev = '[0:v]'
offset = 0.0
for i in range(1, len(parts)):
    offset += parts[i - 1][1] - FADE
    label = '[v%d]' % i
    fc += '%s[%d:v]xfade=transition=fade:duration=%s:offset=%.3f%s;' % (prev, i, FADE, offset, label)
    prev = label
total = sum(l for _, l in parts) - FADE * (len(parts) - 1)
fc += '%sformat=yuv420p[vout]' % prev
video = os.path.join(D, 'video_%s.mp4' % LANG)
run(['ffmpeg', '-v', 'error', '-y'] + inputs + ['-filter_complex', fc, '-map', '[vout]', '-c:v', 'libx264',
     '-preset', 'slow', '-crf', '18', '-r', '30', video])
final = os.path.join(D, 'DeadZone_trailer_%s.mp4' % LANG)
af = 'afade=t=in:st=0:d=1.0,afade=t=out:st=%.2f:d=2.5,volume=0.9' % (total - 2.5)
run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-stream_loop', '-1', '-i', MUSIC, '-t', '%.2f' % total,
     '-af', af, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', final])
print(final, '%.1f s' % total)
