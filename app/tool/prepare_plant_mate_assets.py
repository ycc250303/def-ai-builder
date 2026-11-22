"""从交接包复制运行素材并提取 SVG 内已有的 PNG；原目录只读。"""
import base64
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re

APP = Path(__file__).resolve().parents[1]
SOURCE = APP / 'assets/PlantMate'
DEST = APP / 'assets/plant_mate'
records = []


def save(relative, content, original):
    target = DEST / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    records.append({'asset': relative, 'source': str(original.relative_to(APP)),
                    'sha256': hashlib.sha256(content).hexdigest()})


pngs = SOURCE / '原始素材/V12_Garden_全部PNG/png'
for p in sorted(pngs.glob('*.png')):
    if p.stem.startswith('unknown_'):
        continue
    group = ('characters' if p.stem == 'tuantuan' else 'pets' if p.stem in ['eggie', 'baybi', 'eggie_avatar']
             else 'effects' if p.stem in ['bubble_cluster', 'food_fried_egg', 'eyemask_original_cutout'] else 'decorations')
    save(f'{group}/{p.name}', p.read_bytes(), p)

shared = SOURCE / '网页/assets/shared'
for i, key in enumerate(['5e460636b97fd8', '2bb819d5e33e6e', '03477dbf736955', 'c72969bab82154',
                         '88e687410f81f2', 'bb7b8726e29a55', 'f8e8a224deafd4', 'c48abdf2a8df49']):
    p = shared / f'{key}.svg'
    match = re.search(r'data:image/png;base64,([^\"]+)', p.read_text())
    if match is None:
        raise ValueError(f'缺少内嵌 PNG: {p}')
    save(f'pets/{"fixed" if i == 7 else f"mature_{i + 1}"}.png', base64.b64decode(match[1]), p)


class MapReader(HTMLParser):
    def __init__(self):
        super().__init__()
        self.layers, self.ground = [], []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get('class', '')
        if 'map-ground' not in cls and not (tag == 'img' and 'map-sprite' in cls):
            return
        style = dict(item.split(':', 1) for item in a['style'].split(';') if ':' in item)
        rect = {k: float(style[k].removesuffix('px')) for k in ['left', 'top', 'width', 'height']}
        if 'map-ground' in cls:
            self.ground.append({**rect, 'water': 'water' in cls})
        elif a.get('id') not in ['plantSlot', 'eggSlot']:
            self.layers.append({**rect, 'id': a['data-sprite'], 'asset': 'decorations/' + Path(a['src']).name,
                                'z': int(style.get('z-index', 3))})


p = SOURCE / '原始素材/V12_原始开发源码_可单独运行/PlantMate_V12_Development.html'
parser = MapReader()
parser.feed(p.read_text())
layout = {'width': 675, 'height': 1292, 'ground': parser.ground, 'layers': parser.layers}
save('map/layout.json', json.dumps(layout, ensure_ascii=False, indent=2).encode(), p)
(DEST / 'manifest.json').write_text(json.dumps({'version': 1, 'assets': records}, ensure_ascii=False, indent=2) + '\n')
print(f'已整理 {len(records)} 个运行资源；原始目录保持原样')
