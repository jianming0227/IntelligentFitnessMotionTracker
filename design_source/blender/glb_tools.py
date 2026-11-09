"""Tiny .glb helpers (pure Python, also runs inside Blender)."""
import json, struct

def rename_animations(path, name):
    """Set the name of every animation in a .glb (the exporter's ACTIVE_ACTIONS mode calls them 'Animation')."""
    data = open(path, "rb").read()
    magic, version, _ = struct.unpack("<III", data[:12])
    jlen, jtype = struct.unpack("<II", data[12:20]); assert jtype == 0x4E4F534A
    gltf = json.loads(data[20:20 + jlen])
    for a in gltf.get("animations", []): a["name"] = name
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + jlen:]
    out = struct.pack("<III", magic, version, 12 + 8 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    open(path, "wb").write(out)
    return [a["name"] for a in gltf.get("animations", [])]

def promote_glow_alpha(path, mesh_hint="Glow"):
    """Blender's exporter writes a solid COLOR_0 and our soft-edge colour as COLOR_1; viewers only read
    COLOR_0. Point COLOR_0 of the glow meshes at the soft-edge accessor and drop COLOR_1."""
    data = open(path, "rb").read()
    magic, version, _ = struct.unpack("<III", data[:12])
    jlen, _ = struct.unpack("<II", data[12:20])
    gltf = json.loads(data[20:20 + jlen]); fixed = []
    for m in gltf.get("meshes", []):
        if mesh_hint not in m.get("name", ""): continue
        for pr in m["primitives"]:
            a = pr["attributes"]
            if "COLOR_1" in a:
                a["COLOR_0"] = a.pop("COLOR_1"); fixed.append(m["name"])
    js = json.dumps(gltf, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + jlen:]
    open(path, "wb").write(struct.pack("<III", magic, version, 20 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest)
    return fixed
