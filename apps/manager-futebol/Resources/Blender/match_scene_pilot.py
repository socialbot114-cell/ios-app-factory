"""Create a stylized match vignette and reusable footballer scene.

Run from the repo root:
  blender --background --python apps/manager-futebol/Resources/Blender/match_scene_pilot.py -- \
    apps/manager-futebol/Resources/Assets.xcassets/MatchScenePilot.imageset/match-scene.png \
    apps/manager-futebol/Resources/Blender/exports/match-scene-pilot.glb
"""

import math
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    defaults = [
        "/tmp/manager-futebol-match-scene.png",
        "/tmp/manager-futebol-match-scene.glb",
    ]
    return (args + defaults)[0:2]


def material(name, color, roughness=0.82):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def bevel_cube(name, location, dimensions, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Rounded toy-like edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Soft normals", "WEIGHTED_NORMAL")
    return obj


def sphere(name, location, scale, mat, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def link(name, start, end, radius, mat, vertices=8):
    start, end = Vector(start), Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length,
                                       location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(mat)
    return obj


def line(name, points, mat, radius=0.018):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def create_player(label, x, y, yaw, kit, trim, skin, hair, pose=0):
    """Make one named, low-poly footballer. Each limb is simple reusable mesh geometry."""
    root = bpy.data.objects.new(label, None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, 0)
    root.rotation_euler[2] = yaw

    def local(point):
        px, py, pz = point
        c, s = math.cos(yaw), math.sin(yaw)
        return (x + px * c - py * s, y + px * s + py * c, pz)

    def part(obj):
        obj.parent = root
        return obj

    # Body and shorts.
    part(bevel_cube(f"{label} | shirt", local((0, 0, 1.27)), (0.43, 0.29, 0.48), kit, 0.09))
    part(bevel_cube(f"{label} | collar", local((0, 0, 1.53)), (0.19, 0.23, 0.065), trim, 0.025))
    part(bevel_cube(f"{label} | shorts", local((0, 0, 0.94)), (0.39, 0.30, 0.22), trim, 0.045))
    part(sphere(f"{label} | head", local((0, 0, 1.70)), (0.19, 0.18, 0.22), skin))
    part(sphere(f"{label} | hair", local((0, 0, 1.83)), (0.195, 0.185, 0.11), hair))

    # Arms are slightly separated from the torso for a clear, readable silhouette.
    arm_swing = (-0.13, 0.13, 0.03)[pose % 3]
    for side in (-1, 1):
        shoulder = (side * 0.25, 0, 1.43)
        hand = (side * 0.39, arm_swing * side, 1.08 + 0.05 * (pose % 2))
        part(link(f"{label} | sleeve", local(shoulder), local((side * 0.34, arm_swing * side * 0.5, 1.28)), 0.085, kit))
        part(link(f"{label} | forearm", local((side * 0.34, arm_swing * side * 0.5, 1.28)), local(hand), 0.055, skin))

    # Running stride, with small asymmetry so the figures do not look like rigid mannequins.
    strides = [(-0.16, 0.20), (0.20, -0.14), (0.06, 0.04)]
    front, back = strides[pose % len(strides)]
    for side, stride in ((-1, front), (1, back)):
        hip = (side * 0.12, 0, 0.88)
        knee = (side * 0.14, stride, 0.52)
        ankle = (side * 0.14, stride * 1.65, 0.16)
        part(link(f"{label} | thigh", local(hip), local(knee), 0.105, trim, 7))
        part(link(f"{label} | sock", local(knee), local(ankle), 0.073, trim, 7))
        boot = (side * 0.14, stride * 1.65 + 0.12, 0.09)
        part(link(f"{label} | boot", local(ankle), local(boot), 0.065, hair, 7))
    return root


render_path, glb_path = arguments()
os.makedirs(os.path.dirname(os.path.abspath(render_path)), exist_ok=True)
os.makedirs(os.path.dirname(os.path.abspath(glb_path)), exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

pitch = material("Pitch | match green", (0.075, 0.34, 0.17))
stripe = material("Pitch | alternating grass", (0.09, 0.39, 0.20))
marking = material("Pitch lines | ivory", (0.90, 0.93, 0.82))
blue = material("Home kit | royal blue", (0.035, 0.20, 0.75))
blue_trim = material("Home kit | gold trim", (0.95, 0.66, 0.10))
red = material("Away kit | coral red", (0.77, 0.085, 0.12))
white = material("Away kit | white trim", (0.92, 0.91, 0.82))
skin_a = material("Skin | warm tan", (0.63, 0.35, 0.22))
skin_b = material("Skin | deep brown", (0.30, 0.14, 0.095))
skin_c = material("Skin | light", (0.82, 0.59, 0.43))
hair_dark = material("Hair | dark", (0.08, 0.055, 0.045))
hair_light = material("Hair | chestnut", (0.28, 0.12, 0.055))
ball_mat = material("Ball | warm white", (0.95, 0.94, 0.84))

# Small rounded pitch tile, with field lines suited to the isometric composition.
bevel_cube("Pitch tile", (0, 0, -0.18), (13.0, 8.2, 0.35), pitch, 0.30)
for stripe_index in range(8):
    sx = -5.7 + stripe_index * 1.65
    bevel_cube("Mowing stripe", (sx, 0, 0.004), (0.82, 7.65, 0.018), stripe, 0.01)
z = 0.022
line("Outer touchlines", [(-6.15, -3.75, z), (6.15, -3.75, z), (6.15, 3.75, z), (-6.15, 3.75, z), (-6.15, -3.75, z)], marking)
line("Halfway line", [(0, -3.75, z), (0, 3.75, z)], marking)
line("Center circle", [(0.95 * math.cos(i * math.tau / 64), 0.95 * math.sin(i * math.tau / 64), z) for i in range(65)], marking)
for side in (-1, 1):
    edge = side * 6.15
    inner = side * 4.0
    line("Penalty box", [(edge, -1.95, z), (inner, -1.95, z), (inner, 1.95, z), (edge, 1.95, z)], marking)
    line("Goal box", [(edge, -0.95, z), (side * 5.0, -0.95, z), (side * 5.0, 0.95, z), (edge, 0.95, z)], marking)

# Two fictional squads in a central-play moment; individual players have named roots.
players = [
    ("Home 09 Striker", -0.95, 0.15, 0.30, blue, blue_trim, skin_a, hair_dark, 0),
    ("Home 07 Winger", -2.15, 1.65, 0.12, blue, blue_trim, skin_b, hair_dark, 1),
    ("Home 06 Midfielder", -3.25, -1.25, 0.15, blue, blue_trim, skin_c, hair_light, 2),
    ("Away 04 Defender", 1.05, -0.20, math.pi + 0.10, red, white, skin_b, hair_dark, 1),
    ("Away 05 Defender", 2.35, 1.45, math.pi - 0.05, red, white, skin_a, hair_light, 0),
    ("Away 08 Midfielder", 3.45, -1.50, math.pi - 0.20, red, white, skin_c, hair_dark, 2),
]
for player in players:
    create_player(*player)

# Football at the moment of a close contest between the two central players.
sphere("Match ball", (0.13, 0.10, 0.13), (0.13, 0.13, 0.13), ball_mat, segments=16, rings=8)

# Orthographic camera and soft daylight: readable shapes at small mobile sizes.
bpy.ops.object.camera_add(location=(11.5, -15.5, 20.0))
camera = bpy.context.object
camera.name = "Match vignette camera"
target = Vector((0, 0, 0.45))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 18.0
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type="AREA", location=(-5, -7, 15))
key = bpy.context.object
key.name = "Soft stadium daylight"
key.data.energy = 1800
key.data.shape = "DISK"
key.data.size = 11
bpy.ops.object.light_add(type="AREA", location=(8, 5, 10))
fill = bpy.context.object
fill.name = "Soft fill light"
fill.data.energy = 700
fill.data.size = 8

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 64
scene.render.resolution_x = 1200
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.filepath = render_path
bpy.ops.render.render(write_still=True)

# Keep the complete editable Blender scene and export geometry/materials for reuse.
blend_path = os.path.splitext(glb_path)[0] + ".blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True)
print("Rendered match scene:", render_path)
print("Exported reusable player scene:", glb_path)
