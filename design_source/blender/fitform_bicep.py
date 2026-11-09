"""Bicep bulge (BicepFlex shape key) + emerging glow overlay (BicepGlow) for the FitForm human."""
import bpy, bmesh, math, numpy as np
from mathutils import Vector

BULGE = 0.009        # metres of radial swell at the bicep peak
SURFACE = 0.001     # how far the glow sits above the flexed skin
LIME = (0.578, 1.0, 0.026, 1)

def mix_coords(body):
    k = body.shape_key_add(name="__tmp", from_mix=True)
    co = np.zeros(len(body.data.vertices) * 3); k.data.foreach_get("co", co)
    body.shape_key_remove(k)
    return co.reshape(-1, 3)

def bicep_field(body, rig):
    """Per-vertex weight (0..1) and radial direction for both biceps, in rest space."""
    co = mix_coords(body)
    w = np.zeros(len(co)); radial = np.zeros_like(co); dist = np.zeros(len(co))
    for side in "lr":
        b = rig.data.bones["upperarm_" + side]
        h, t = np.array(b.head_local), np.array(b.tail_local)
        axis = t - h; L = np.linalg.norm(axis); axis /= L
        rel = co - h
        tt = rel @ axis / L
        foot = h + np.outer(tt * L, axis)
        r = co - foot; d = np.linalg.norm(r, axis=1) + 1e-9; rn = r / d[:, None]
        # anterior = facing forward (-Y) in the A-pose rest
        ant = np.clip(-rn[:, 1], 0, 1)
        along = np.where((tt > 0.12) & (tt < 0.92), np.sin(np.pi * (tt - 0.12) / 0.80), 0) ** 1.4
        near = d < 0.085
        ws = along * np.clip((ant - 0.15) / 0.6, 0, 1) ** 1.2 * near
        better = ws > w
        w[better] = ws[better]; radial[better] = rn[better]; dist[better] = d[better]
    return co, w, radial, dist

def build(body, rig):
    # measure the skin WITHOUT any previous bulge (a re-run would otherwise bake it in)
    old = body.data.shape_keys.key_blocks.get("BicepFlex")
    if old: body.shape_key_remove(old)
    co, w, radial, dist = bicep_field(body, rig)
    # 1. BicepFlex shape key on the body
    sk = body.data.shape_keys
    if "BicepFlex" in sk.key_blocks: body.shape_key_remove(sk.key_blocks["BicepFlex"])
    basis = np.zeros(len(co) * 3); sk.reference_key.data.foreach_get("co", basis); basis = basis.reshape(-1, 3)
    flex = body.shape_key_add(name="BicepFlex", from_mix=False)
    flex.data.foreach_set("co", (basis + radial * (BULGE * w)[:, None]).ravel())
    flex.slider_min, flex.slider_max = 0, 1
    # 2. BicepGlow overlay: the bicep faces of the body, as their own skinned mesh
    if "BicepGlow" in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects["BicepGlow"])
    keep = w > 0.02
    bm = bmesh.new(); bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    idx_layer = bm.verts.layers.int.new("src")      # tag BEFORE deleting: indices renumber afterwards
    for v in bm.verts: v[idx_layer] = v.index
    dead = [f for f in bm.faces if not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    for layer in list(bm.verts.layers.shape): bm.verts.layers.shape.remove(layer)
    loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context="VERTS")
    me = bpy.data.meshes.new("BicepGlow")
    bm.to_mesh(me); bm.free()
    src = np.zeros(len(me.vertices), dtype=np.int64); me.attributes["src"].data.foreach_get("value", src)
    ov = bpy.data.objects.new("BicepGlow", me); bpy.context.scene.collection.objects.link(ov)
    ov.parent = rig
    # skin weights copied from the body
    for g in body.vertex_groups:
        ng = ov.vertex_groups.new(name=g.name)
    gmap = {g.index: g.name for g in body.vertex_groups}
    for i, s in enumerate(src):
        for gref in body.data.vertices[s].groups:
            ov.vertex_groups[gmap[gref.group]].add([i], gref.weight, "REPLACE")
    mod = ov.modifiers.new("Armature", "ARMATURE"); mod.object = rig
    # positions: tucked 3-10 mm under the skin (centre shallowest); the "Glow" key lifts each
    # vertex radially to SURFACE above the (flexed) skin; "Flex" mirrors the body's bulge.
    wv = w[src]; n = radial[src]; base = co[src]; dv = dist[src]
    k = np.full_like(wv, 0.12)                      # uniform sink: the whole patch surfaces at once (no half-surfaced streaks)
    depth = k * dv
    rest = base - n * depth[:, None]                # toward the upper-arm bone axis
    me.vertices.foreach_set("co", rest.ravel())
    ov.shape_key_add(name="Basis", from_mix=False)
    flex_k = ov.shape_key_add(name="Flex", from_mix=False)
    flex_k.data.foreach_set("co", (rest + n * (BULGE * wv)[:, None]).ravel())
    glow = ov.shape_key_add(name="Glow", from_mix=False)
    glow.data.foreach_set("co", (rest + n * (depth + SURFACE)[:, None]).ravel())
    # soft edge: vertex alpha follows the bicep weight
    for ca in list(me.color_attributes): me.color_attributes.remove(ca)   # inherited MPFB colours would become COLOR_0
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    a = np.clip(wv / 0.8, 0, 1) ** 2.0
    rgba = np.column_stack([np.ones(len(a)), np.ones(len(a)), np.ones(len(a)), a])
    col.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    # material: lime, emissive, alpha-blended
    m = bpy.data.materials.get("BicepGlow") or bpy.data.materials.new("BicepGlow")
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "Col"
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 0.62
    bs.inputs["Base Color"].default_value = LIME
    bs.inputs["Emission Color"].default_value = LIME
    bs.inputs["Emission Strength"].default_value = 0.9
    bs.inputs["Roughness"].default_value = 0.6
    nt.links.new(ca.outputs["Alpha"], mul.inputs[0]); nt.links.new(mul.outputs[0], bs.inputs["Alpha"])
    nt.links.new(bs.outputs[0], out.inputs[0])
    m.surface_render_method = "BLENDED"
    me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return int(keep.sum()), len(me.vertices)

def glow_value(c):
    """Glow on once the curl is ~1/3 up, off again on the way down. A short, steep switch: a slow ramp left the
    glow half-surfaced through the skin for many frames, which showed as thin lime streaks on the phone."""
    t = min(max((c - 0.25) / 0.12, 0.0), 1.0)
    return t * t * (3 - 2 * t)

def animate(action, curl_values, step=3):
    """Key the bulge (body + overlay) and the glow into the same action as the arms."""
    body = bpy.data.objects["FitForm_Human"]; ov = bpy.data.objects["BicepGlow"]
    N = len(curl_values)
    for ob, keys in ((body, {"BicepFlex": lambda c: c}), (ov, {"Flex": lambda c: c, "Glow": glow_value})):
        sk = ob.data.shape_keys
        if sk.animation_data: sk.animation_data_clear()
        sk.animation_data_create(); sk.animation_data.action = action
        for name, fn in keys.items():
            kb = sk.key_blocks[name]
            for f in list(range(0, N, step)) + [N - 1, N]:
                kb.value = fn(curl_values[f % N]); kb.keyframe_insert("value", frame=f)
