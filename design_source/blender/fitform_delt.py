"""Shoulder (deltoid) glow overlay, DeltGlow, for the shoulder press and lateral raise.
Built like fitform_bicep's BicepGlow: the deltoid faces of the body as their own skinned mesh, tucked under
the skin at rest; the "Glow" shape key lifts them just above it. Same lime, emissive, soft-alpha material."""
import bpy, bmesh, numpy as np
import fitform_bicep as fb

SURFACE = 0.0012

def delt_field(body, rig):
    """Per-vertex weight (0..1) and outward direction for both deltoids, in rest space."""
    co = fb.mix_coords(body)
    w = np.zeros(len(co)); radial = np.zeros_like(co); dist = np.zeros(len(co))
    for side, sx in (("l", 1), ("r", -1)):
        b = rig.data.bones["upperarm_" + side]
        h, t = np.array(b.head_local), np.array(b.tail_local)
        axis = t - h; L = np.linalg.norm(axis); axis /= L
        rel = co - h; tt = rel @ axis / L
        foot = h + np.outer(np.clip(tt, 0, None) * L, axis)       # above the joint: measure from the joint itself
        r = co - foot; d = np.linalg.norm(r, axis=1) + 1e-9; rn = r / d[:, None]
        # cap over the joint: from just above the shoulder to ~45% down the upper arm
        along = np.where((tt > -0.30) & (tt < 0.48), np.cos(np.pi * (tt - 0.09) / 0.78), 0) ** 1.3
        # outward/up-facing side only (not the armpit or the inner arm)
        out = np.array([sx, 0, 0.55]); out /= np.linalg.norm(out)
        face = np.clip((rn @ out + 0.25) / 0.8, 0, 1) ** 1.2
        near = d < 0.095
        lateral = co[:, 0] * sx > abs(h[0]) - 0.035                 # stay off the chest/neck
        ws = along * face * near * lateral
        better = ws > w
        w[better] = ws[better]; radial[better] = rn[better]; dist[better] = d[better]
    return co, w, radial, dist

def build(body, rig, name="DeltGlow"):
    co, w, radial, dist = delt_field(body, rig)
    if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name])
    keep = w > 0.02
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    idx_layer = bm.verts.layers.int.new("src")
    for v in bm.verts: v[idx_layer] = v.index
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(keep[v.index] for v in f.verts)], context="FACES")
    for layer in list(bm.verts.layers.shape): bm.verts.layers.shape.remove(layer)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    src = np.zeros(len(me.vertices), dtype=np.int64); me.attributes["src"].data.foreach_get("value", src)
    me.attributes.remove(me.attributes["src"])
    ov = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ov); ov.parent = rig
    for g in body.vertex_groups: ov.vertex_groups.new(name=g.name)
    gmap = {g.index: g.name for g in body.vertex_groups}
    for i, s in enumerate(src):
        for gref in body.data.vertices[s].groups:
            ov.vertex_groups[gmap[gref.group]].add([i], gref.weight, "REPLACE")
    ov.modifiers.new("Armature", "ARMATURE").object = rig
    wv = w[src]; n = radial[src]; base = co[src]; dv = dist[src]
    depth = 0.12 * np.maximum(dv, 0.03)            # uniform sink: surfaces all at once (no streaks)
    rest = base - n * depth[:, None]
    me.vertices.foreach_set("co", rest.ravel())
    ov.shape_key_add(name="Basis", from_mix=False)
    ov.shape_key_add(name="Glow", from_mix=False).data.foreach_set("co", (rest + n * (depth + SURFACE)[:, None]).ravel())
    for ca in list(me.color_attributes): me.color_attributes.remove(ca)
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    a = np.clip(wv / 0.8, 0, 1) ** 2.0
    col.data.foreach_set("color", np.column_stack([np.ones_like(a)] * 3 + [a]).ravel())
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    me.materials.append(bpy.data.materials["BicepGlow"])          # same lime as the bicep
    for p in me.polygons: p.use_smooth = True
    return int(keep.sum()), len(me.vertices)
