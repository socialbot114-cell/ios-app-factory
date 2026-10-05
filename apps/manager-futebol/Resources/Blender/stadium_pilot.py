"""Render a compact isometric stadium illustration for Manager Futebol.

Run with:
  blender --background --python stadium_pilot.py -- /path/to/stadium.png
"""

import math
import sys

import bpy
from mathutils import Vector


def output_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return args[0] if args else "/tmp/manager-futebol-stadium.png"


def material(name, color, roughness=0.82):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def cube(name, location, dimensions, mat, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft illustrated edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def line(name, points, mat, radius=0.025):
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


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

grass = material("Pitch | deep match green", (0.10, 0.39, 0.20))
stripe = material("Pitch | alternating green", (0.13, 0.46, 0.24))
white = material("Pitch markings | warm white", (0.91, 0.94, 0.84))
concrete = material("Stadium shell | warm concrete", (0.77, 0.73, 0.61))
dark = material("Roof | forest green", (0.055, 0.20, 0.16))
seat_a = material("Seats | emerald", (0.07, 0.39, 0.27))
seat_b = material("Seats | gold accent", (0.82, 0.55, 0.15))
shadow = material("Stadium base | dark green", (0.035, 0.15, 0.12))

# Low plinth and pitch.
cube("Rounded shadow plinth", (0, 0, 0), (13.2, 9.6, 0.48), shadow, 0.42)
cube("Playing field", (0, 0, 0.29), (9.4, 5.7, 0.12), grass, 0.05)
for index in range(8):
    x = -4.05 + index * 1.16
    cube("Mowed stripe", (x, 0, 0.36), (0.58, 5.55, 0.012), stripe, 0.0)

# Pitch markings, inset on the grass.
z = 0.375
line("Touchlines", [(-4.45, -2.62, z), (4.45, -2.62, z), (4.45, 2.62, z), (-4.45, 2.62, z), (-4.45, -2.62, z)], white)
line("Halfway line", [(0, -2.62, z), (0, 2.62, z)], white)
circle_points = [(0.76 * math.cos(i * math.tau / 64), 0.76 * math.sin(i * math.tau / 64), z) for i in range(65)]
line("Center circle", circle_points, white)
for side in (-1, 1):
    x0, x1 = (side * 4.45, side * 3.0)
    line("Penalty area", [(x0, -1.48, z), (x1, -1.48, z), (x1, 1.48, z), (x0, 1.48, z)], white)
    gx = side * 4.46
    line("Goal frame", [(gx, -0.5, z), (gx, 0.5, z), (gx, 0.5, 0.86), (gx, -0.5, 0.86), (gx, -0.5, z)], white, 0.035)

# Four stepped grandstands surrounding the pitch.
for row in range(3):
    height = 0.43 + row * 0.35
    width = 0.72
    y = 3.08 + row * 0.29
    color = seat_a if row != 1 else seat_b
    for side in (-1, 1):
        cube("Long stand terrace", (0, side * y, height), (10.5 + row * 0.25, width, 0.62), color, 0.10)
        cube("End stand terrace", (side * (5.10 + row * 0.28), 0, height), (width, 6.9 + row * 0.25, 0.62), color, 0.10)

# Perimeter fascia and four roof canopies; leave the pitch open and visible.
for side in (-1, 1):
    cube("Long stand fascia", (0, side * 4.18, 1.72), (11.7, 0.38, 0.35), concrete, 0.10)
    cube("Long roof canopy", (0, side * 4.28, 2.55), (12.2, 1.05, 0.25), dark, 0.12)
    cube("End stand fascia", (side * 6.0, 0, 1.72), (0.38, 8.6, 0.35), concrete, 0.10)
    cube("End roof canopy", (side * 6.05, 0, 2.55), (1.05, 9.15, 0.25), dark, 0.12)

# Subtle entrance blocks and corner floodlights.
for side in (-1, 1):
    for end in (-1, 1):
        x, y = side * 5.8, end * 4.0
        cube("Floodlight mast", (x, y, 3.0), (0.12, 0.12, 1.5), concrete, 0.03)
        cube("Floodlight", (x, y, 3.78), (0.52, 0.18, 0.20), white, 0.04)
for y in (-4.66, 4.66):
    cube("Stadium entrance", (0, y, 0.72), (2.2, 0.30, 0.74), concrete, 0.12)

# Camera and soft studio lighting.
bpy.ops.object.camera_add(location=(12.5, -15.5, 17.0))
camera = bpy.context.object
camera.name = "Isometric product camera"
target = Vector((0, 0, 1.2))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 19.6
bpy.context.scene.camera = camera

bpy.ops.object.light_add(type="AREA", location=(-7, -8, 16))
key = bpy.context.object
key.name = "Large softbox"
key.data.energy = 2100
key.data.shape = "DISK"
key.data.size = 10
bpy.ops.object.light_add(type="AREA", location=(7, 4, 10))
fill = bpy.context.object
fill.name = "Soft fill"
fill.data.energy = 850
fill.data.size = 8

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 64
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.filepath = output_path()
scene.camera.data.lens = 50

bpy.ops.render.render(write_still=True)
print("Rendered stadium pilot to:", scene.render.filepath)
