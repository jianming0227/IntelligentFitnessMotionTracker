"""Export the FitForm human to a mobile .glb, keeping the bicep morph targets.
Works on the open file destructively, so call reload_master() afterwards."""
import bpy, bmesh, os, numpy as np

MASTER = r"C:\Users\ljmwa\Desktop\fitness\design_source\fitform_tutorial_master.blend"
KEEP_KEYS = {"BicepFlex", "Flex", "Glow"}

def bake_body_shape(ob):
    sk = ob.data.shape_keys
    if not sk: return
    keep = [k for k in sk.key_blocks if k.name in KEEP_KEYS]
    if not keep:
        mix = ob.shape_key_add(name="__mix", from_mix=True)
        co = np.zeros(len(ob.data.vertices) * 3); mix.data.foreach_get("co", co)
        ob.shape_key_clear(); ob.data.vertices.foreach_set("co", co); ob.data.update(); return
    ref = sk.reference_key
    n = len(ob.data.vertices)
    base = np.zeros(n * 3); ref.data.foreach_get("co", base)
    deltas = {}
    for k in keep:
        c = np.zeros(n * 3); k.data.foreach_get("co", c); deltas[k.name] = c - base
        k.value = 0.0
    mix = ob.shape_key_add(name="__mix", from_mix=True)
    m = np.zeros(n * 3); mix.data.foreach_get("co", m)
    for k in list(sk.key_blocks):
        if k.name not in KEEP_KEYS and k != ref: ob.shape_key_remove(k)
    ref.data.foreach_set("co", m); ob.data.vertices.foreach_set("co", m)
    for k in sk.key_blocks:
        if k.name in deltas: k.data.foreach_set("co", m + deltas[k.name])
    ob.data.update()
    print("baked", ob.name, "kept", list(deltas))

def apply_masks(ob):
    masks = [md for md in ob.modifiers if md.type == "MASK"]
    if not masks: return
    keep = np.ones(len(ob.data.vertices), dtype=bool)
    for md in masks:
        g = ob.vertex_groups.get(md.vertex_group)
        inside = np.zeros(len(keep), dtype=bool)
        if g:
            for v in ob.data.vertices:
                for gr in v.groups:
                    if gr.group == g.index and gr.weight > md.threshold: inside[v.index] = True
        keep &= ~inside if md.invert_vertex_group else inside
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep[v.index]], context="VERTS")
    bm.to_mesh(ob.data); bm.free()
    for md in masks: ob.modifiers.remove(md)
    print("masked", ob.name, "kept verts", int(keep.sum()))

EXERCISES = {
    # glb name: (rig action, objects left out, shape keys dropped)
    "bicep_curl": ("BicepCurl", ("LegGlow",), ()),
    "squat": ("Squat", ("Dumbbell_L", "Dumbbell_R", "BicepGlow"), ("BicepFlex",)),
}

def prepare(exercise):
    action, drop, drop_keys = EXERCISES[exercise]
    rig = bpy.data.objects["FitForm_Rig"]
    rig.animation_data.action = bpy.data.actions[action]
    for name in drop:
        if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    for o in rig.children_recursive:
        sk = o.data.shape_keys if o.type == "MESH" else None
        if not sk: continue
        hit = [k for k in drop_keys if k in sk.key_blocks]
        if hit:                                     # only the mesh that owns the dropped keys
            if sk.animation_data: sk.animation_data_clear()
            for k in hit: o.shape_key_remove(sk.key_blocks[k])
    for o in bpy.data.objects: o.hide_viewport = False

def export(out, exercise="bicep_curl"):
    prepare(exercise)
    rig = bpy.data.objects["FitForm_Rig"]
    objs = [rig] + list(rig.children_recursive)
    for o in objs:
        if o.type == "MESH":
            bake_body_shape(o); apply_masks(o)
            for md in [md for md in o.modifiers if md.type not in ("ARMATURE",)]:
                print("dropping modifier", o.name, md.type); o.modifiers.remove(md)
    for img in bpy.data.images:
        if img.size[0] > 1024: img.scale(1024, max(1, int(1024 * img.size[1] / img.size[0])))
    for o in bpy.data.objects: o.select_set(o in objs)
    bpy.context.view_layer.objects.active = rig
    bpy.context.scene.frame_set(0)
    res = bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False,
        export_animations=True, export_animation_mode="ACTIVE_ACTIONS", export_skins=True,
        export_morph=True, export_morph_normal=True, export_morph_animation=True,
        export_vertex_color="ACTIVE", export_yup=True, export_force_sampling=True,
        export_draco_mesh_compression_enable=False, export_image_format="WEBP")
    import importlib, glb_tools; importlib.reload(glb_tools)
    glb_tools.rename_animations(out, EXERCISES[exercise][0])   # exporter names it "Animation"
    glb_tools.promote_glow_alpha(out)                          # soft glow edges (see glb_tools)
    print(res, "bytes", os.path.getsize(out))

def reload_master():
    bpy.ops.wm.open_mainfile(filepath=MASTER)
