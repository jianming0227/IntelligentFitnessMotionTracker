"""Leg-muscle glow (quads + glutes) for the squat, built on the joggers' surface."""
import bpy, bmesh, numpy as np

SURFACE = 0.0015
CLOTH = "FitForm_Human.male_casualsuit06"

def _axis(rig, bone):
    b = rig.data.bones[bone]
    h, t = np.array(b.head_local), np.array(b.tail_local)
    a = t - h; L = np.linalg.norm(a)
    return h, a / L, L

def leg_field(co, rig):
    w = np.zeros(len(co)); radial = np.zeros_like(co); dist = np.zeros(len(co))
    for side in "lr":
        h, ax, L = _axis(rig, "thigh_" + side)
        rel = co - h; tt = rel @ ax / L
        foot = h + np.outer(tt * L, ax)
        r = co - foot; d = np.linalg.norm(r, axis=1) + 1e-9; rn = r / d[:, None]
        same_side = (co[:, 0] * (1 if side == "l" else -1)) > 0.005
        # quads: front of the thigh
        ant = np.clip(-rn[:, 1], 0, 1)
        along = np.where((tt > 0.08) & (tt < 0.92), np.sin(np.pi * (tt - 0.08) / 0.84), 0) ** 1.2
        wq = along * np.clip((ant - 0.30) / 0.5, 0, 1) ** 1.1 * (d < 0.13)
        # glutes: behind the hip joint
        post = np.clip(rn[:, 1], 0, 1)
        prof = np.where((tt > -0.12) & (tt < 0.32), np.cos(np.pi * (tt - 0.10) / 0.44), 0) ** 1.5
        wg = prof * np.clip((post - 0.35) / 0.5, 0, 1) * (d < 0.17) * (co[:, 2] < 0.95)
        ws = np.maximum(wq, wg) * same_side
        better = ws > w
        w[better] = ws[better]
        # every vertex gets the inward direction of its own thigh, even where w == 0,
        # so the glow can always hide under the fabric
        radial[same_side] = rn[same_side]; dist[same_side] = d[same_side]
    return w, radial, dist

def _material(name="LegGlow"):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials["BicepGlow"].copy(); m.name = name
    nt = m.node_tree
    for n in nt.nodes:
        if n.type == "MATH": n.inputs[1].default_value = 0.62            # stronger over dark fabric
        if n.type == "BSDF_PRINCIPLED": n.inputs["Emission Strength"].default_value = 0.9
    return m

def build(rig, name="LegGlow", cuts=2):
    """Overlay = the joggers' quad/glute faces, subdivided for a smooth falloff, then shaped from the field."""
    cloth = bpy.data.objects[CLOTH]
    co = np.array([v.co[:] for v in cloth.data.vertices])
    w0, _, _ = leg_field(co, rig)
    keep = (w0 > 0.0) & (co[:, 2] < 0.97)
    if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name])
    bm = bmesh.new(); bm.from_mesh(cloth.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not any(keep[v.index] for v in f.verts)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)   # skin weights interpolate
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ov = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ov); ov.parent = rig
    for g in cloth.vertex_groups: ov.vertex_groups.new(name=g.name)          # same order -> same deform indices
    ov.modifiers.new("Armature", "ARMATURE").object = rig
    base = np.array([v.co[:] for v in me.vertices])
    w, n, dist = leg_field(base, rig)
    wv = np.clip(w, 0, 1)
    depth = 0.12 * np.maximum(dist, 0.03)          # uniform: surfaces all at once (no streaks)
    rest = base - n * depth[:, None]
    me.vertices.foreach_set("co", rest.ravel())
    ov.shape_key_add(name="Basis", from_mix=False)
    ov.shape_key_add(name="Glow", from_mix=False).data.foreach_set("co", (base + n * SURFACE).ravel())
    for ca in list(me.color_attributes): me.color_attributes.remove(ca)   # inherited MPFB colours would become COLOR_0
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    a = np.clip(wv / 0.75, 0, 1) ** 1.8
    col.data.foreach_set("color", np.column_stack([np.ones_like(a)] * 3 + [a]).ravel())
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    me.materials.append(_material())
    for p in me.polygons: p.use_smooth = True
    return int(keep.sum()), len(me.vertices)
