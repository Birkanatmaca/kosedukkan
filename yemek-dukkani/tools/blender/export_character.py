import bpy, sys, os
argv = sys.argv[sys.argv.index("--")+1:]
sys.path.insert(0, os.path.dirname(__file__))
import faces  # aynı klasördeki faces.py
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name != 'geometry_0':
        bpy.data.objects.remove(o)
me = bpy.data.objects['geometry_0']
profile = argv[2] if len(argv) > 2 else "erkek"
if profile != "yok":  # "yok": yüz mimiği eklenmez (ör. temizlikçi)
    faces.add_faces(me, profile)
if me.data.shape_keys:
    for kb in me.data.shape_keys.key_blocks: kb.value = 0
for img in bpy.data.images:
    if img.size[0] > 1024: img.scale(1024, 1024)
bpy.ops.export_scene.gltf(filepath=argv[1], export_format='GLB', export_morph=True, export_morph_normal=False,
    export_skins=True, export_animations=True, export_animation_mode='ACTIONS',
    export_image_format='JPEG', export_jpeg_quality=85, export_apply=False)
print("EXPORTED", os.path.getsize(argv[1]))
