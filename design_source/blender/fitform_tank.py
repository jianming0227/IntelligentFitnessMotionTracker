"""Turns MakeHuman's male_casualsuit06 tee into a tank top with a rounded armhole."""
import bpy, bmesh, glob, os, numpy as np

YC, ZC, RY, RZ = -0.012, 1.30, 0.075, 0.17      # bottom ~1.13 (armpit), top ~1.47 (over the shoulder)     # armhole ellipse on the torso side (y-z plane)
X_SIDE, X_SEAM = 0.12, 0.165                     # side surface starts / shoulder seam (sleeve beyond)

def ell(y, z, grow=0.0):
    return ((y - YC) / (RY + grow)) ** 2 + ((z - ZC) / (RZ + grow)) ** 2

def cut_mask(x, y, z):
    ax = abs(x)
    return ax > X_SEAM and z > 1.05 or (ax > X_SIDE and (ell(y, z) < 1.0 or z > 1.38))   # above 1.38 only the strap stays

def reload_tee(fh):
    HS = fh.HumanService; body = fh.basemesh()
    old = bpy.data.objects.get("FitForm_Human.male_casualsuit06")
    if old:
        try: HS.unload_mhclo_asset(body, old)
        except Exception: bpy.data.objects.remove(old, do_unlink=True)
    for m in [m for m in body.modifiers if m.name == "Delete.male_casualsuit06"]: body.modifiers.remove(m)
    g = body.vertex_groups.get("Delete.male_casualsuit06")
    if g: body.vertex_groups.remove(g)
    mhclo = glob.glob(os.path.join(fh.asset("clothes", "male_casualsuit06"), "*.mhclo"))[0]
    tee = HS.add_mhclo_asset(mhclo, body, asset_type="Clothes", subdiv_levels=0, material_type="MAKESKIN")
    nt = tee.material_slots[0].material.node_tree
    nt.nodes["diffuseTexture"].image = bpy.data.images["fitform_suit_diffuse"]
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for l in list(bsdf.inputs["Alpha"].links): nt.links.remove(l)
    bsdf.inputs["Alpha"].default_value = 1.0
    return tee, body

Z_TOP, SLOPE = 1.45, 0.14   # front/back edge: x = X_SIDE + SLOPE * (Z_TOP - z), from strap down to the armpit

def edge_x(z):
    return X_SIDE + SLOPE * max(Z_TOP - z, 0.0)

def cut(tee):
    from mathutils import Vector
    bm = bmesh.new(); bm.from_mesh(tee.data)
    # 1. more resolution around the armholes so the curve is smooth
    zone = [e for e in bm.edges if all(v.co.z > 1.04 and abs(v.co.x) > 0.09 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=zone, cuts=2, use_grid_fill=True)
    # 2. front/back edge: one sloped plane per side (clean straight line from strap to armpit)
    for sx in (1, -1):
        faces = [f for f in bm.faces if f.calc_center_median().z > 1.10]
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
        n = Vector((sx, 0, SLOPE)).normalized()          # inside: x < X_SIDE + SLOPE*(Z_TOP - z)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(sx * X_SIDE, 0, Z_TOP), plane_no=n, clear_outer=True)
    # 3. the round scoop: slice the side along a 24-segment ellipse, then drop what's inside
    import math
    N = 24
    pts = [(YC + RY * math.cos(2 * math.pi * i / N), ZC + RZ * math.sin(2 * math.pi * i / N)) for i in range(N)]
    for sx in (1, -1):
        for i in range(N):
            (y0, z0), (y1, z1) = pts[i], pts[(i + 1) % N]
            dy, dz = y1 - y0, z1 - z0; L = math.hypot(dy, dz)
            my, mz = (y0 + y1) / 2, (z0 + z1) / 2
            faces = [f for f in bm.faces if sx * f.calc_center_median().x > 0.10
                     and math.hypot(f.calc_center_median().y - my, f.calc_center_median().z - mz) < L * 0.5 + 0.03]
            if not faces: continue
            geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, y0, z0), plane_no=Vector((0, -dz, dy)).normalized())
    def inside_poly(y, z):
        c = False
        for i in range(N):
            (y0, z0), (y1, z1) = pts[i], pts[(i + 1) % N]
            if (z0 > z) != (z1 > z) and y < y0 + (z - z0) * (y1 - y0) / (z1 - z0): c = not c
        return c
    def gone(c):
        ax = abs(c.x)
        return (ax > X_SEAM and c.z > 1.05) or (ax > X_SIDE and inside_poly(c.y, c.z))
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if gone(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for _ in range(3):
        sp = [f for f in bm.faces if f.calc_center_median().z > 1.05 and abs(f.calc_center_median().x) > 0.1
              and sum(1 for e in f.edges if e.is_boundary) >= 2 and f.calc_area() < 2e-5]
        if not sp: break
        bmesh.ops.delete(bm, geom=sp, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    snapped = 0
    bm.to_mesh(tee.data); bm.free(); tee.data.update()
    return snapped

def bind_to_chest(tee):
    """Side fabric follows the chest, not the arm (stops flaps at the armpit)."""
    vg = tee.vertex_groups; names = {g.index: g.name for g in vg}
    arm = [g for g in vg if g.name.startswith(("upperarm_", "clavicle_"))]
    spine = vg.get("spine_03") or vg.new(name="spine_03"); moved = 0
    for v in tee.data.vertices:
        if not (0.98 < v.co.z < 1.40 and abs(v.co.x) > 0.08): continue
        w_arm = sum(gr.weight for gr in v.groups if names.get(gr.group, "").startswith(("upperarm_", "clavicle_")))
        if w_arm <= 0: continue
        keep = 0.0                                    # full weight to the chest: partial weights leave points behind (spikes)
        for g in arm:
            try:
                w = g.weight(v.index)
                if g.name.startswith("clavicle_") and keep: g.add([v.index], w * keep, "REPLACE")
                else: g.remove([v.index])
            except RuntimeError: pass
        spine.add([v.index], w_arm * (1 - keep), "ADD"); moved += 1
    return moved

def reveal_skin(body, mix_co):
    x, y, z = np.abs(mix_co[:, 0]), mix_co[:, 1], mix_co[:, 2]
    e = ((y - YC) / (RY + 0.012)) ** 2 + ((z - ZC) / (RZ + 0.012)) ** 2
    ex = X_SIDE + SLOPE * np.clip(Z_TOP - z, 0, None)
    show = np.nonzero(((x > X_SIDE - 0.006) & (e < 1.0)) | ((x > ex - 0.006) & (z > 1.10)) | ((x > 0.17) & (z > 1.08)))[0].tolist()
    body.vertex_groups["Delete.male_casualsuit06"].remove(show)
    return len(show)

def solid_torso(body, tee, lift=0.005, smooth_iters=6):
    """Keep the real upper body under the tank (no see-through holes at the armholes), lift the tank a few mm
    off the skin so the skin can't poke through, and smooth the stair-steps out of the armhole edges."""
    g = body.vertex_groups["Delete.male_casualsuit06"]
    upper = [v.index for v in body.data.vertices if v.co.z > 0.0]   # placeholder, replaced below with mix coords
    import fitform_bicep as fb
    co = fb.mix_coords(body)
    keep_hidden_below = 1.0                       # jeans region stays masked (waistband and down)
    show = [int(i) for i in np.nonzero(co[:, 2] > keep_hidden_below)[0]]
    g.remove(show)
    bm = bmesh.new(); bm.from_mesh(tee.data); bm.verts.ensure_lookup_table()
    # lift: away from the torso's centre line (upward-outward over the shoulders)
    for v in bm.verts:
        if v.co.z <= 0.98: continue
        c = v.co.copy(); c.x = 0.0; c.y = -0.005; c.z = min(v.co.z, 1.30)
        d = v.co - c
        if d.length > 1e-6: v.co += d.normalized() * lift
    # smooth the armhole/strap boundary (move each edge point toward its two boundary neighbours)
    for _ in range(smooth_iters):
        new = {}
        for v in bm.verts:
            if not v.is_boundary or v.co.z < 1.05 or abs(v.co.x) < 0.07: continue
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2:
                new[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, p in new.items(): v.co = p
    bm.to_mesh(tee.data); bm.free(); tee.data.update()
    return len(show)
