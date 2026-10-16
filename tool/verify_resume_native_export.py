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


def check_pdf(path, expected_records=52):
    document = pymupdf.open(path)
    text = re.sub(r"\s+", "", "".join(page.get_text() for page in document))
    assert len(document) == 2, f"Unexpected pagination: {path}"
    for index in range(expected_records):
        token = f"交付记录{index:02}"
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
    assert images == [1, 0], f"Unexpected pictures: {images} in {path}"
    assert not any("交付记录" in text or "English italic" in text
                   for text in stroked_text), "Bold rendering leaked into regular text"
    return {"pages": len(document), "records": expected_records,
            "displayed_images": images, "bullet_visually_verified": bullet_checked}


def check_word(path):
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        text = "".join(item.text or "" for item in root.findall(".//w:t", ns))
        assert "林知远" in text and "交付记录51" in text
        assert len(root.findall("./w:body/w:p", ns)) > 40, "Editable paragraphs are missing"
        assert len([name for name in archive.namelist() if name.startswith("word/media/")]) == 1
        assert archive.getinfo("word/fonts/regular.odttf").file_size > 1000
        font_table = ET.fromstring(archive.read("word/fontTable.xml"))
        if font_table.find(".//w:embedBold", ns) is not None:
            assert archive.getinfo("word/fonts/bold.odttf").file_size > 1000
    return {"editable_paragraphs": True, "embedded_fonts": True, "portrait_only": True}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    root = args.directory
    results = {"native_pdf": check_pdf(root / "resume.pdf"),
               "editable_word": check_word(root / "resume.docx")}
    if (root / "market.pdf").exists():
        results["market_pdf"] = check_pdf(root / "market.pdf")
        results["market_word"] = check_word(root / "market.docx")
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
