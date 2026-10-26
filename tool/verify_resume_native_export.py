"""Validate synthetic resume export QA artifacts with PyMuPDF.

Generate artifacts with BOJIAN_EXPORT_QA=1 flutter test
  test/resume_native_export_test.dart, then run this script with that directory.
PyMuPDF is a QA-only dependency, not an application dependency.
"""
from pathlib import Path
import argparse
import json
import re
import zipfile
import xml.etree.ElementTree as ET

import pymupdf


def check_pdf(path, expected_records=52, decorative_background=False, record_prefix="交付记录"):
    document = pymupdf.open(path)
    text = re.sub(r"\s+", "", "".join(page.get_text() for page in document))
    assert len(document) == 2, f"Unexpected pagination: {path}"
    for index in range(expected_records):
        token = f"{record_prefix}{index:02}"
        assert text.count(token) == 1, f"Lost or duplicated text: {token} in {path}"
    images = []
    bullet_checked = False
    stroked_text = []
    for page in document:
        stroked_text.extend(
            "".join(chr(char[0]) for char in span["chars"])
            for span in page.get_texttrace() if span["type"] == 1
        )
        actual = page.get_image_info()
        large_images = [item for item in actual
                        if pymupdf.Rect(item["bbox"]).get_area() >= page.rect.get_area() * .95]
        if decorative_background:
            assert len(large_images) == 1, "Expected one decorative paint layer per page"
        else:
            assert all(pymupdf.Rect(item["bbox"]).get_area() < page.rect.get_area() * .5
                       for item in actual), f"A page was exported as an image: {path}"
        images.append(len(actual))
        for block in page.get_text("rawdict")["blocks"]:
            for line in block.get("lines", []):
                for span in line["spans"]:
                    for char in span["chars"]:
                        if char["c"] != "•":
                            continue
                        # Cmap aliases (· and •) once produced a visible 'E' while
                        # ToUnicode still said '•'. Check visible ink, not text alone.
                        raster = page.get_pixmap(matrix=pymupdf.Matrix(10, 10),
                                                  clip=pymupdf.Rect(char["bbox"]), alpha=False)
                        points = []
                        for y in range(raster.height):
                            for x in range(raster.width):
                                offset = (y * raster.width + x) * raster.n
                                if min(raster.samples[offset:offset + 3]) < 100:
                                    points.append((x, y))
                        assert points, "Bullet has no visible ink"
                        width = max(x for x, _ in points) - min(x for x, _ in points) + 1
                        height = max(y for _, y in points) - min(y for _, y in points) + 1
                        assert .6 < width / height < 1.5, "Bullet is not round"
                        assert height < span["size"] * 7, "Bullet rendered as another glyph"
                        bullet_checked = True
    if not decorative_background:
        assert images == [1, 0], f"Unexpected pictures: {images} in {path}"
    assert not any("交付记录" in text or "English italic" in text
                   for text in stroked_text), "Bold rendering leaked into regular text"
    return {"pages": len(document), "records": expected_records,
            "displayed_images": images, "bullet_visually_verified": bullet_checked,
            "decoration_only_background": decorative_background}


def check_word(path, decorative_background=False, expected_records=52,
               record_prefix="交付记录", expected_name="林知远"):
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
              "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006"}
        text = "".join(item.text or "" for item in root.findall(".//w:t", ns))
        assert expected_name in text and f"{record_prefix}{expected_records - 1:02}" in text
        assert len(root.findall(".//w:txbxContent/w:p", ns)) > 40, "Editable paragraphs are missing"
        modern_text, legacy_text = [], []
        alternates = root.findall(".//mc:AlternateContent", ns)
        assert alternates, "Missing mobile-reader compatibility branches"
        for alternate in alternates:
            modern = alternate.find("mc:Choice", ns)
            legacy = alternate.find("mc:Fallback", ns)
            assert modern is not None and legacy is not None
            current = [item.text or "" for item in modern.findall(".//w:t", ns)]
            fallback = [item.text or "" for item in legacy.findall(".//w:t", ns)]
            assert current == fallback, "Fallback lost or changed text"
            modern_text.extend(current)
            legacy_text.extend(fallback)
            for branch in (modern, legacy):
                for box in branch.findall(".//w:txbxContent", ns):
                    assert all(item.get(f"{{{ns['w']}}}lineRule") != "exact"
                               for item in box.findall(".//w:spacing", ns)), "Text can be vertically clipped"
        for branch in (modern_text, legacy_text):
            joined = "".join(branch)
            for index in range(expected_records):
                assert joined.count(f"{record_prefix}{index:02}") == 1, "A branch lost or duplicated a record"
        image_count = len([name for name in archive.namelist() if name.startswith("word/media/")])
        assert image_count >= 2 if decorative_background else image_count == 1
        assert archive.getinfo("word/fonts/regular.odttf").file_size > 1000
        font_table = ET.fromstring(archive.read("word/fontTable.xml"))
        if font_table.find(".//w:embedBold", ns) is not None:
            assert archive.getinfo("word/fonts/bold.odttf").file_size > 1000
        names = {item.get(f"{{{ns['w']}}}name") for item in font_table.findall("w:font", ns)}
        for item in root.findall(".//w:rFonts", ns):
            assert item.get(f"{{{ns['w']}}}eastAsia") in names, "Embedded family does not match text"
        faces = []
        for face in ("regular", "medium", "bold"):
            name = f"word/fonts/{face}.odttf"
            if name not in archive.namelist():
                continue
            data = bytearray(archive.read(name))
            for index in range(32):
                data[index] ^= (15 - index % 16) * 17
            original = path.parent / f"{face}.ttf"
            if original.exists():
                assert data == original.read_bytes(), f"Embedded {face} font changed"
            faces.append(face)
    return {"editable_paragraphs": True, "embedded_faces": faces,
            "images": image_count, "decoration_only_background": decorative_background,
            "equivalent_modern_and_legacy_text": True, "records_per_branch": expected_records}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    root = args.directory
    results = {"native_pdf": check_pdf(root / "resume.pdf"),
               "editable_word": check_word(root / "resume.docx")}
    if (root / "market.pdf").exists():
        results["market_pdf"] = check_pdf(root / "market.pdf", decorative_background=True)
        results["market_word"] = check_word(root / "market.docx", decorative_background=True)
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
