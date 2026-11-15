"""Monta el vídeo promocional de 20 s (1920x1080, 60 fps, sin audio) con los clips de OBS y el arte del juego.

    python promo/build_promo.py promo/promo_20s.mp4

Necesita OpenCV, NumPy y Pillow. Los clips se leen de la carpeta SRC (cámbiala si los mueves).

Guion: cohete que abre la pantalla como una cremallera -> inicio del juego -> NFC y QR (pantalla partida) ->
elegir rol y lobby -> aterrizaje en Marte -> partida -> debate y voto (pantalla partida) -> cierre fijo.
"""
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS, SECONDS = 1920, 1080, 60, 20.0
SRC = r"C:\Users\nikon\Downloads\videos\videos obs"
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(os.path.dirname(HERE), "game")
FONT = os.path.join(GAME, "TextFonts", "sixtyfour", "static", "sixtyfour-latin-400-normal.ttf")
DARK = (20, 11, 8)                 # BGR del fondo del cierre (#080b14)
ORANGE = (30, 122, 255)            # BGR
CYAN = (230, 168, 42)


def imread(path, flags=cv2.IMREAD_UNCHANGED):
    return cv2.imdecode(np.fromfile(path, np.uint8), flags)


def clip_path(start):
    for name in os.listdir(SRC):
        if name.lower().endswith(".mp4") and name.lower().startswith(start.lower()):
            return os.path.join(SRC, name)
    raise SystemExit("No encuentro el clip que empieza por " + start)


class Clip:
    """Lector con acceso por tiempo (los accesos van casi siempre hacia delante)."""

    def __init__(self, start, rotate=None):
        self.path = clip_path(start)
        self.rotate = rotate
        self.cap = cv2.VideoCapture(self.path)
        self.fps = self.cap.get(cv2.CAP_PROP_FPS)
        self.count = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.index = -1
        self.frame = None

    def at(self, seconds):
        target = int(min(max(seconds, 0.0) * self.fps, self.count - 2))
        if target < self.index or self.frame is None:
            self.cap.release()
            self.cap = cv2.VideoCapture(self.path)
            self.index = -1
        while self.index < target:
            ok, frame = self.cap.read()
            if not ok:
                break
            self.index += 1
            self.frame = frame
        frame = self.frame
        if self.rotate is not None:
            frame = cv2.rotate(frame, self.rotate)
        return frame


# ---------------------------------------------------------------- utilidades de composición

def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ease_out(x):
    x = clamp(x)
    return 1 - (1 - x) ** 3


def cover(img, w=W, h=H, cx=0.5, cy=0.5, zoom=1.0):
    """Escala para llenar w x h recortando lo que sobre (cx, cy = punto que se mantiene centrado)."""
    ih, iw = img.shape[:2]
    scale = max(w / iw, h / ih) * zoom
    cw, ch = w / scale, h / scale
    x0 = clamp(cx * iw - cw / 2, 0, iw - cw)
    y0 = clamp(cy * ih - ch / 2, 0, ih - ch)
    crop = img[int(y0):int(y0 + ch), int(x0):int(x0 + cw)]
    return cv2.resize(crop, (w, h), interpolation=cv2.INTER_CUBIC if scale > 1 else cv2.INTER_AREA)


def blurred_fill(img):
    small = cover(img, 96, 54)
    small = cv2.GaussianBlur(small, (0, 0), 3)
    big = cv2.resize(small, (W, H), interpolation=cv2.INTER_CUBIC)
    return (big * 0.45).astype(np.uint8)


def paste(dst, src, x, y, clip_x0=0, clip_x1=W):
    """Pega src en dst en (x, y), recortando a la pantalla y a [clip_x0, clip_x1)."""
    h, w = src.shape[:2]
    x0, y0 = max(int(x), clip_x0, 0), max(int(y), 0)
    x1, y1 = min(int(x) + w, clip_x1, W), min(int(y) + h, H)
    if x1 <= x0 or y1 <= y0:
        return
    dst[y0:y1, x0:x1] = src[y0 - int(y):y1 - int(y), x0 - int(x):x1 - int(x)]


def overlay(dst, rgba, x, y, alpha=1.0):
    """Pega una imagen BGRA con transparencia."""
    h, w = rgba.shape[:2]
    x, y = int(round(x)), int(round(y))
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    if x1 <= x0 or y1 <= y0:
        return
    part = rgba[y0 - y:y1 - y, x0 - x:x1 - x]
    a = (part[:, :, 3:4].astype(np.float32) / 255.0) * alpha
    dst[y0:y1, x0:x1] = (dst[y0:y1, x0:x1] * (1 - a) + part[:, :, :3] * a).astype(np.uint8)


def mix(a, b, k):
    k = clamp(k)
    if k <= 0:
        return a
    if k >= 1:
        return b
    return cv2.addWeighted(a, 1 - k, b, k, 0)


def flash(img, color, k):
    k = clamp(k)
    if k <= 0:
        return img
    return cv2.addWeighted(img, 1 - k, np.full_like(img, color), k, 0)


def sprite(path, scale):
    img = imread(path)
    return cv2.resize(img, (img.shape[1] * scale, img.shape[0] * scale), interpolation=cv2.INTER_NEAREST)


_caption_cache = {}


def caption(text, size=30):
    """Rótulo con la fuente del juego: caja oscura con barra naranja."""
    key = (text, size)
    if key not in _caption_cache:
        font = ImageFont.truetype(FONT, size)
        box = font.getbbox(text)
        tw, th = box[2] - box[0], box[3] - box[1]
        pad = 20
        img = Image.new("RGBA", (tw + pad * 2 + 12, th + pad * 2), (8, 11, 20, 225))
        draw = ImageDraw.Draw(img)
        draw.rectangle([0, 0, 9, img.height], fill=(255, 122, 30, 255))
        draw.text((pad + 12 - box[0], pad - box[1]), text, font=font, fill=(255, 238, 190, 255))
        _caption_cache[key] = cv2.cvtColor(np.array(img), cv2.COLOR_RGBA2BGRA)
    return _caption_cache[key]


def put_caption(frame, text, local_t, duration, x=70, y=None, size=30, align="left"):
    """Rótulo que entra deslizándose y se va al final del tramo."""
    img = caption(text, size)
    k = ease_out(local_t / 0.25) * ease_out((duration - local_t) / 0.15)
    if k <= 0:
        return
    if y is None:
        y = H - 130 - img.shape[0]
    if align == "right":
        x = W - x - img.shape[1]
    elif align == "center":
        x = x - img.shape[1] // 2
    overlay(frame, img, x - (1 - k) * 60 * (1 if align != "right" else -1), y, k)


# ---------------------------------------------------------------- recursos

landing = Clip("Pantalla")
nfc = Clip("EntrarNFC")
qr = Clip("EscaneQR")
roles = Clip("Selecci\u00f3n de rol m", rotate=cv2.ROTATE_90_CLOCKWISE)
lobby = Clip("Selecci\u00f3n de rol j")
gameplay = Clip("video gameplay")
talk = Clip("Charla")

outro = cover(imread(os.path.join(SRC, "Imagen est\u00e1tica final.png"))[:, :, :3])
cursor_rocket = sprite(os.path.join(GAME, "Images", "Raton.png"), 10)          # cohete en diagonal (240 px)
rocket_sheet = sprite(os.path.join(GAME, "Images", "Cohete.png"), 8)           # 2 fotogramas de 192x320
rocket_frames = [rocket_sheet[:, :192], rocket_sheet[:, 192:]]
orbit = imread(os.path.join(GAME, "Images", "MonsCloud_MarsExpress_1920.jpg"), cv2.IMREAD_COLOR)
surface = cv2.resize(imread(os.path.join(HERE, "mars_surface.png"), cv2.IMREAD_COLOR), (W, H),
    interpolation=cv2.INTER_CUBIC)   # paisaje de Marte del juego (recorte de una captura)
GROUND_Y = 800                                                                   # altura del suelo en `surface`

rng = np.random.default_rng(4)
stars = np.full((H, W, 3), DARK, np.uint8)
for sx, sy, sb in zip(rng.integers(0, W, 260), rng.integers(0, H, 260), rng.integers(70, 230, 260)):
    cv2.rectangle(stars, (int(sx), int(sy)), (int(sx) + 2, int(sy) + 2), (int(sb), int(sb), int(sb)), -1)

# geometría de la «cremallera»: distancia de cada píxel a la diagonal y posición a lo largo de ella
A = np.array([-170.0, H + 170.0])
B = np.array([W + 170.0, -170.0])
AB = B - A
LEN = float(np.linalg.norm(AB))
DIR = AB / LEN
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
along = ((xx - A[0]) * DIR[0] + (yy - A[1]) * DIR[1]) / LEN
across = np.abs((xx - A[0]) * DIR[1] - (yy - A[1]) * DIR[0])
ROCKET_START, ROCKET_TRAVEL = 0.12, 1.15

dust_seed = rng.random((70, 4))   # ángulo, velocidad, tamaño, retraso


# ---------------------------------------------------------------- escenas

def scene_zipper(t):
    """0-2 s: el cohete cruza en diagonal y su estela abre la pantalla como una cremallera."""
    under = cover(landing.at(0.05 + t * 0.5))
    pass_time = ROCKET_START + np.clip(along, 0, 1) * ROCKET_TRAVEL
    opened = np.clip(t - pass_time, 0, None)
    half_width = 720.0 * opened ** 1.25
    mask = across < half_width
    frame = np.where(mask[:, :, None], under, stars)

    # borde brillante de la abertura
    edge = (np.abs(across - half_width) < 7) & (opened > 0)
    glow = cv2.GaussianBlur(edge.astype(np.float32), (0, 0), 9)
    frame = np.clip(frame + glow[:, :, None] * np.array(ORANGE, np.float32) * 1.6, 0, 255).astype(np.uint8)
    frame[edge] = (200, 235, 255)

    p = (t - ROCKET_START) / ROCKET_TRAVEL
    if -0.05 < p < 1.12:
        pos = A + AB * p
        for k in range(1, 16):          # estela de fuego
            tail = pos - DIR * (60 + k * 34)
            radius = max(3, int(30 - k * 1.7))
            color = (40, int(210 - k * 9), 255) if k < 6 else (30, int(150 - k * 5), int(255 - k * 6))
            cv2.circle(frame, (int(tail[0]), int(tail[1])), radius, color, -1, cv2.LINE_AA)
        overlay(frame, cursor_rocket, pos[0] - 120, pos[1] - 120)
    return frame


def scene_intro(t):
    """2-2,5 s: destello y arranque del juego (de la portada a «How do you want to play?»)."""
    lt = t - 2.0
    frame = cover(landing.at(1.05 + lt * 2.1), zoom=1.06 - 0.06 * ease_out(lt / 0.4))
    return flash(frame, (255, 255, 255), 0.85 * (1 - lt / 0.2))


def scene_join(t):
    """2,5-3,5 s: entrar con NFC; a la mitad la pantalla se parte y a la derecha se escanea el QR."""
    lt = t - 2.5
    src = nfc.at(1.5 + lt * 1.3)
    k = ease_out((lt - 0.5) / 0.14)

    # NFC: llena toda la pantalla y, al partirse, se queda con la mitad izquierda
    frame = cover(src, cy=0.46)
    if k > 0:
        paste(frame, cover(src, 960, H, cy=0.46), 0, 0, 0, int(W - 960 * k))

    if k > 0:
        right = cover(qr.at(2.3 + (lt - 0.5) * 1.5), 960, H, cy=0.47)
        x_right = 960 + (1 - k) * 960
        paste(frame, right, x_right, 0)
        cv2.rectangle(frame, (int(x_right) - 4, 0), (int(x_right) + 4, H), (255, 255, 255), -1)
        put_caption(frame, "TAP THE NFC TAG", lt - 0.5, 0.5, x=60, size=24)
        put_caption(frame, "OR SCAN THE QR", lt - 0.5, 0.5, x=60, size=24, align="right")
    else:
        put_caption(frame, "JOIN WITH YOUR PHONE", lt, 0.5, x=60, size=26)
    return flash(frame, (255, 255, 255), 0.5 * (1 - lt / 0.12))


def scene_roles(t):
    """3,5-5,3 s: los móviles eligen rol (acercándose a la pantalla)."""
    lt = t - 3.5
    frame = cover(roles.at(0.2 + lt * 1.9), cx=0.42, cy=0.52, zoom=1.0 + 0.16 * ease(lt / 1.8))
    put_caption(frame, "PICK YOUR JOB", lt, 1.8)
    return flash(frame, (255, 255, 255), 0.45 * (1 - lt / 0.12))


def scene_lobby(t):
    """5,3-7 s: el lobby con toda la tripulación conectada (la cámara se aleja)."""
    lt = t - 5.3
    frame = cover(lobby.at(0.75 + lt * 0.95), zoom=1.12 - 0.12 * ease_out(lt / 0.7))
    if lt < 0.25:
        frame = mix(scene_roles(5.2999), frame, lt / 0.25)
    put_caption(frame, "THE CREW IS READY", lt, 1.7)
    return frame


def draw_dust(frame, origin, lt, strength):
    """Nube de polvo rojo que sale del punto de aterrizaje."""
    layer = frame.copy()
    for angle, speed, size, delay in dust_seed:
        age = lt - delay * 0.25
        if age <= 0:
            continue
        direction = math.pi * (0.05 + 0.9 * angle)          # hacia arriba y a los lados
        dist = (240 + 900 * speed) * ease_out(age / 1.0)
        x = origin[0] + math.cos(direction) * dist * 1.5
        y = origin[1] - math.sin(direction) * dist * 0.55
        radius = int((40 + 150 * size) * (0.4 + ease_out(age / 0.9)))
        shade = 0.75 + 0.25 * size
        cv2.circle(layer, (int(x), int(y)), radius, (int(70 * shade), int(120 * shade), int(205 * shade)), -1, cv2.LINE_AA)
    layer = cv2.GaussianBlur(layer, (0, 0), 14)
    return mix(frame, layer, strength)


def scene_landing(t):
    """7-11 s: del lobby al descenso sobre Marte; el polvo del aterrizaje se despeja y aparece la partida."""
    lt = t - 7.0
    flame = rocket_frames[int(t * 14) % 2]
    if lt < 1.5:
        # llegada desde la órbita: Marte se acerca muy rápido
        zoom = 1.0 + 2.6 * (lt / 1.5) ** 2
        shake = np.array([math.sin(t * 61), math.cos(t * 47)]) * (2 + 10 * lt)
        frame = cover(orbit, cx=0.52 + shake[0] / W, cy=0.55 + shake[1] / H, zoom=zoom)
        frame = flash(frame, (60, 110, 200), 0.25 * ease(lt / 1.5))
        overlay(frame, flame, W / 2 - 96 + shake[0] * 2, -330 + 620 * ease(lt / 1.5) + shake[1] * 2)
        if lt < 0.3:
            frame = mix(scene_lobby(6.9999), frame, lt / 0.3)
        frame = flash(frame, (120, 170, 240), ease((lt - 1.3) / 0.2))
    elif lt < 3.5:
        # descenso final y toma de tierra en el paisaje del juego
        st = lt - 1.5
        touchdown = 1.45
        frame = surface.copy()
        y = -340 + (GROUND_Y - 232 + 340) * ease_out(st / touchdown)
        shake = math.sin(t * 70) * (6 if st < touchdown else 14 * clamp(1 - (st - touchdown) / 0.4))
        if st < touchdown:
            overlay(frame, flame, W / 2 - 96, y + shake)
            near = ease((st - 0.75) / 0.7)
            if near > 0:
                frame = draw_dust(frame, (W / 2, GROUND_Y + 10), (st - 0.75) * 0.6, 0.55 * near)
        else:
            overlay(frame, rocket_frames[0][:232], W / 2 - 96, GROUND_Y - 232 + shake)   # sin llama
            frame = draw_dust(frame, (W / 2, GROUND_Y + 10), 0.42 + (st - touchdown), 0.9)
        frame = flash(frame, (120, 170, 240), 1 - ease(st / 0.25))
        put_caption(frame, "LAND ON MARS", st, 1.6)
        frame = flash(frame, (96, 150, 222), ease((st - touchdown - 0.05) / 0.5))       # el polvo lo tapa todo
    else:
        # el polvo se despeja y aparece la pantalla de la partida
        st = lt - 3.5
        frame = flash(cover(gameplay.at(1.3)), (96, 150, 222), 1 - ease(st / 0.5))
    return frame


def scene_game(t):
    """11-14 s: la pantalla principal de la partida."""
    lt = t - 11.0
    frame = cover(gameplay.at(1.3 + lt * 1.4))
    put_caption(frame, "SURVIVE 20 SOLS TOGETHER", lt, 3.0, x=555, y=70, size=26, align="center")
    return frame


def scene_debate(t):
    """14-18 s: la tripulación debate; después media pantalla enseña el toque final en el móvil."""
    lt = t - 14.0
    split = 1.7
    if lt < split:
        frame = cover(talk.at(0.45 + lt), cy=0.42)
        put_caption(frame, "TALK IT OVER", lt, split)
        return flash(frame, (255, 255, 255), 0.4 * (1 - lt / 0.12))
    st = lt - split
    k = ease_out(st / 0.22)
    src = talk.at(0.45 + split + st * 0.5)
    full = cover(src, cy=0.42)
    left = cover(src, 960, H, cx=0.52, cy=0.42)
    frame = full.copy()
    if k < 1:
        # la imagen completa se va estrechando hacia la mitad izquierda
        frame = mix(full, np.hstack([left, full[:, 960:]]), k)
    else:
        frame = np.hstack([left, full[:, 960:]])
    if st < 1.15:
        right = cover(nfc.at(7.2 + st * 0.6), 960, H, cx=0.62, cy=0.36, zoom=1.15)
    else:
        right = cover(roles.at(0.75 + (st - 1.15) * 0.8), 960, H, cx=0.24, cy=0.5, zoom=1.25)
        right = flash(right, (255, 255, 255), 0.4 * (1 - (st - 1.15) / 0.12))
    x_right = 960 + (1 - k) * 960
    paste(frame, right, x_right, 0)
    cv2.rectangle(frame, (int(x_right) - 4, 0), (int(x_right) + 4, H), (255, 255, 255), -1)
    put_caption(frame, "THEN DECIDE", st, 2.3, x=60, size=28, align="right")
    return frame


def render(t):
    if t < 2.0:
        return scene_zipper(t)
    if t < 2.5:
        return scene_intro(t)
    if t < 3.5:
        return scene_join(t)
    if t < 5.3:
        return scene_roles(t)
    if t < 7.0:
        return scene_lobby(t)
    if t < 11.0:
        return scene_landing(t)
    if t < 14.0:
        return scene_game(t)
    if t < 18.0:
        return scene_debate(t)
    return outro


def main():
    out_path = sys.argv[1]
    preview_dir = sys.argv[2] if len(sys.argv) > 2 else None
    if preview_dir and len(sys.argv) > 3:
        # solo fotogramas sueltos: python build_promo.py salida carpeta 0.5,1.2,...
        for value in sys.argv[3].split(","):
            t = float(value)
            cv2.imencode(".jpg", cv2.resize(render(t), (960, 540)))[1].tofile(os.path.join(preview_dir, "f_%05.2f.jpg" % t))
        return
    writer = cv2.VideoWriter(out_path, cv2.CAP_MSMF, cv2.VideoWriter_fourcc(*"avc1"), float(FPS), (W, H))
    if not writer.isOpened():
        raise SystemExit("No se pudo abrir el codificador H.264")
    total = int(SECONDS * FPS)
    for i in range(total):
        frame = render(i / FPS)
        writer.write(np.ascontiguousarray(frame))
        if i % 120 == 0:
            print("  %2d s / %d s" % (i // FPS, int(SECONDS)), flush=True)
    writer.release()
    print("Escrito", os.path.getsize(out_path) // 1024, "KB")


if __name__ == "__main__":
    main()
