"""Готовит папку web/ для установки на iPhone как приложения:
название, черная тема, иконка-полумесяц, настройки для экрана "Домой".
Запускается в облачной сборке после `flutter create --platforms=web .`
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw

WEB = sys.argv[1] if len(sys.argv) > 1 else "web"
NAME = "Моя Музыка"


def make_icon(size, padding=0.0, rounded=False):
    """Полумесяц на черном фоне. padding - отступ (для maskable-иконки)."""
    s = 1024
    img = Image.new("RGB", (s, s), (0, 0, 0))
    d = ImageDraw.Draw(img)
    k = 1 - padding * 2
    cx, cy, r = s * (0.5 + (0.47 - 0.5) * k), s * (0.5 + (0.53 - 0.5) * k), s * 0.30 * k
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(237, 237, 237))
    cr = r * 0.86
    ox, oy = cx + s * 0.13 * k, cy - s * 0.08 * k
    d.ellipse((ox - cr, oy - cr, ox + cr, oy + cr), fill=(0, 0, 0))
    sr = s * 0.022 * k
    sx, sy = s * (0.5 + 0.20 * k), s * (0.5 - 0.20 * k)
    d.ellipse((sx - sr, sy - sr, sx + sr, sy + sr), fill=(140, 140, 140))
    return img.resize((size, size), Image.LANCZOS)


def save(path, img):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


# --- иконки
save(f"{WEB}/icons/Icon-192.png", make_icon(192))
save(f"{WEB}/icons/Icon-512.png", make_icon(512))
save(f"{WEB}/icons/Icon-maskable-192.png", make_icon(192, padding=0.10))
save(f"{WEB}/icons/Icon-maskable-512.png", make_icon(512, padding=0.10))
save(f"{WEB}/icons/apple-touch-icon.png", make_icon(180))
save(f"{WEB}/favicon.png", make_icon(48))

# --- manifest.json
mpath = f"{WEB}/manifest.json"
try:
    with open(mpath, encoding="utf-8") as f:
        m = json.load(f)
except Exception:
    m = {}
m.update({
    "name": NAME,
    "short_name": NAME,
    "start_url": ".",
    "display": "standalone",
    "background_color": "#000000",
    "theme_color": "#000000",
    "description": "Неофициальный клиент Яндекс Музыки",
    "orientation": "any",
    "icons": [
        {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
        {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
        {"src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
        {"src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
    ],
})
with open(mpath, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=2)

# --- index.html
ipath = f"{WEB}/index.html"
with open(ipath, encoding="utf-8") as f:
    html = f.read()

html = re.sub(r"<title>.*?</title>", f"<title>{NAME}</title>", html, flags=re.S)

# убираем то, что добавим сами, чтобы не было дублей
for pat in [
    r'<meta name="apple-mobile-web-app-[^>]*>\s*',
    r'<link rel="apple-touch-icon"[^>]*>\s*',
    r'<meta name="theme-color"[^>]*>\s*',
    r'<meta name="viewport"[^>]*>\s*',
    r'<meta name="mobile-web-app-capable"[^>]*>\s*',
]:
    html = re.sub(pat, "", html)

extra = f"""  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="#000000">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="{NAME}">
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
  <style>
    html,body{{background:#000;margin:0}}
    /* Известный баг iOS: в приложении с экрана "Домой" поля ввода иногда перестают
       реагировать на касания, пока их не "разбудить" так. Подробности:
       https://developer.apple.com/forums/thread/700736
       https://developer.apple.com/forums/thread/705685 */
    input, textarea {{
      -webkit-user-select: text !important;
      user-select: text !important;
      transform: translateZ(0);
    }}
  </style>
"""
if "</head>" not in html:
    sys.exit("index.html: не найден </head>")
html = html.replace("</head>", extra + "</head>", 1)
with open(ipath, "w", encoding="utf-8") as f:
    f.write(html)

print("web_setup: ok")
