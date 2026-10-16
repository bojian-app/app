AnnotationUI is a renamed, regular-weight subset of Noto Sans SC from https://github.com/google/fonts/tree/main/ofl/notosanssc, under the bundled SIL Open Font License. It contains 查看评论参与改写 and space for consistent annotation-menu typography across Android system themes. Expand the subset when changing menu labels.

ResumeDocument currently uses the unmodified `ChillRoundF v3.0.ttf` (寒蝉全圆体) from https://github.com/Warren2060/ChillRound at commit `46dda1602729b58de96e3fdee9f918d7aaa64727`, saved as `chill-round-f.ttf`. SHA-256: `7dae804b344f7bc1a1c8426b9515e9b54d7baac3e123263d0bae94d0a305a732`. Its copyright and SIL Open Font License are bundled in `ChillRound-OFL.txt`.

The upstream font has one regular (400) face. Flutter and HTML previews synthesize emphasized weights; PDF applies a light stroke to emphasized glyphs; Word embeds the regular face under its Chinese family name and uses bold run formatting. PDF embeds used glyph subsets, and Word embeds the obfuscated original font. Preview and native PDF/Word export share the same font file.

`resume-regular.ttf` and `resume-semibold.ttf` are the previous static 400/600 Noto Sans SC fonts, retained for comparison. They are no longer registered as the active ResumeDocument family.
