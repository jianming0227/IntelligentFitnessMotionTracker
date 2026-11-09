"""Builds both exercise clips with a muscle-highlight intro pause."""
import bpy, sys, importlib
import fitform_pose as fp, fitform_squat as fs, fitform_bicep as fb

FPS = 30
INTRO = (0.15, 1.1, 0.15)     # glow switch-on, hold, switch-off while standing still (short switches: no streaks)

def ease(t): return t * t * (3 - 2 * t)

def timeline(phases):
    vals = []
    for sec, a, b in phases:
        n = round(sec * FPS); vals += [a + (b - a) * ease(i / n) for i in range(n)]
    return vals

def intro_glow():
    fi, hold, fo = (round(s * FPS) for s in INTRO)
    return [ease(i / fi) for i in range(fi)] + [1.0] * hold + [1 - ease(i / fo) for i in range(fo)]

def build(exercise):
    intro = intro_glow(); n0 = len(intro)
    if exercise == "bicep_curl":
        rep = timeline([(1.6, 0, 1), (0.6, 1, 1), (2.0, 1, 0)]); action_name, pose = "BicepCurl", lambda c: (fp.reset(), fp.curl_pose(c), fp.grip(1.0, "X", 1))
        shape = {("FitForm_Human", "BicepFlex"): lambda f, c: c,
                 ("BicepGlow", "Flex"): lambda f, c: c,
                 ("BicepGlow", "Glow"): lambda f, c: intro[f] if f < n0 else fb.glow_value(c)}
    else:
        rep = timeline([(1.8, 0, 1), (0.8, 1, 1), (1.8, 1, 0)]); action_name, pose = "Squat", fs.squat_pose
        shape = {("LegGlow", "Glow"): lambda f, c: intro[f] if f < n0 else fb.glow_value(c)}
    vals = [0.0] * n0 + rep; N = len(vals)
    rig = fp.rig()
    old = bpy.data.actions.get(action_name)
    if old: bpy.data.actions.remove(old)
    act = bpy.data.actions.new(action_name); act.use_fake_user = True
    rig.animation_data.action = act
    for f in list(range(0, N, 3)) + [N - 1, N]:
        pose(vals[f % N])
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f); pb.keyframe_insert("location", frame=f)
    for (obj, key), fn in shape.items():
        sk = bpy.data.objects[obj].data.shape_keys
        if sk.animation_data is None: sk.animation_data_create()
        sk.animation_data.action = act
        kb = sk.key_blocks[key]
        for f in range(N + 1):                      # every frame: no overshoot on the glow ramps
            kb.value = fn(f % N, vals[f % N]); kb.keyframe_insert("value", frame=f)
    return action_name, N
