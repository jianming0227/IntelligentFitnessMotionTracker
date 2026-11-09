"""Shared helpers for the FitForm human (MPFB) build steps."""
import bpy, os
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.locationservice import LocationService
from bl_ext.user_default.mpfb.services.objectservice import ObjectService

# Microsoft Store Blender redirects AppData to a much longer LocalCache path,
# which pushes some MakeHuman files past Windows' 260-char limit. The same files
# are visible at the short path, so point MPFB there.
_LONG = r"C:\Users\ljmwa\AppData\Local\packages\BlenderFoundation.Blender_ppwjx1n5r4v9t\LocalCache\Roaming"
_SHORT = r"C:\Users\ljmwa\AppData\Roaming"
for _k, _v in list(vars(LocationService).items()):
    if isinstance(_v, str) and _v.lower().startswith(_LONG.lower()):
        setattr(LocationService, _k, _SHORT + _v[len(_LONG):])
ASSETS = LocationService.get_user_data()
OUT = r"C:\Users\ljmwa\Desktop\fitness\design_source"

def asset(*p):
    return os.path.join(ASSETS, *p)

def basemesh():
    for o in bpy.data.objects:
        if ObjectService.get_object_type(o) == "Basemesh":
            return o
    return None

def view3d_areas():
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type == "VIEW_3D":
                yield win, area

def show(frame_obj=None, shading="MATERIAL"):
    """Material preview + frame the human so Ming can watch progress."""
    for win, area in view3d_areas():
        space = area.spaces.active
        space.shading.type = shading
        region = next(r for r in area.regions if r.type == "WINDOW")
        with bpy.context.temp_override(window=win, area=area, region=region):
            if frame_obj is not None:
                bpy.ops.object.select_all(action="DESELECT")
                for o in ([frame_obj] + list(frame_obj.children_recursive)):
                    o.select_set(True)
                bpy.context.view_layer.objects.active = frame_obj
                bpy.ops.view3d.view_selected()

def view_34(dist=3.2, target=(0, 0, 1.0), yaw=-35, pitch=78):
    """Point every 3D view at the human from the front 3/4 (like the app camera)."""
    from mathutils import Euler, Vector
    import math
    for win, area in view3d_areas():
        r3d = area.spaces.active.region_3d
        r3d.view_perspective = "PERSP"
        r3d.view_location = Vector(target)
        r3d.view_rotation = Euler((math.radians(pitch), 0, math.radians(yaw)), "XYZ").to_quaternion()
        r3d.view_distance = dist
        area.spaces.active.overlay.show_overlays = False

def snapshot(path, w=900, h=900):
    """Save what the 3D viewport shows (material preview) to a PNG."""
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = path
    for win, area in view3d_areas():
        region = next(r for r in area.regions if r.type == "WINDOW")
        with bpy.context.temp_override(window=win, area=area, region=region):
            bpy.ops.render.opengl(write_still=True, view_context=True)
        return
