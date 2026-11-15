"""Genera game/web/loading_shell.html (la plantilla web de Godot con la pantalla de carga del cohete).

    python tools/build_loading_shell.py

Parte de game/web/loading_shell.template.html y le mete, como data URI, las imágenes de la Tierra, la Luna, Marte
y el cohete (game/Images/) y la fuente del título. Así la pantalla de carga no necesita ficheros aparte junto a
index.html. Hay que ejecutarlo cada vez que se cambie la plantilla o alguna de esas imágenes y antes de exportar
el juego a web (el preset Web de game/export_presets.cfg usa res://web/loading_shell.html).
"""
import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"

ASSETS = {
    "@@EARTH@@": (GAME / "Images" / "tierra.png", "image/png"),
    "@@MOON@@": (GAME / "Images" / "luna.png", "image/png"),
    "@@MARS@@": (GAME / "Images" / "Marte.png", "image/png"),
    "@@ROCKET@@": (GAME / "Images" / "Cohete.png", "image/png"),
    "@@FONT@@": (GAME / "TextFonts" / "sixtyfour" / "static" / "sixtyfour-latin-400-normal.woff2", "font/woff2"),
}


def data_uri(path: Path, mime: str) -> str:
    return "data:%s;base64,%s" % (mime, base64.b64encode(path.read_bytes()).decode("ascii"))


def main() -> None:
    template = (GAME / "web" / "loading_shell.template.html").read_text(encoding="utf-8")
    for marker, (path, mime) in ASSETS.items():
        if marker not in template:
            raise SystemExit("Falta el marcador %s en la plantilla" % marker)
        template = template.replace(marker, data_uri(path, mime))
    out = GAME / "web" / "loading_shell.html"
    out.write_text(template, encoding="utf-8", newline="\n")
    print("Escrito %s (%d KB)" % (out.relative_to(ROOT), out.stat().st_size // 1024))


if __name__ == "__main__":
    main()
