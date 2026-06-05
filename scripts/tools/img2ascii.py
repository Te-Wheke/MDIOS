from PIL import Image

src = 'Untitled design_20260529_143130_0000.png'
out = "whekeos-logo.txt"

chars = "@%#*+=-:. "

img = Image.open(src).convert("L")
width = 100
ratio = img.height / img.width
height = int(width * ratio * 0.45)

img = img.resize((width, height))

text = ""
for y in range(img.height):
    for x in range(img.width):
        p = img.getpixel((x, y))
        text += chars[p * len(chars) // 256]
    text += "\n"

open(out, "w").write(text)
print(f"saved: {out}")
