from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "svnly-app-icon-1024.png"
CATALOG = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
LAUNCH = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

source = Image.open(SOURCE).convert("RGB")
source = source.resize((1024, 1024), Image.Resampling.LANCZOS)
source.save(SOURCE, "PNG", optimize=True)
for filename, size in SIZES.items():
    source.resize((size, size), Image.Resampling.LANCZOS).save(
        CATALOG / filename, "PNG", optimize=True
    )
for scale, filename in [(1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")]:
    canvas = Image.new("RGB", (200 * scale, 200 * scale), "#05070A")
    mark = source.resize((168 * scale, 168 * scale), Image.Resampling.LANCZOS)
    canvas.paste(mark, (16 * scale, 16 * scale))
    canvas.save(LAUNCH / filename, "PNG", optimize=True)
print(f"Generated {len(SIZES)} production icons and 3 launch assets.")
