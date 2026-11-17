r"""Dev helper: runs scripts dropped in blender/queue/ inside this live Blender.
Start it from Blender's Python console:
    exec(open(r"C:\Users\ljmwa\Desktop\fitness\design_source\blender\claude_bridge.py").read())
Each queue/<name>.py runs once; output goes to log/<name>.log, the script is renamed <name>.ran."""
import bpy, os, io, sys, traceback, contextlib

BASE = r"C:\Users\ljmwa\Desktop\fitness\design_source\blender"
Q, L = os.path.join(BASE, "queue"), os.path.join(BASE, "log")
os.makedirs(Q, exist_ok=True); os.makedirs(L, exist_ok=True)
if BASE not in sys.path: sys.path.insert(0, BASE)

def _claude_bridge_tick():
    try:
        jobs = sorted(f for f in os.listdir(Q) if f.endswith(".py"))
    except Exception:
        return 1.0
    for f in jobs:
        src = os.path.join(Q, f); name = f[:-3]
        code = open(src, encoding="utf-8").read()
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            try:
                exec(compile(code, src, "exec"), {"__name__": "__main__"})
                print("\n[bridge] OK")
            except Exception:
                traceback.print_exc(); print("\n[bridge] ERROR")
        open(os.path.join(L, name + ".log"), "w", encoding="utf-8").write(buf.getvalue())
        dst = os.path.join(Q, name + ".ran")
        if os.path.exists(dst): os.remove(dst)
        os.rename(src, dst)
        break                       # one job per tick keeps the UI responsive
    return 1.0

if not bpy.app.timers.is_registered(_claude_bridge_tick):
    bpy.app.timers.register(_claude_bridge_tick, first_interval=1.0, persistent=True)
print("Claude bridge running:", Q)
