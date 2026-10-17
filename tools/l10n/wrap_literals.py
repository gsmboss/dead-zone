# Оборачивает русские строковые литералы в UIKit.t() там, где авто-перевод Control не сработает:
# форматирование (%), склейка (+), рисование текста (draw_string)
import re, glob, os, sys
ROOT = sys.argv[1]
APPLY = len(sys.argv) > 2 and sys.argv[2] == "apply"
os.chdir(ROOT)
cyr = re.compile(r'[А-Яа-яЁё]')
lit = re.compile(r'"(?:[^"\\]|\\.)*"')
SKIP = ('push_warning', 'push_error', 'print(', 'assert(', 'printerr', 'print_verbose', '_warn')
changed = 0
report = []
for f in sorted(glob.glob('**/*.gd', recursive=True)):
    if f.startswith('addons/'):
        continue
    lines = open(f, encoding='utf-8').read().split('\n')
    out = []
    for n, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('#') or stripped.startswith('##') or any(k in line for k in SKIP) \
                or re.match(r'\s*(const|enum|@export)', line):
            out.append(line); continue
        draw = 'draw_string' in line or 'draw_multiline_string' in line
        new = ''
        pos = 0
        for m in lit.finditer(line):
            text = m.group(0)
            start, end = m.span()
            before = line[:start]
            # Литерал внутри комментария
            if '#' in before and before.count('"') % 2 == 0 and '#' in before.split('"')[-1]:
                continue
            if not cyr.search(text):
                continue
            after = line[end:]
            already = re.search(r'(UIKit\.t|\btr)\(\s*$', before)
            fmt = re.match(r'\s*%', after) is not None
            concat = re.match(r'\s*\+', after) is not None or re.search(r'\+\s*$', before) is not None
            key = re.match(r'\s*:', after) is not None and not re.search(r'(=|\(|,|return|\?|else)\s*$', before)
            if already or key:
                continue
            if fmt or concat or draw:
                new += line[pos:start] + 'UIKit.t(' + text + ')'
                pos = end
                changed += 1
        if pos:
            new += line[pos:]
            report.append('%s:%d: %s' % (f, n + 1, new.strip()))
            out.append(new)
        else:
            out.append(line)
    if APPLY:
        open(f, 'w', encoding='utf-8').write('\n'.join(out))
print('wrapped', changed)
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wrap_report.txt'), 'w').write('\n'.join(report))
