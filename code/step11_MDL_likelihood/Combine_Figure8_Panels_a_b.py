from PIL import Image, ImageDraw, ImageFont

SRC_COMBINED = "combined_MDL_PMF_RainWetness_300dpi.png"   # existing, unmodified panel (a) lives here
PANEL_B      = "panel_b_with_delta_axis_300dpi.png"        # freshly rendered, updated panel (b)
OUT          = "combined_MDL_PMF_RainWetness_with_deltaEP_300dpi.png"

src = Image.open(SRC_COMBINED).convert("RGB")
W, H = src.size
print("source combined size:", src.size)

# Panel (a) occupies the left ~45.36% of the original combined image
# (a_width=2850, gap=32, b_width=3400 in the original compose script;
# 2850/6282 = 0.45368). Crop panel (a) out of the existing, still-valid
# rendering -- it is not being changed.
a_frac = 2850.0 / (2850.0 + 32.0 + 3400.0)
a_w = round(W * a_frac)
panel_a = src.crop((0, 0, a_w, H))
print("cropped panel (a):", panel_a.size)

# Upscale panel (a) to a clean working height, then build panel (b) at a
# matching height so the two sit at comparable visual scale.
target_h = 2400
panel_a = panel_a.resize((round(panel_a.width * target_h / panel_a.height), target_h),
                          Image.Resampling.LANCZOS)

panel_b = Image.open(PANEL_B).convert("RGB")
panel_b = panel_b.resize((round(panel_b.width * target_h / panel_b.height), target_h),
                          Image.Resampling.LANCZOS)

gap = 40
canvas = Image.new("RGB", (panel_a.width + gap + panel_b.width, target_h), "white")
canvas.paste(panel_a, (0, 0))
canvas.paste(panel_b, (panel_a.width + gap, 0))

font_path = "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"
font = ImageFont.truetype(font_path, 78)
draw = ImageDraw.Draw(canvas)
draw.text((24, 22), "(a)", fill="black", font=font)
draw.text((panel_a.width + gap + 22, 22), "(b)", fill="black", font=font)

canvas.save(OUT, format="PNG", dpi=(300, 300))
print("Saved:", OUT, canvas.size)
