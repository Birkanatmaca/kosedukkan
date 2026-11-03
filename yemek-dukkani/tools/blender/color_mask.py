## Karakter dokusu için renk bölgesi maskesi çıkarır:
## R = ten, G = saç, B = üst giysi, A = pantolon. Profil: erkek (varsayılan) ya da kadin. Oyunda shader bu bölgeleri yeniden boyar.
## Renk tek başına yetmez (gölgedeki ten ceket rengine, göz bebeği saç rengine yakın),
## bu yüzden her üçgenin hangi kemiğe bağlı olduğu da hesaba katılır.
import bpy, sys, numpy as np, colorsys
argv = sys.argv[sys.argv.index("--")+1:]
src, out, size = argv[0], argv[1], int(argv[2])
profile = argv[3] if len(argv) > 3 else "erkek"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = bpy.data.objects['geometry_0']; me = ob.data
img = [i for i in bpy.data.images if i.size[0] > 0][0]
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]
if W != size:
    # en yakın komşu ile küçült
    ys = (np.arange(size) * H / size).astype(int); xs = (np.arange(size) * W / size).astype(int)
    px = px[ys][:, xs]
N = size
r, g, b = px[..., 0], px[..., 1], px[..., 2]
mx = px.max(-1); mn = px.min(-1); v = mx; s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
d = np.maximum(mx - mn, 1e-6)
h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
# Not: 8 bitlik dokularda Blender pikselleri zaten sRGB değerleri verir.
def to_srgb(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)
sr = px; r, g, b = sr[..., 0], sr[..., 1], sr[..., 2]
mx = sr.max(-1); mn = sr.min(-1); v = mx; d = np.maximum(mx - mn, 1e-6); s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60

# Üçgen bölgeleri: 0 yok, 1 baş, 2 el, 3 gövde/kol, 4 bacak/ayak
groups = {vg.index: vg.name for vg in ob.vertex_groups}
def cat(name):
    n = name.split(':')[-1]
    if n in ('Head', 'HeadTop_End', 'headfront', 'Neck'): return 1
    if 'Hand' in n: return 2
    if 'Leg' in n or 'Foot' in n or 'Toe' in n: return 4
    return 3
vcat = []
for vtx in me.vertices:
    w = [0, 0, 0, 0, 0]
    for ge in vtx.groups: w[cat(groups[ge.group])] += ge.weight
    vcat.append(w)
region = np.zeros((N, N), np.uint8); face_front = np.zeros((N, N), bool)
uv = me.uv_layers.active.data
me.calc_loop_triangles()
for tri in me.loop_triangles:
    w = np.sum([vcat[i] for i in tri.vertices], axis=0); c = int(np.argmax(w))
    co = [me.vertices[i].co for i in tri.vertices]
    front = c == 1 and all(p.y < -0.05 and 1.3 < p.z < 1.56 and abs(p.x) < 0.13 for p in co)
    t = np.array([uv[l].uv[:] for l in tri.loops]) * N
    x0, y0 = np.floor(t.min(0)).astype(int); x1, y1 = np.ceil(t.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, N - 1), min(y1, N - 1)
    if x1 < x0 or y1 < y0: continue
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = t
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9: continue
    l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
    l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
    inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
    sub = region[y0:y1 + 1, x0:x1 + 1]; sub[inside] = c
    if front: face_front[y0:y1 + 1, x0:x1 + 1] |= inside

skinish = (h > 3) & (h < 40) & (s > 0.2) & (s < 0.75) & (v > 0.45)
dark = ((v < 0.33) & (s < 0.55)) | (v < 0.22)
body = (region == 2) | (region == 3) | (region == 4)
extra = None
if profile == "temizlikci":
    # Temizlikçi: açık yeşil gömlek, koyu petrol pantolon, koyu yeşil önlük, mavi eldiven.
    # Önlük ve eldiven dükkan rengine boyanır; ikinci maskeye yazılır (R önlük, G eldiven).
    gloves = ((region == 2) | (region == 3)) & (h > 190) & (h < 215) & (s > 0.45) & (v > 0.55)
    apron = ((region == 3) | (region == 4)) & (h > 118) & (h < 178) & (s > 0.45) & (v > 0.15) & (v < 0.5)
    shirt = (region == 3) & (h > 95) & (h < 145) & (s > 0.15) & (s < 0.55) & (v > 0.45)
    pants = (region == 4) & (h > 168) & (h < 222) & (s > 0.45) & (v < 0.4)
    skin = ((region == 1) | (region == 2) | (region == 3)) & skinish
    hair = (region == 1) & dark & ~face_front
    jacket, jeans = shirt, pants
    extra = np.zeros((N, N, 4), np.float32)
    extra[..., 0] = apron; extra[..., 1] = gloves; extra[..., 3] = 1.0
else:
    # Üst giysinin rengi karaktere göre: erkekte turuncu ceket, kadında hardal hırka.
    if profile == "kadin":
        orange = (h > 28) & (h < 58) & (s > 0.45) & (v > 0.25)
    else:
        orange = ((h < 30) | (h > 350)) & (s > 0.6) & (v > 0.3) & (v < 0.85)
    blue = (h > 190) & (h < 235) & (s > 0.3)
    # Ceket kemik bölgesine göre gövdede, bel/etekte (bacak kemiği) ve manşette (el kemiği) olabilir.
    skin = ((region == 1) | (region == 2) | (region == 3)) & skinish & ~(orange & body)
    hair = (region == 1) & dark & ~face_front
    jacket = body & orange
    jeans = (region == 4) & blue
mask = np.zeros((N, N, 4), np.float32)
mask[..., 0] = skin; mask[..., 1] = hair; mask[..., 2] = jacket; mask[..., 3] = jeans
# Ada kenarlarında doku süzmesi karışmasın diye maskeyi birkaç piksel genişlet
def grow(m):
    for _ in range(3):
        g = m.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            g = np.maximum(g, np.roll(np.roll(m, dy, 0), dx, 1) * (region == 0)[..., None])
        m = g
    return m


def save(m, path):
    img = bpy.data.images.new("mask", N, N, alpha=True)
    img.colorspace_settings.name = 'Non-Color'
    img.pixels = m.ravel()  # Blender pikselleri alttan başlar, dizimiz de öyle
    img.filepath_raw = path; img.file_format = 'PNG'; img.save()


mask = grow(mask)
print("COVER skin %.3f hair %.3f top %.3f pants %.3f" % tuple(mask[..., i].mean() for i in range(4)))
save(mask, out)
if extra is not None:
    extra = grow(extra)
    print("COVER2 apron %.3f gloves %.3f" % (extra[..., 0].mean(), extra[..., 1].mean()))
    save(extra, out.replace(".png", "_2.png"))
