import bpy, bmesh, math
from mathutils import Vector, Matrix

def _mat(name, rgb, metal=0.0, rough=0.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m

def build(name):
    """Hex dumbbell along local X, centred on the grip. ~3 kg look."""
    iron = _mat("DB_Iron", (0.025, 0.027, 0.032), 0.6, 0.35)
    grip = _mat("DB_Grip", (0.12, 0.12, 0.13), 0.9, 0.3)
    lime = _mat("DB_Lime", (0.578, 1.0, 0.026), 0.0, 0.4)
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    def cyl(r, depth, x, segs, mat_index):
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=depth,
                                    matrix=Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = mat_index
    cyl(0.016, 0.15, 0, 24, 1)                       # knurled handle
    for s in (-1, 1):
        cyl(0.052, 0.045, s * 0.098, 6, 0)           # hex head
        cyl(0.040, 0.004, s * 0.1225, 6, 2)          # lime end cap (brand accent)
    bm.to_mesh(me); bm.free()
    for m in (iron, grip, lime): me.materials.append(m)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = False
    return o

def attach(rig, side, offset_palm=0.035, offset_along=0.0):
    bones = rig.data.bones
    hand = bones["hand_" + side]
    m1 = bones["middle_01_" + side].head_local
    across = (bones["index_01_" + side].head_local - bones["pinky_01_" + side].head_local).normalized()
    hdir = (m1 - hand.head_local).normalized()
    n = across.cross(hdir).normalized()
    sx = 1 if side == "l" else -1
    if n.x * sx > 0: n = -n                           # same palm convention as fitform_pose
    center = m1 + n * offset_palm + hdir * offset_along
    x = across; z = hdir.cross(x).normalized(); y = z.cross(x)
    world = Matrix.Translation(center) @ Matrix((x, y, z)).transposed().to_4x4()
    name = "Dumbbell_" + side.upper()
    if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name])
    o = build(name)
    o.parent = rig; o.parent_type = "BONE"; o.parent_bone = hand.name
    tail = rig.matrix_world @ hand.matrix_local @ Matrix.Translation((0, hand.length, 0))
    o.matrix_parent_inverse = tail.inverted()
    o.matrix_world = rig.matrix_world @ world   # placed in rest pose
    return o
