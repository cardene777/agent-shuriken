"""The newsprint ink treatment and the bundled font (Kaisei Decol Bold) for figures drawn from
HTML or SVG source. The font is found relative to this skill folder."""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / 'data/fonts/KaiseiDecol-Bold.ttf'

def font_file():
    if not FONT.is_file():
        raise FileNotFoundError(f'Missing newsprint font: {FONT}')
    return FONT

def svg_defs(width=1600, height=1000):
    """Return seeded ink texture definitions; geometry remains the caller's."""
    if width <= 0 or height <= 0:
        raise ValueError('Canvas dimensions must be positive')
    press=dict(typeface='Kaisei Decol Bold',seed=1941,pore_tile=[97,79],ink_displacement_px=0.65,edge_bleed_px=0.16,noise_frequency=[0.23,0.6],noise_octaves=3,coverage_table=[0,0.45,0.7,0.85,1,0.98,1,1])
    rng=random.Random(press['seed'])
    pores=[]
    for i in range(42):
     x=rng.uniform(0,97);y=rng.uniform(0,79);radius=rng.uniform(.45,1.15)
     pores.append(f'<ellipse cx="{x:.3f}" cy="{y:.3f}" rx="{radius:.3f}" ry="{radius*.63:.3f}" fill="black" opacity="{rng.uniform(.4,.88):.3f}"/>')
    for i in range(8):
     x=rng.uniform(0,97);y=rng.uniform(0,79)
     pores.append(f'<path d="M{x:.3f} {y:.3f} l{rng.uniform(1.6,3.2):.3f} {rng.uniform(-.6,.6):.3f}" stroke="#333" stroke-width=".6"/>')
    defs='''<defs>
    <pattern id="dry-ink" width="97" height="79" patternUnits="userSpaceOnUse"><rect width="97" height="79" fill="white"/>'''+''.join(pores)+'''</pattern>
    <mask id="press-pores" maskUnits="userSpaceOnUse" x="0" y="0" width="1600" height="1000"><rect width="1600" height="1000" fill="url(#dry-ink)"/></mask>
    <filter id="newsprint-press" x="-4%" y="-12%" width="108%" height="124%" color-interpolation-filters="sRGB">
     <feTurbulence type="fractalNoise" baseFrequency=".23 .6" numOctaves="3" seed="1941" result="fibres"/>
     <feDisplacementMap in="SourceGraphic" in2="fibres" scale=".65" xChannelSelector="R" yChannelSelector="G" result="edge"/>
     <feColorMatrix in="fibres" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  .25 .6 .15 0 0" result="pressure"/>
     <feComponentTransfer in="pressure" result="coverage"><feFuncA type="discrete" tableValues="0 .45 .7 .85 1 .98 1 1"/></feComponentTransfer>
     <feComposite in="edge" in2="coverage" operator="in" result="ink"/>
     <feGaussianBlur in="ink" stdDeviation=".16" result="bleed"/>
     <feMerge><feMergeNode in="bleed"/><feMergeNode in="ink"/></feMerge>
    </filter></defs>'''
    return defs.replace('width="1600" height="1000"', f'width="{width}" height="{height}"')
