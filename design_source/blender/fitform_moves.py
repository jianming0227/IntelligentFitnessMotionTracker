"""Lunge, shoulder press and lateral raise posing for the MPFB game_engine rig (armature space == world).
Same conventions as fitform_pose / fitform_squat: -Y is forward, +X is the character's left."""
import bpy, math, json, os
from mathutils import Vector, Matrix
import fitform_pose as fp, fitform_squat as fs

# Pose-bone scales the shipped squat/bicep clips were exported with (MPFB proportions: head, calves, feet).
# Scale is not keyed, so it is shared by every clip: keep it fixed. Setting pb.matrix (aim/place) drops
# scale, so every helper below puts it back; otherwise it drifts a little each call (it reached 92698 on ball_r).
_SCALES = json.load(open(os.path.join(os.path.dirname(__file__), "rig_pose_scales.json")))

def base_scales():
    for pb in fp.rig().pose.bones: pb.scale = _SCALES.get(pb.name, (1, 1, 1))
    fp.upd()

def _keep(fn):
    def wrapped(pb, *a, **k):
        sc = pb.scale.copy(); r = fn(pb, *a, **k); pb.scale = sc; fp.upd(); return r
    return wrapped
aim = _keep(fp.aim)
place = _keep(fs.place)
orient_forearm = _keep(fp.orient_forearm)

def reset():
    fp.reset(); base_scales()

D = math.radians
def lerp(a, b, t): return a + (b - a) * t
def _rest(name): return fp.rig().data.bones[name]

# ---------------------------------------------------------------- legs
def leg_to(side, hip, ankle, pole):
    """Two-bone IK: thigh/calf so the ankle lands on `ankle`, knee bending toward `pole`."""
    P = fp.rig().pose.bones
    L1, L2 = P["thigh_" + side].length, P["calf_" + side].length     # posed lengths (MPFB scales the calf)
    v = ankle - hip; d = min(v.length, L1 + L2 - 1e-4); u = v.normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0))
    p = Vector(pole); p = (p - u * p.dot(u)).normalized()
    K = hip + u * a + p * h
    A = hip + u * d
    aim(P["thigh_" + side], K - hip)
    aim(P["calf_" + side], A - K)
    return K, A

def knee_angle(side):
    P = fp.rig().pose.bones
    a = P["thigh_" + side].head - P["calf_" + side].head
    b = P["calf_" + side].tail - P["calf_" + side].head
    return math.degrees(a.angle(b))

# lunge geometry (metres): left foot forward, right foot back on the ball of the foot
FRONT_Y, BACK_BALL_Y = -0.27, 0.58
HIP_TOP, HIP_BOTTOM = 0.72, 0.49

_stand = {}
def _measure_stand():
    """Ankle/ball heights of the plain standing pose (the floor the squat stands on)."""
    if _stand: return
    reset(); P = fp.rig().pose.bones
    _stand.update(ankle=P["foot_l"].head.z, ball=P["ball_l"].head.z, ankle_x=P["foot_l"].head.x,
                  ankle_pt=P["foot_l"].head.copy(), ball_pt=P["ball_l"].head.copy())

def lunge_pose(d):
    """d: 0 tall in split stance -> 1 bottom (front knee ~90, back knee near the floor)."""
    _measure_stand(); reset(); P = fp.rig().pose.bones
    pel = _rest("pelvis")
    hz = lerp(HIP_TOP, HIP_BOTTOM, d); hy = lerp(0.13, 0.12, d)
    head = Vector((0, hy, hz)) + (pel.head_local - Vector((0, 0, 0.894)))
    place(P["pelvis"], head, Matrix.Rotation(D(4) * d, 3, "X") @ pel.matrix_local.to_3x3())
    # floor heights taken from the standing pose (same feet as the squat)
    ank_z, ball_z = _stand["ankle"], _stand["ball"]
    # front (left) leg: foot flat, knee forward
    fl = _rest("foot_l")
    ank_f = Vector((_stand["ankle_x"], FRONT_Y, ank_z))
    leg_to("l", P["thigh_l"].head.copy(), ank_f, (0.05, -1, 0))
    place(P["foot_l"], P["foot_l"].head.copy(), fl.matrix_local.to_3x3())
    # back (right) leg: ball planted, heel up
    flen = (_stand["ball_pt"] - _stand["ankle_pt"]).length
    ball = Vector((-_stand["ankle_x"], BACK_BALL_Y, ball_z))
    heel_up = D(lerp(38, 58, d))
    ank_b = ball + Vector((0, math.cos(heel_up), math.sin(heel_up))) * flen
    for _ in range(3):                                 # scaled calf/foot bend the aim a little: correct the toes
        leg_to("r", P["thigh_r"].head.copy(), ank_b, (-0.05, -1, 0))
        aim(P["foot_r"], ball - P["foot_r"].head)
        err = ball - P["ball_r"].head
        if err.length < 0.002: break
        ank_b = ank_b + err
    aim(P["ball_r"], (0, -1, -0.05))                 # toes flat on the floor
    # torso tall, tiny forward lean, eyes ahead
    for name, part in (("spine_01", 0.4), ("spine_02", 0.7), ("spine_03", 1.0)):
        lean = D(6) * d * part
        aim(P[name], (0, -math.sin(lean), math.cos(lean)))
    aim(P["neck_01"], (0, -0.02, 1)); aim(P["head"], (0, -0.08, 1))
    # arms relaxed by the sides, palms in
    for s, sx in (("l", 1), ("r", -1)):
        aim(P["upperarm_" + s], (sx * 0.12, -0.02, -1))
        fd = Vector((sx * 0.06, -0.10, -1))
        orient_forearm(P["lowerarm_" + s], s, fd, Vector((-sx, 0, 0)))
    fp.grip(0.2, "X", 1)

# ---------------------------------------------------------------- arms
def _clavicle(lift):
    """Small shrug-free clavicle elevation so overhead arms don't pinch the shoulder."""
    P = fp.rig().pose.bones
    for s, sx in (("l", 1), ("r", -1)):
        c = _rest("clavicle_" + s)
        dv = (c.tail_local - c.head_local).normalized()
        aim(P["clavicle_" + s], (dv.x, dv.y, dv.z + lift))

def press_pose(p):
    """p: 0 dumbbells at shoulder height (elbows ~90) -> 1 locked out overhead (~170)."""
    reset(); P = fp.rig().pose.bones
    _clavicle(D(14) * p)
    alpha = D(lerp(82, 162, p))          # upper arm from straight down, out to the side
    beta = D(lerp(0, 6, p))              # forearm from vertical, outward
    for s, sx in (("l", 1), ("r", -1)):
        u = Vector((sx * math.sin(alpha), -0.18 * math.sin(alpha), -math.cos(alpha)))
        aim(P["upperarm_" + s], u)
        fd = Vector((sx * math.sin(beta), -0.04, math.cos(beta)))
        orient_forearm(P["lowerarm_" + s], s, fd, Vector((0, -1, 0)))     # palms forward
    fp.grip(1.0, "X", 1)

def raise_pose(r):
    """r: 0 arms by the sides (~20 at the shoulder) -> 1 out to shoulder height (~90), soft elbows."""
    reset(); P = fp.rig().pose.bones
    _clavicle(D(4) * r)
    alpha = D(lerp(20, 88, r))
    for s, sx in (("l", 1), ("r", -1)):
        u = Vector((sx * math.sin(alpha), -0.22 * math.sin(alpha), -math.cos(alpha))).normalized()
        aim(P["upperarm_" + s], u)
        fwd = Vector((0, -1, 0)); fwd = (fwd - u * fwd.dot(u)).normalized()
        fd = (u + fwd * math.tan(D(16))).normalized()                        # ~165 deg soft elbow
        palm_in, palm_down = Vector((-sx, 0, 0)), Vector((0, 0, -1))
        palm = palm_in.lerp(palm_down, r).normalized()
        orient_forearm(P["lowerarm_" + s], s, fd, palm)
    fp.grip(1.0, "X", 1)

def arm_angles(side):
    """(shoulder abduction from straight down, elbow interior angle) in degrees."""
    P = fp.rig().pose.bones
    ua = P["upperarm_" + side]; la = P["lowerarm_" + side]
    up = ua.tail - ua.head
    return (math.degrees(up.angle(Vector((0, 0, -1)))),
            math.degrees((ua.head - ua.tail).angle(la.tail - la.head)))
