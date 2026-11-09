"""Air-squat posing for the MPFB game_engine rig (armature space == world)."""
import bpy, math
from mathutils import Vector, Matrix
import fitform_pose as fp

D = math.radians

def _rest(name):
    return fp.rig().data.bones[name]

def place(pb, head, rot3):
    pb.matrix = Matrix.Translation(head) @ rot3.to_4x4(); fp.upd()

def leg_ik(side, hip):
    """Two-bone IK: thigh/calf so the ankle stays at its rest spot, knee pushed forward over the toes."""
    P = fp.rig().pose.bones
    th, ca = _rest("thigh_" + side), _rest("calf_" + side)
    L1, L2 = th.length, ca.length
    A = ca.tail_local.copy()                          # ankle, planted
    v = A - hip; d = min(v.length, L1 + L2 - 1e-4); u = v.normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)         # distance hip->knee projection along u
    h = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = Vector((0.12 if side == "l" else -0.12, -1, 0))   # forward, slightly out (toes/knees out)
    pole = (pole - u * pole.dot(u)).normalized()
    K = hip + u * a + pole * h
    fp.aim(P["thigh_" + side], K - hip)
    fp.aim(P["calf_" + side], A - K)
    # foot keeps its rest orientation (flat, heel down)
    foot = _rest("foot_" + side)
    place(P["foot_" + side], P["foot_" + side].head.copy(), foot.matrix_local.to_3x3())

def squat_pose(d):
    """d: 0 standing tall -> 1 bottom (thighs about parallel)."""
    fp.reset(); P = fp.rig().pose.bones
    # pelvis: down and back, slight forward hinge
    pel = _rest("pelvis")
    hip_drop, hip_back, hinge = 0.38 * d, 0.20 * d, D(18) * d
    head = pel.head_local + Vector((0, hip_back, -hip_drop))
    place(P["pelvis"], head, Matrix.Rotation(hinge, 3, "X") @ pel.matrix_local.to_3x3())
    for s in "lr":
        hip = P["thigh_" + s].head.copy()
        leg_ik(s, hip)
    # spine: total chest lean ~38 deg at the bottom (forward = +X rotation for upward bones)
    lean = D(38) * d
    for name, part in (("spine_01", 0.45), ("spine_02", 0.75), ("spine_03", 1.0)):
        fp.aim(P[name], (0, -math.sin(lean * part), math.cos(lean * part)))
    # head looks ahead, not at the floor
    fp.aim(P["neck_01"], (0, -math.sin(lean * 0.6), math.cos(lean * 0.6)))
    fp.aim(P["head"], (0, -0.08, 1))
    # arms raise forward to shoulder height for balance, palms down
    g = D(8 + 80 * d)
    for s, sx in (("l", 1), ("r", -1)):
        dirv = Vector((sx * 0.10, -math.sin(g), -math.cos(g)))
        fp.aim(P["upperarm_" + s], dirv)
        palm = Vector((0, math.cos(g), -math.sin(g)))
        fp.orient_forearm(P["lowerarm_" + s], s, dirv + Vector((0, -0.05, 0.02)), palm)
    # flat hands in line with the forearms (no dangling claws)
    for s_ in "lr":
        fp.aim(P["hand_" + s_], P["lowerarm_" + s_].tail - P["lowerarm_" + s_].head)
    fp.grip(0.08, "X", 1)
