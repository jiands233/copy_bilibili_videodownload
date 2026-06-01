#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT_DIR / "Assets"
SIZE = 1024
SCALE = 4


VARIANTS = {
    "AppIcon": {
        "tile": ((255, 255, 255, 255), (229, 241, 255, 255)),
        "tile_shadow": (20, 78, 150, 0),
        "tile_shadow_alpha": 0.20,
        "tile_stroke": (210, 220, 235, 125),
        "inner_stroke": (255, 255, 255, 170),
        "arrow": ((90, 183, 255, 255), (0, 104, 255, 255)),
        "arrow_shadow_alpha": 0.22,
        "tray": ((255, 255, 255, 255), (221, 234, 252, 255)),
        "tray_shadow_alpha": 0.24,
        "slot": ((77, 166, 255, 255), (0, 108, 255, 255)),
        "paper": ((255, 255, 255, 255), (233, 241, 253, 255)),
        "paper_shadow_alpha": 0.30,
        "fold": (248, 251, 255, 255),
    },
    "AppIconDark": {
        "tile": ((54, 65, 82, 255), (12, 18, 30, 255)),
        "tile_shadow": (0, 34, 98, 0),
        "tile_shadow_alpha": 0.34,
        "tile_stroke": (95, 130, 180, 135),
        "inner_stroke": (255, 255, 255, 55),
        "arrow": ((99, 205, 255, 255), (0, 116, 255, 255)),
        "arrow_shadow_alpha": 0.34,
        "tray": ((72, 87, 110, 255), (28, 39, 60, 255)),
        "tray_shadow_alpha": 0.36,
        "slot": ((93, 198, 255, 255), (0, 118, 255, 255)),
        "paper": ((250, 252, 255, 255), (221, 231, 248, 255)),
        "paper_shadow_alpha": 0.40,
        "fold": (242, 247, 255, 255),
    },
    "AppIconTransparent": {
        "tile": ((255, 255, 255, 122), (221, 238, 255, 86)),
        "tile_shadow": (0, 92, 220, 0),
        "tile_shadow_alpha": 0.15,
        "tile_stroke": (255, 255, 255, 175),
        "inner_stroke": (255, 255, 255, 125),
        "arrow": ((94, 196, 255, 250), (0, 112, 255, 250)),
        "arrow_shadow_alpha": 0.25,
        "tray": ((255, 255, 255, 222), (224, 240, 255, 190)),
        "tray_shadow_alpha": 0.22,
        "slot": ((83, 176, 255, 245), (0, 112, 255, 245)),
        "paper": ((255, 255, 255, 238), (235, 245, 255, 218)),
        "paper_shadow_alpha": 0.26,
        "fold": (248, 252, 255, 230),
    },
}


def scaled_box(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(v * SCALE for v in box)


def scaled_point(point: tuple[int, int]) -> tuple[int, int]:
    return point[0] * SCALE, point[1] * SCALE


def gradient(size: tuple[int, int], start: tuple[int, int, int, int], end: tuple[int, int, int, int]) -> Image.Image:
    width, height = size
    column = Image.new("RGBA", (1, height))
    pixels = column.load()
    denominator = max(height - 1, 1)
    for y in range(height):
        t = y / denominator
        pixels[0, y] = tuple(int(start[i] * (1 - t) + end[i] * t) for i in range(4))
    return column.resize((width, height))


def paste_masked(base: Image.Image, layer: Image.Image, mask: Image.Image) -> None:
    base.alpha_composite(Image.composite(layer, Image.new("RGBA", layer.size), mask))


def shadow_from_mask(
    mask: Image.Image,
    color: tuple[int, int, int, int],
    alpha: float,
    blur_radius: int,
    offset: tuple[int, int],
) -> Image.Image:
    shadow = Image.new("RGBA", mask.size, color)
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur_radius * SCALE)).point(lambda p: int(p * alpha)))
    shifted = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    shifted.alpha_composite(shadow, (offset[0] * SCALE, offset[1] * SCALE))
    return shifted


def draw_arrow(mask: Image.Image) -> None:
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(scaled_box((450, 168, 574, 585)), radius=62 * SCALE, fill=255)
    for start, end in [((342, 418), (512, 606)), ((682, 418), (512, 606))]:
        draw.line([scaled_point(start), scaled_point(end)], fill=255, width=124 * SCALE)
        draw.ellipse(scaled_box((start[0] - 62, start[1] - 62, start[0] + 62, start[1] + 62)), fill=255)
    draw.ellipse(scaled_box((450, 545, 574, 669)), fill=255)


def font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        try:
            return ImageFont.truetype(path, 58 * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_icon(name: str, config: dict[str, object]) -> Image.Image:
    canvas_size = (SIZE * SCALE, SIZE * SCALE)
    image = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    tile_mask = Image.new("L", canvas_size, 0)
    tile_draw = ImageDraw.Draw(tile_mask)
    tile_draw.rounded_rectangle(scaled_box((78, 58, 946, 952)), radius=195 * SCALE, fill=255)
    image.alpha_composite(shadow_from_mask(tile_mask, config["tile_shadow"], config["tile_shadow_alpha"], 30, (0, 18)))
    paste_masked(image, gradient(canvas_size, *config["tile"]), tile_mask)
    draw.rounded_rectangle(scaled_box((78, 58, 946, 952)), radius=195 * SCALE, outline=config["tile_stroke"], width=2 * SCALE)
    draw.rounded_rectangle(scaled_box((92, 74, 932, 938)), radius=180 * SCALE, outline=config["inner_stroke"], width=3 * SCALE)

    arrow_mask = Image.new("L", canvas_size, 0)
    draw_arrow(arrow_mask)
    image.alpha_composite(shadow_from_mask(arrow_mask, (0, 72, 200, 0), config["arrow_shadow_alpha"], 14, (0, 9)))
    paste_masked(image, gradient(canvas_size, *config["arrow"]), arrow_mask)

    arrow_highlight = Image.new("L", canvas_size, 0)
    ImageDraw.Draw(arrow_highlight).rounded_rectangle(scaled_box((465, 184, 559, 562)), radius=46 * SCALE, fill=70)
    paste_masked(image, Image.new("RGBA", canvas_size, (255, 255, 255, 78)), arrow_highlight)

    tray_mask = Image.new("L", canvas_size, 0)
    tray_draw = ImageDraw.Draw(tray_mask)
    tray_draw.rounded_rectangle(scaled_box((245, 580, 755, 768)), radius=72 * SCALE, fill=255)
    tray_draw.rounded_rectangle(scaled_box((248, 535, 365, 710)), radius=48 * SCALE, fill=255)
    image.alpha_composite(shadow_from_mask(tray_mask, (35, 80, 150, 0), config["tray_shadow_alpha"], 18, (0, 18)))
    paste_masked(image, gradient(canvas_size, *config["tray"]), tray_mask)
    draw.rounded_rectangle(scaled_box((245, 580, 755, 768)), radius=72 * SCALE, outline=(255, 255, 255, 150), width=2 * SCALE)

    slot_mask = Image.new("L", canvas_size, 0)
    ImageDraw.Draw(slot_mask).rounded_rectangle(scaled_box((302, 593, 706, 650)), radius=24 * SCALE, fill=255)
    paste_masked(image, gradient(canvas_size, *config["slot"]), slot_mask)

    paper_mask = Image.new("L", canvas_size, 0)
    ImageDraw.Draw(paper_mask).rounded_rectangle(scaled_box((585, 520, 828, 826)), radius=40 * SCALE, fill=255)
    image.alpha_composite(shadow_from_mask(paper_mask, (18, 55, 115, 0), config["paper_shadow_alpha"], 18, (8, 14)))
    paste_masked(image, gradient(canvas_size, *config["paper"]), paper_mask)
    draw.rounded_rectangle(scaled_box((585, 520, 828, 826)), radius=40 * SCALE, outline=(190, 205, 226, 140), width=2 * SCALE)

    fold = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    fold_draw = ImageDraw.Draw(fold)
    fold_draw.polygon([scaled_point(point) for point in [(735, 520), (828, 613), (735, 613)]], fill=config["fold"])
    fold_draw.line([scaled_point(point) for point in [(735, 613), (828, 613)]], fill=(190, 205, 226, 100), width=2 * SCALE)
    fold_draw.line([scaled_point(point) for point in [(735, 520), (735, 613)]], fill=(255, 255, 255, 145), width=2 * SCALE)
    image.alpha_composite(fold)

    pill_mask = Image.new("L", canvas_size, 0)
    ImageDraw.Draw(pill_mask).rounded_rectangle(scaled_box((626, 688, 796, 773)), radius=22 * SCALE, fill=255)
    image.alpha_composite(shadow_from_mask(pill_mask, (0, 75, 200, 0), 0.30, 7, (0, 5)))
    paste_masked(image, gradient(canvas_size, (67, 171, 255, 255), (0, 105, 245, 255)), pill_mask)

    label = "MP4"
    text_draw = ImageDraw.Draw(image)
    label_font = font()
    bbox = text_draw.textbbox((0, 0), label, font=label_font)
    x = int((626 + 85) * SCALE - (bbox[2] - bbox[0]) / 2)
    y = int((688 + 42) * SCALE - (bbox[3] - bbox[1]) / 2 - 3 * SCALE)
    text_draw.text((x, y), label, font=label_font, fill=(255, 255, 255, 255))

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_icns(png_path: Path, icns_path: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="bilidown-iconset-") as temporary:
        iconset = Path(temporary) / "AppIcon.iconset"
        iconset.mkdir()
        sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for size, filename in sizes:
            output = iconset / filename
            subprocess.run(["sips", "-z", str(size), str(size), str(png_path), "--out", str(output)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns_path)], check=True)


def make_preview(icons: list[tuple[str, Image.Image]]) -> None:
    preview = Image.new("RGBA", (1500, 560), (245, 248, 252, 255))
    preview_draw = ImageDraw.Draw(preview)
    preview_draw.rounded_rectangle((24, 24, 1476, 536), radius=42, fill=(255, 255, 255, 235), outline=(218, 228, 240, 255), width=2)
    label_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 34)
    labels = ["Default", "Dark", "Transparent"]
    for index, ((_, icon), label) in enumerate(zip(icons, labels)):
        thumb = icon.resize((300, 300), Image.Resampling.LANCZOS)
        x = 150 + index * 420
        preview.alpha_composite(thumb, (x, 88))
        bbox = preview_draw.textbbox((0, 0), label, font=label_font)
        preview_draw.text((x + 150 - (bbox[2] - bbox[0]) / 2, 420), label, font=label_font, fill=(62, 74, 92, 255))
    preview.save(ASSETS_DIR / "AppIconVariants.png")


def main() -> None:
    if not shutil.which("sips") or not shutil.which("iconutil"):
        raise SystemExit("sips and iconutil are required on macOS.")

    ASSETS_DIR.mkdir(exist_ok=True)
    rendered_icons: list[tuple[str, Image.Image]] = []
    for name, config in VARIANTS.items():
        image = draw_icon(name, config)
        png_path = ASSETS_DIR / f"{name}.png"
        icns_path = ASSETS_DIR / f"{name}.icns"
        image.save(png_path)
        make_icns(png_path, icns_path)
        rendered_icons.append((name, image))
        print(f"generated {png_path.relative_to(ROOT_DIR)} and {icns_path.relative_to(ROOT_DIR)}")

    make_preview(rendered_icons)
    print("generated Assets/AppIconVariants.png")


if __name__ == "__main__":
    main()
