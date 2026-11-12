# Builds Bojian Resume Sans: static, subsetted, renamed Noto Sans SC (OFL).
# Run from the app root with fontTools:
#   python3 tool/fonts/make_resume_sans.py 'NotoSansSC[wght].ttf' assets/fonts
import glob
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
src, out = sys.argv[1:3]


def charset():
    chars = set()
    for lead in range(0xA1, 0xF8):
        for trail in range(0xA1, 0xFF):
            try:
                chars.add(bytes([lead, trail]).decode('gb2312'))
            except UnicodeDecodeError:
                pass
    for first, last in [(0x20, 0x7E), (0xA0, 0x17F), (0x2000, 0x206F), (0x20A0, 0x20BF),
                        (0x2100, 0x21FF), (0x2200, 0x22FF), (0x2460, 0x24FF), (0x2500, 0x25FF),
                        (0x2600, 0x26FF), (0x2700, 0x27BF), (0x3000, 0x303F), (0xFE30, 0xFE4F),
                        (0xFF00, 0xFFEF)]:
        chars.update(map(chr, range(first, last + 1)))
    # Everything the app itself writes, including the sample resume.
    for path in glob.glob('lib/**/*.dart', recursive=True) + glob.glob('assets/**/*.json', recursive=True) + glob.glob('assets/**/*.js', recursive=True):
        chars.update(open(path, encoding='utf-8').read())
    return ''.join(sorted(c for c in chars if ord(c) >= 0x20))


text = charset()
for name, wght, style in [('regular', 400, 'Regular'), ('medium', 500, 'Medium'), ('bold', 700, 'Bold')]:
    f = instancer.instantiateVariableFont(TTFont(src), {'wght': wght})
    opts = subset.Options()
    opts.layout_features = ['*']; opts.name_IDs = ['*']; opts.name_languages = ['*']; opts.notdef_outline = True
    s = subset.Subsetter(opts); s.populate(text=text); s.subset(f)
    # Latin middle dot and bullet are proportional, as in Alibaba PuHuiTi.
    gs = f.getGlyphSet(); glyf = f['glyf']; dot = glyf['periodcentered']
    cx, cy = (dot.xMin + dot.xMax) / 2, (dot.yMin + dot.yMax) / 2
    order = f.getGlyphOrder()
    for glyph, cp, adv, scale in [('periodcentered.half', 0xB7, 357, .62), ('bullet.half', 0x2022, 308, 1.0)]:
        pen = TTGlyphPen(gs)
        gs['periodcentered'].draw(TransformPen(pen, (scale, 0, 0, scale, adv / 2 - cx * scale, cy - cy * scale)))
        g = pen.glyph(); g.recalcBounds(glyf)
        order.append(glyph); glyf[glyph] = g
        f['hmtx'][glyph] = (adv, g.xMin)
        if 'vmtx' in f: f['vmtx'][glyph] = f['vmtx']['periodcentered']
        for t in f['cmap'].tables:
            if cp in t.cmap: t.cmap[cp] = glyph
    f.setGlyphOrder(order); f['maxp'].numGlyphs = len(order)
    family = 'Bojian Resume Sans'
    for rec in f['name'].names:
        if rec.nameID in (1, 16): rec.string = family
        elif rec.nameID in (2, 17): rec.string = style
        elif rec.nameID == 4: rec.string = f'{family} {style}'
        elif rec.nameID == 6: rec.string = f'BojianResumeSans-{style}'
        elif rec.nameID == 3: rec.string = f'BojianResumeSans-{style};subset of Noto Sans SC'
    f['OS/2'].usWeightClass = wght
    f.save(f'{out}/resume-sans-{name}.ttf')
