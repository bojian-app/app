AnnotationUI is a renamed, regular-weight subset of Noto Sans SC from https://github.com/google/fonts/tree/main/ofl/notosanssc, under the bundled SIL Open Font License. It contains 查看评论参与改写 and space for consistent annotation-menu typography across Android system themes. Expand the subset when changing menu labels.

ResumeDocument currently uses the unmodified `ChillRoundF v3.0.ttf` (寒蝉全圆体) from https://github.com/Warren2060/ChillRound at commit `46dda1602729b58de96e3fdee9f918d7aaa64727`, saved as `chill-round-f.ttf`. SHA-256: `7dae804b344f7bc1a1c8426b9515e9b54d7baac3e123263d0bae94d0a305a732`. Its copyright and SIL Open Font License are bundled in `ChillRound-OFL.txt`.

The upstream font has one regular (400) face. Flutter and HTML previews synthesize emphasized weights; PDF applies a light stroke to emphasized glyphs; Word embeds the regular face under its Chinese family name and uses bold run formatting. PDF embeds used glyph subsets, and Word embeds the obfuscated original font. Preview and native PDF/Word export share the same font file.

The previous static 400/600 Noto Sans SC comparison fonts have been removed. ResumeDocument uses only `chill-round-f.ttf`.

Template marketplace previews (inline and fullscreen) use unmodified Alibaba PuHuiTi 3.0 (font version 3.01) Regular, Medium and Bold from the official https://www.alibabafonts.com/ site. They are loaded locally under the HTML family alias `ResumeDocument`; Flutter interface typography and the existing editor/export font are unchanged. The complete official legal notice is bundled in `AlibabaPuHuiTi-LICENSE.txt`, sourced from https://www.yuque.com/yiguang-wkqc2/hgpff0/nus9wiinq4aeiegy. Font binaries are not converted or subsetted. The previous Source Han Sans comparison asset has been removed.

- `alibaba-puhuiti-3-regular.ttf`: https://fonts.alibabadesign.com/AlibabaPuHuiTi-3/AlibabaPuHuiTi-3-55-Regular/AlibabaPuHuiTi-3-55-Regular.ttf; SHA-256 `be33bc8d45ced30fa5c542f6f056565baf85003d4e079522110d76016f8a04e2`.
- `alibaba-puhuiti-3-medium.ttf`: https://fonts.alibabadesign.com/AlibabaPuHuiTi-3/AlibabaPuHuiTi-3-65-Medium/AlibabaPuHuiTi-3-65-Medium.ttf; SHA-256 `d92b378a2d08ac1e5c2b87d03b9939fdfae93d3c336b6a13ac4e00ce44f6db9e`.
- `alibaba-puhuiti-3-bold.ttf`: https://fonts.alibabadesign.com/AlibabaPuHuiTi-3/AlibabaPuHuiTi-3-85-Bold/AlibabaPuHuiTi-3-85-Bold.ttf; SHA-256 `d50f483fd8d9f95f9edbecdc199aee5fa9ddc5db8027f0d80334c3f502af61c8`.
