"""Bicep-curl posing for the MPFB game_engine rig (armature space, world == armature)."""
import bpy, math
from mathutils import Vector, Matrix, Quaternion

RIG = "FitForm_Rig"

def rig():
    return bpy.data.objects[RIG]

def upd():
    bpy.context.view_layer.update()

def reset():
    r = rig()
    for pb in r.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    upd()

def aim(pb, d):
    """Minimal rotation so the bone points along world direction d."""
    d = Vector(d).normalized()
    m = pb.matrix.copy()
    cur = m.col[1].xyz.normalized()
    q = cur.rotation_difference(d)
    rot = q.to_matrix() @ m.to_3x3()
    pb.matrix = Matrix.Translation(m.translation) @ rot.to_4x4()
    upd()

def frame(y, p):
    y = y.normalized(); p = (p - y * p.dot(y)).normalized()
    return Matrix((y, p, y.cross(p))).transposed()

_rest_palm = {}
def rest_palm_local(side):
    """Palm normal of the hand, expressed in the lowerarm's rest frame."""
    if side in _rest_palm: return _rest_palm[side]
    r = rig(); bones = r.data.bones
    hand = bones["hand_" + side]
    across = bones["index_01_" + side].head_local - bones["pinky_01_" + side].head_local
    hdir = (bones["middle_01_" + side].head_local - hand.head_local).normalized()
    n = across.cross(hdir).normalized()
    # palm faces the thumb side's curl: in the A-pose rest the palms face the body
    sx = 1 if side == "l" else -1
    if n.x * sx > 0: n = -n   # palm side = side the fingers curl toward (checked on close-ups)
    la = bones["lowerarm_" + side].matrix_local.to_3x3()
    _rest_palm[side] = la.inverted() @ n
    return _rest_palm[side]

def orient_forearm(pb, side, d, palm):
    m = pb.matrix.copy()
    local = frame(Vector((0, 1, 0)), rest_palm_local(side))
    world = frame(Vector(d), Vector(palm))
    rot = world @ local.inverted()
    pb.matrix = Matrix.Translation(m.translation) @ rot.to_4x4()
    upd()

def curl_pose(c):
    """c: 0 = arms extended at the sides (elbow ~170 deg), 1 = fully curled (~35 deg)."""
    r = rig(); P = r.pose.bones
    for side, sx in (("l", 1), ("r", -1)):
        P["clavicle_" + side].rotation_quaternion = (1, 0, 0, 0); upd()
        # upper arm hangs by the torso, drifting slightly forward at the top
        aim(P["upperarm_" + side], (sx * 0.10, -0.04 - 0.06 * c, -1))
        a = math.radians(10 + 142 * c)                 # forearm angle from straight down
        d = Vector((sx * 0.06, -math.sin(a), -math.cos(a)))
        palm = Vector((0, -math.cos(a), math.sin(a)))  # supinated: forward, then toward shoulder
        orient_forearm(P["lowerarm_" + side], side, d, palm)
        P["hand_" + side].rotation_quaternion = Quaternion((1, 0, 0), 0); upd()

FINGERS = ("index", "middle", "ring", "pinky")

def grip(amount=1.0, axis="X", sign=1):
    """Wrap the fingers around the dumbbell handle."""
    r = rig(); P = r.pose.bones
    for side in "lr":
        for f in FINGERS:
            for i, deg in ((1, 55), (2, 70), (3, 45)):
                pb = P[f"{f}_0{i}_{side}"]
                pb.rotation_quaternion = Quaternion(Vector({"X": (1,0,0), "Z": (0,0,1)}[axis]), sign * math.radians(deg) * amount)
        for i, deg in ((1, 15), (2, 25), (3, 25)):
            P[f"thumb_0{i}_{side}"].rotation_quaternion = Quaternion(Vector({"X": (1,0,0), "Z": (0,0,1)}[axis]), sign * math.radians(deg) * amount)
    upd()
