#!/usr/bin/env python3
"""Rebuild Verdant's original pixel sprites and vector toolbar icons.

Requires Pillow only for asset regeneration; Godot uses committed PNG/SVG files.
No downloaded game artwork or pretrained image assets are used.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / 'assets/sprites'
ICONS = ROOT / 'assets/icons'
SPRITES.mkdir(parents=True, exist_ok=True)
ICONS.mkdir(parents=True, exist_ok=True)
rng = random.Random(739)

def canvas(name, painter, size=(16, 16)):
    im = Image.new('RGBA', size)
    painter(ImageDraw.Draw(im))
    im.save(SPRITES / f'{name}.png')

colors = ['#164b60', '#d9c28b', '#7b9d52', '#48744b', '#7a8990', '#d7e6df']
for t, color in enumerate(colors):
    for variant in range(4):
        im = Image.new('RGBA', (16, 16), color)
        dr = ImageDraw.Draw(im)
        for _ in range(8):
            x, y = rng.randrange(15), rng.randrange(15)
            base = tuple(int(color[i:i+2], 16) for i in (1, 3, 5))
            shift = rng.choice([-8, -4, 5, 10])
            dr.rectangle((x, y, x+1, y), fill=tuple(max(0, min(255, c+shift)) for c in base))
        im.save(SPRITES / f'tile_{t}_{variant}.png')

def tree(d):
    d.rectangle((7, 10, 9, 15), fill='#634d37')
    d.rectangle((2, 7, 14, 12), fill='#28483c')
    d.rectangle((3, 3, 12, 10), fill='#345b40')
    d.rectangle((5, 1, 10, 11), fill='#456e45')
    d.rectangle((4, 3, 8, 7), fill='#63894b')
    d.rectangle((6, 1, 9, 4), fill='#83a956')
    d.rectangle((10, 6, 12, 9), fill='#527c43')
canvas('tree', tree)

def pine(d):
    d.rectangle((7, 10, 9, 15), fill='#655741')
    d.polygon([(8, 1), (14, 12), (2, 12)], fill='#264e44')
    d.polygon([(7, 1), (7, 11), (2, 11)], fill='#49795a')
    d.rectangle((6, 3, 8, 4), fill='#8baf78')
canvas('pine', pine)

def mountain(d):
    d.polygon([(0, 15), (7, 1), (15, 15)], fill='#4d6570')
    d.polygon([(0, 15), (7, 1), (7, 15)], fill='#96a6a5')
    d.polygon([(4, 7), (7, 1), (10, 7), (7, 5)], fill='#e5ede0')
canvas('peak', mountain)

def human(d):
    d.rectangle((6, 4, 10, 8), fill='#ebc995')
    d.rectangle((5, 3, 9, 4), fill='#57453b')
    d.rectangle((5, 9, 10, 12), fill='#eaca76')
    d.rectangle((5, 13, 6, 15), fill='#3b4b47')
    d.rectangle((9, 13, 10, 15), fill='#3b4b47')
    d.point((9, 6), fill='#313e3b')
canvas('settler', human)

def rabbit(d):
    d.rectangle((4, 9, 10, 13), fill='#e5e2c8')
    d.rectangle((9, 5, 12, 11), fill='#f4f0d8')
    d.rectangle((9, 2, 10, 6), fill='#f4f0d8')
    d.rectangle((12, 3, 13, 6), fill='#c4c5b3')
    d.rectangle((4, 13, 5, 14), fill='#b8c2af')
    d.point((12, 8), fill='#3c5147')
canvas('rabbit', rabbit)

def deer(d):
    d.rectangle((2, 7, 10, 11), fill='#b78950')
    d.rectangle((10, 4, 12, 10), fill='#d7ad6c')
    d.rectangle((10, 3, 14, 5), fill='#d7ad6c')
    for x in [3, 6, 9]: d.line((x, 11, x, 15), fill='#614f37')
    d.line((10, 0, 12, 3), fill='#d2bf8a')
    d.point((13, 4), fill='#38463d')
canvas('deer', deer)

def house(d):
    d.rectangle((4, 16, 28, 28), fill='#24433c')
    d.rectangle((5, 12, 26, 25), fill='#e4d8ad')
    d.rectangle((7, 12, 10, 25), fill='#bea67b')
    d.polygon([(2, 13), (13, 3), (19, 3), (30, 13)], fill='#9a604e')
    d.polygon([(2, 13), (13, 3), (16, 3), (16, 13)], fill='#cf9366')
    d.rectangle((3, 13, 29, 15), fill='#674d3f')
    d.rectangle((18, 18, 22, 25), fill='#506159')
    d.rectangle((11, 18, 14, 21), fill='#759592')
    d.rectangle((23, 4, 25, 10), fill='#afbdad')
canvas('house', house, (32, 32))

def fire(d):
    d.polygon([(2, 12), (5, 6), (5, 9), (8, 1), (12, 8), (14, 12), (10, 15), (6, 15)], fill='#e98846')
    d.polygon([(6, 13), (8, 7), (11, 13), (9, 15)], fill='#f5d97d')
canvas('fire', fire)

def stone(d):
    d.polygon([(2, 12), (4, 7), (8, 5), (13, 8), (14, 13)], fill='#4e6267')
    d.polygon([(3, 11), (5, 7), (8, 6), (11, 8), (9, 11)], fill='#b3b6a3')
    d.rectangle((6, 9, 8, 10), fill='#d7d6bd')
canvas('stone', stone)

def depot(d):
    d.rectangle((2, 9, 13, 14), fill='#624a36')
    d.rectangle((3, 8, 12, 12), fill='#b99760')
    d.line((7, 8, 7, 14), fill='#e4c886')
    d.line((1, 7, 14, 7), fill='#dfc885', width=2)
    d.line((7, 0, 7, 6), fill='#d8d8b3')
    d.polygon([(8, 0), (14, 2), (8, 4)], fill='#c2d98a')
canvas('depot', depot)

def soldier(d):
    d.rectangle((6, 3, 10, 6), fill='#d9b18b')
    d.rectangle((5, 2, 11, 3), fill='#759390')
    d.rectangle((5, 7, 10, 12), fill='#bbcaaf')
    d.rectangle((5, 13, 6, 15), fill='#364a49')
    d.rectangle((9, 13, 10, 15), fill='#364a49')
    d.rectangle((2, 8, 5, 12), fill='#9c733f')
    d.line((13, 3, 13, 14), fill='#c8a269')
    d.polygon([(11, 4), (13, 0), (15, 4)], fill='#d6ded0')
canvas('soldier', soldier)
def archer(d):
    soldier(d)
    d.rectangle((11, 0, 15, 15), fill=(0, 0, 0, 0))
    d.arc((10, 4, 15, 13), -90, 90, fill='#d7ba79', width=2)
    d.line((12, 4, 12, 13), fill='#e6e4cb')
canvas('archer', archer)
def tower(d):
    d.rectangle((8, 10, 24, 29), fill='#657b79')
    d.rectangle((9, 10, 20, 28), fill='#b0b9a0')
    d.rectangle((5, 6, 27, 12), fill='#82958b')
    for x in (5, 14, 23): d.rectangle((x, 2, x+4, 7), fill='#b7c3ab')
    d.rectangle((14, 16, 18, 23), fill='#2c4c50')
    d.line((9, 25, 23, 25), fill='#82958b')
canvas('tower', tower, (32, 32))
def boat(d):
    d.polygon([(2, 22), (29, 22), (24, 29), (7, 29)], fill='#654a35')
    d.line((2, 22, 29, 22), fill='#d9b971', width=2)
    d.line((15, 2, 15, 24), fill='#937547', width=2)
    d.polygon([(17, 3), (28, 18), (17, 18)], fill='#eee0b1')
    d.polygon([(13, 7), (6, 18), (13, 18)], fill='#c6d9c1')
canvas('boat', boat, (32, 32))

# Original inherited appearance variants: clothing, fur, and coat markings.
for variant, color in enumerate(['#eaca76', '#95c7bc', '#c99daa', '#dfdfc3']):
    def person_variant(d, tone=color, number=variant):
        human(d)
        d.rectangle((5, 9, 10, 12), fill=tone)
        d.rectangle((5, 3, 9, 4), fill=['#57453b', '#a17950', '#354941', '#8b7770'][number])
        if number % 2: d.rectangle((4, 9, 4, 11), fill=tone)
    canvas(f'settler_{variant}', person_variant)
    def rabbit_variant(d, tone=color, number=variant):
        rabbit(d)
        d.rectangle((4, 9, 8, 12), fill=['#e5e2c8', '#beaa83', '#9baba4', '#f0eee0'][number])
        if number % 2: d.rectangle((5, 9, 6, 10), fill='#eee8d1')
    canvas(f'rabbit_{variant}', rabbit_variant)
    def deer_variant(d, tone=color, number=variant):
        deer(d)
        d.rectangle((2, 7, 9, 10), fill=['#b78950', '#cfb481', '#907560', '#dcd9be'][number])
        if number % 2:
            for x in [3, 6, 8]: d.point((x, 8), fill='#eee5c4')
    canvas(f'deer_{variant}', deer_variant)

strokes = {
'family':'<circle cx="12" cy="4" r="2"/><path d="M12 6v6M5 15v-3h14v3"/><circle cx="5" cy="18" r="3"/><circle cx="19" cy="18" r="3"/>',
'favorite':'<path d="m12 2 3 7 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z"/>',
'war':'<path d="m4 3 14 15M3 3l1 5L16 20M3 17l4 4M17 3 3 17M21 3l-1 5L8 20M17 17l4 4"/>',
'tower':'<path d="M5 21V9H3V3h4v3h3V3h4v3h3V3h4v6h-2v12ZM10 21v-6h4v6M8 10h8"/>',
'crown':'<path d="M3 7l4 4 5-7 5 7 4-4-2 13H5ZM6 16h12"/>',
'borders':'<path d="M3 4h7l4 3h7v14h-8l-5-3H3ZM10 4v7l-2 7M14 7l-1 14"/>',
'peace':'<path d="M4 20 20 4M7 17Q1 9 6 7q5 1 4 7M13 11q-1-8 4-8 4 4-1 7M10 15q8 1 9-4-4-4-7 1"/>',
'discord':'<path d="m13 2-8 11h6l-1 9 9-13h-7Z"/>',

'village':'<path d="m2 11 10-8 10 8M5 10v11h14V10M10 21v-7h4v7M3 21h18"/>',

'pan':'<path d="M12 3v18M3 12h18M9 6l3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3M18 9l3 3-3 3"/>',
'inspect':'<circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/>',
'ocean':'<path d="M2 8q3-4 6 0t6 0 6 0M2 14q3-4 6 0t6 0 6 0M2 20q3-4 6 0t6 0 6 0"/>',
'sand':'<path d="m2 18 6-7 5 5 4-9 5 11Z"/><circle cx="7" cy="5" r="2"/>',
'meadow':'<path d="M3 20h18M7 20l-3-8 5 4 2-11 3 10 5-6-2 11"/>',
'forest':'<path d="M12 2 4 12h4l-5 6h18l-5-6h4ZM12 18v4"/>',
'mountain':'<path d="m2 20 10-17 10 17ZM8 10l4 3 3-4"/>',
'snow':'<path d="M12 2v20M3.4 7l17.2 10M3.4 17 20.6 7M9 4l3 3 3-3M9 20l3-3 3 3M4 10l4-1V5M20 14l-4 1v4M4 14l4 1v4M20 10l-4-1V5"/>',
'settler':'<circle cx="12" cy="7" r="4"/><path d="M5 21v-3a7 7 0 0 1 14 0v3M8 21v-5M16 21v-5"/>',
'rabbit':'<path d="M7 11Q1 0 6 2l4 8M13 10q0-11 4-8l-1 11M5 18q-2-8 7-8t7 10H5Z"/><path d="M14 15h.1"/>',
'deer':'<path d="M4 17v5M13 17v5M3 12h12V7h5v5h-3v5H3ZM16 7l-4-5M15 5V1M19 7l3-5M20 5V1"/>',
'rain':'<path d="M5 14a4 4 0 0 1 0-8 6 6 0 0 1 11-1 4.5 4.5 0 0 1 2 9ZM7 17l-2 4M13 17l-2 4M19 17l-2 4"/>',
'fire':'<path d="M13 2q2 7-2 9 6-2 6-5 10 17-6 16Q1 21 5 12q1 5 3 3-1-9 5-13Z"/>',
'bless':'<path d="m12 2 3 7 7 3-7 3-3 7-3-7-7-3 7-3Z"/>',
'meteor':'<circle cx="8" cy="16" r="6"/><path d="m10 4 5-3M15 9l7-7M20 14l3-5M6 14l4 4"/>',
'leaf':'<path d="M20 3Q1 1 4 15q3 8 11 2 6-4 5-14ZM3 22 16 8"/>',
'plus':'<path d="M12 4v16M4 12h16"/>',
'minus':'<path d="M4 12h16"/>',
'fit':'<path d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5M8 8h8v8H8Z"/>',
'save':'<path d="M4 3h13l4 4v14H3V3ZM7 3v6h9V3M7 21v-8h10v8"/>',
'load':'<path d="M3 7h7l2 3h9l-3 11H3ZM3 7V4h8l2 3"/>',
'world':'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3q-9 9 0 18 9-9 0-18"/>',
'pause':'<path d="M8 5v14M16 5v14"/>',
'play':'<path d="m8 4 12 8-12 8Z"/>',
'laws':'<path d="M12 3v18M4 7h16M6 7l-4 8h8ZM18 7l-4 8h8M8 21h8"/>',
'close':'<path d="m5 5 14 14M5 19l14-14"/>',
'help':'<circle cx="12" cy="12" r="9"/><path d="M9 8a3 3 0 0 1 6 0c0 3-3 2-3 6M12 17h.1"/>',
'history':'<path d="M4 8a9 9 0 1 1-1 8M3 2v7h7M12 7v6l4 2"/>',
}
for name, body in strokes.items():
    (ICONS / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#dce7d5" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>')
(ICONS / 'app.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="#112b32"/><path d="M28 70 42 48 67 39 93 52 102 72 80 91 47 92Z" fill="#5c9061"/><path d="m37 63 17-19 28 2 12 15-16 19H48Z" fill="#aad27b"/><path d="M66 17v14M59 24h14" stroke="#e8d7a6" stroke-width="3"/><path d="m19 93 6 3 10-2M96 100l9-2" fill="none" stroke="#4b8085" stroke-width="3"/></svg>')
print('Generated original terrain, sprites, and icons.')

# Phase 6: original biome surfaces, wetland reeds, glimmer trees, and climate icons.
biome_colors = ['#d9c28b', '#7b9d52', '#48744b', '#d7e6df', '#c99a62', '#518c83', '#7476a7']
biome_rng = random.Random(610031)
for biome, color in enumerate(biome_colors):
    base = tuple(int(color[i:i+2], 16) for i in (1, 3, 5))
    for variant in range(4):
        im = Image.new('RGBA', (16, 16), color)
        d = ImageDraw.Draw(im)
        for _ in range(12):
            x, y = biome_rng.randrange(15), biome_rng.randrange(15)
            shift = biome_rng.choice([-9, -4, 5, 9])
            d.line((x, y, x+1, y), fill=tuple(max(0, min(255, c+shift)) for c in base))
        if biome == 4:
            d.line((3, 4, 7, 6, 9, 5), fill='#b58653')
        elif biome == 5:
            d.line((2, 10, 7, 10), fill='#80b1a0')
        elif biome == 6:
            d.point((4, 3), fill='#c9d9bd')
            d.point((12, 10), fill='#a6caca')
        im.save(SPRITES / f'biome_{biome}_{variant}.png')

def glimmer_tree(d):
    d.rectangle((7, 9, 9, 15), fill='#615779')
    d.rectangle((2, 4, 13, 10), fill='#414f78')
    d.rectangle((4, 1, 11, 9), fill='#89a7bc')
    d.rectangle((3, 3, 8, 7), fill='#bac7c9')
    d.rectangle((6, 1, 9, 4), fill='#d2dcbc')
    d.point((12, 3), fill='#ecdda2')
canvas('glimmer_tree', glimmer_tree)

def reeds(d):
    for x, h in [(3, 7), (6, 3), (10, 5), (13, 8)]:
        d.line((x, h, x, 14), fill='#b1bb71')
        d.rectangle((x-1, h-1, x, h+3), fill='#79684b')
    d.line((1, 14, 14, 14), fill='#7ba68c')
canvas('reeds', reeds)

climate_icons = {
    'sun': '<circle cx="16" cy="16" r="6"/><path d="M16 2v4m0 20v4M2 16h4m20 0h4M6 6l3 3m14 14 3 3M6 26l3-3M23 9l3-3"/>',
    'drought': '<circle cx="22" cy="9" r="5"/><path d="M3 25h26M6 20l5-5 5 4 4-3M13 25l3-5 4 5"/>',
    'wetland': '<path d="M3 25q6-4 12 0t14 0M8 22V9m8 13V5m8 17V11"/><path d="M6 9V5h4v4M14 8V3h4v5M22 13V8h4v5"/>',
    'glimmer': '<path d="m16 2 3 8 8 3-8 3-3 8-3-8-8-3 8-3ZM5 22l2 3-2 3-2-3Zm21 0 2 3-2 3-2-3Z"/>',
    'biome': '<path d="M4 26h24M8 24V13m14 11V9M3 16l5-9 5 9ZM16 13l6-10 6 10Z"/>',
    'lightning': '<path d="M18 2 6 18h9l-1 12 12-18h-9Z"/>',
    'quake': '<path d="M3 24h8l3-7-4-4 9-7-2 9 5 4-3 5h10M4 8l3 2M24 8l4-2"/>',
    'volcano': '<path d="m2 28 9-16h10l9 16ZM11 12l5 7 5-7M16 8V2M9 8 6 4m17 4 3-4"/>',
    'plague': '<circle cx="16" cy="16" r="8"/><path d="M16 3v5m0 16v5M3 16h5m16 0h5M7 7l4 4m10 10 4 4M7 25l4-4M21 11l4-4"/><circle cx="13" cy="14" r="1"/><circle cx="19" cy="18" r="1"/>',
    'planet': '<circle cx="16" cy="16" r="12"/><path d="m7 7 9 3-3 6-6 1 2 8m14-17-3 8 5 5M4 18l-1 6M28 8l1-4"/>',
}
for name, body in climate_icons.items():
    (ICONS / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#c9dda0" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n')

# Phase 7: a woven community emblem, authored as vector geometry.
(ICONS / 'society.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#eef0d8" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16 3 28 10v12l-12 7L4 22V10Z"/><path d="m9 12 14 8m0-8L9 20M16 7v18M7 16h18"/><circle cx="16" cy="16" r="4"/></g></svg>\n')

# Phase 8: original audio/accessibility settings control.
(ICONS / "settings.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#dce7d5" stroke-width="1.65" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2" fill="#112d35"/><circle cx="15" cy="12" r="2" fill="#112d35"/><circle cx="8" cy="18" r="2" fill="#112d35"/></g></svg>\n')
