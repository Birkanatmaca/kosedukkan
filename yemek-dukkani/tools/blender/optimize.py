## Meshy modellerini mobile uygun hale getirir: üçgen azaltma, doku küçültme,
## gerçek boyuta ölçekleme, pivotu tabana alma. Kaynak: Downloads'taki orijinaller.
import bpy, sys, os, math, mathutils
argv = sys.argv[sys.argv.index("--")+1:]
src, dst, tris, tex, axis, meters, preview = argv[0], argv[1], int(argv[2]), int(argv[3]), argv[4], float(argv[5]), argv[6]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in list(bpy.data.objects):
    if o != ob: bpy.data.objects.remove(o)
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Doku dikişlerinde ayrık duran noktaları birleştir (UV'ler köşe başına saklandığı için bozulmaz),
# yoksa sadeleştirme dikişlerden yırtılır.
import bmesh
bm = bmesh.new(); bm.from_mesh(ob.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.to_mesh(ob.data); bm.free()
before = sum(len(p.vertices) - 2 for p in ob.data.polygons)
# Kenarı üstünde duran düz objeleri (tepsi) yatır: en ince eksen yukarı baksın.
dims = ob.dimensions.copy()
# flatflip: aynısı, ama önü (Meshy'nin ön yüzü) yukarı bakar (ör. ızgara izli köfte).
if axis in ("flat", "flatflip"):
    sign = -1 if axis == "flatflip" else 1
    thin = min(range(3), key=lambda i: dims[i])
    if thin == 0: ob.data.transform(mathutils.Matrix.Rotation(math.radians(90 * sign), 4, 'Y'))
    elif thin == 1: ob.data.transform(mathutils.Matrix.Rotation(math.radians(90 * sign), 4, 'X'))
    ob.data.update()
if before > tris:
    mod = ob.modifiers.new("dec", 'DECIMATE'); mod.ratio = tris / before; mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
after = sum(len(p.vertices) - 2 for p in ob.data.polygons)
# Ölçek: h = yükseklik, l = en uzun yatay kenar
d = ob.dimensions
size = d.z if axis == "h" else max(d.x, d.y)
s = meters / size
ob.scale = (s, s, s); bpy.ops.object.transform_apply(scale=True)
# Pivot: tabanın ortası
bb = [ob.matrix_world @ mathutils.Vector(c) for c in ob.bound_box]
cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2; cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2; mz = min(v.z for v in bb)
for v in ob.data.vertices: v.co -= mathutils.Vector((cx, cy, mz))
# Materyal: sadece renk dokusu kalsın; metal/pürüzlülük dokusu atılır.
for mat in ob.data.materials:
    if not mat or not mat.use_nodes: continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bsdf: continue
    for name in ("Metallic", "Roughness"):
        for link in list(bsdf.inputs[name].links): mat.node_tree.links.remove(link)
    bsdf.inputs["Metallic"].default_value = 0.0; bsdf.inputs["Roughness"].default_value = 0.75
    nrm = bsdf.inputs["Normal"]
    for link in list(nrm.links): mat.node_tree.links.remove(link)
if len(argv) > 7 and not any(m and m.use_nodes and any(n.type == 'TEX_IMAGE' for n in m.node_tree.nodes) for m in ob.data.materials):
    mat = bpy.data.materials.new("renk"); mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = tuple(int(argv[7][i:i+2], 16) / 255 for i in (0, 2, 4)) + (1,)
    b.inputs["Roughness"].default_value = 0.6
    ob.data.materials.clear(); ob.data.materials.append(mat)
for img in list(bpy.data.images):
    if img.users == 0: bpy.data.images.remove(img); continue
    if img.size[0] > tex: img.scale(tex, tex)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=85,
    export_animations=False, export_skins=False, export_morph=False, use_selection=False)
print("RESULT", os.path.basename(dst), before, "->", after, "tris |", tuple(round(x, 3) for x in ob.dimensions), "|", os.path.getsize(dst) // 1024, "KB")
# Önizleme
sc = bpy.context.scene
d = ob.dimensions; r = max(d) * 1.4
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = r
cam.location = (r * 0.9, -r * 1.2, d.z / 2 + r * 0.7)
cam.rotation_euler = (mathutils.Vector((0, 0, d.z / 2)) - cam.location).to_track_quat('-Z', 'Y').to_euler(); sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = sc.render.resolution_y = 300
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[1].default_value = 2.0
sc.view_settings.view_transform = 'Standard'; sc.render.filepath = preview; bpy.ops.render.render(write_still=True)
