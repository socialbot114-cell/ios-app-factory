"""Render a more detailed low-poly stadium for Manager Futebol."""

import math
import os
import sys

import bpy
from mathutils import Vector


def output_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return args[0] if args else "/tmp/manager-futebol-stadium-v2.png"


def mat(name, color, roughness=0.86):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def box(name, location, dimensions, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Soft bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def stroke(name, points, material, radius=0.024):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*coordinate, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


render_path = output_path()
os.makedirs(os.path.dirname(os.path.abspath(render_path)), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

pitch = mat("Pitch | rich green", (0.075, 0.34, 0.16))
grass = mat("Pitch | light mowing stripe", (0.10, 0.40, 0.20))
line_mat = mat("Pitch markings | ivory", (0.91, 0.94, 0.84))
shell = mat("Bowl | warm stone", (0.66, 0.63, 0.53))
dark_shell = mat("Bowl | shadow green", (0.035, 0.15, 0.115))
roof = mat("Canopy | deep forest", (0.045, 0.19, 0.15))
roof_edge = mat("Canopy edge | brass", (0.72, 0.49, 0.16))
seat_green = mat("Seats | emerald", (0.045, 0.34, 0.23))
seat_mint = mat("Seats | mint accent", (0.10, 0.49, 0.32))
seat_gold = mat("Seats | gold accent", (0.85, 0.57, 0.14))
glass = mat("Press box | blue glass", (0.20, 0.39, 0.42), 0.28)
light_mat = mat("Floodlights | warm white", (1.0, 0.89, 0.62), 0.3)

# Raised plinth, striped field and detailed markings.
box("Stadium foundation", (0, 0, -0.26), (14.0, 10.5, 0.62), dark_shell, 0.42)
box("Playing surface", (0, 0, 0.10), (9.7, 5.9, 0.10), pitch, 0.04)
for index in range(10):
    x = -4.35 + index * 0.96
    box("Mowing stripe", (x, 0, 0.156), (0.46, 5.76, 0.012), grass, 0.006)
z = 0.17
stroke("Touchline rectangle", [(-4.6, -2.75, z), (4.6, -2.75, z), (4.6, 2.75, z), (-4.6, 2.75, z), (-4.6, -2.75, z)], line_mat)
stroke("Halfway line", [(0, -2.75, z), (0, 2.75, z)], line_mat)
stroke("Center circle", [(0.78 * math.cos(i * math.tau / 64), 0.78 * math.sin(i * math.tau / 64), z) for i in range(65)], line_mat)
for side in (-1, 1):
    edge, box_edge = side * 4.60, side * 3.03
    stroke("Penalty area", [(edge, -1.46, z), (box_edge, -1.46, z), (box_edge, 1.46, z), (edge, 1.46, z)], line_mat)
    stroke("Six yard box", [(edge, -0.72, z), (side * 4.0, -0.72, z), (side * 4.0, 0.72, z), (edge, 0.72, z)], line_mat)
    stroke("Goal frame", [(edge, -0.46, z), (edge, 0.46, z), (edge, 0.46, 0.72), (edge, -0.46, 0.72), (edge, -0.46, z)], line_mat, 0.035)

# Continuous four-sided lower bowl and stepped stands, with colored seat rows.
box("North lower bowl base", (0, 3.25, 0.49), (11.7, 1.15, 0.48), shell, 0.22)
box("South lower bowl base", (0, -3.25, 0.49), (11.7, 1.15, 0.48), shell, 0.22)
box("East lower bowl base", (5.25, 0, 0.49), (1.15, 7.35, 0.48), shell, 0.22)
box("West lower bowl base", (-5.25, 0, 0.49), (1.15, 7.35, 0.48), shell, 0.22)
for level in range(4):
    height = 0.78 + level * 0.38
    seat_depth = 0.42
    stand_y = 3.17 + level * 0.35
    stand_x = 4.98 + level * 0.35
    terrace = seat_green if level % 2 == 0 else seat_mint
    box("North seating terrace", (0, stand_y, height - 0.12), (10.8 + level * 0.22, 0.82, 0.56), terrace, 0.09)
    box("South seating terrace", (0, -stand_y, height - 0.12), (10.8 + level * 0.22, 0.82, 0.56), terrace, 0.09)
    box("East seating terrace", (stand_x, 0, height - 0.12), (0.82, 7.3 + level * 0.18, 0.56), terrace, 0.09)
    box("West seating terrace", (-stand_x, 0, height - 0.12), (0.82, 7.3 + level * 0.18, 0.56), terrace, 0.09)

    # Individual seats as linked, lightweight meshes give the stands a stadium texture.
    seat_mat = seat_gold if level == 2 else (seat_mint if level == 1 else seat_green)
    for side in (-1, 1):
        for index in range(29):
            seat_x = -5.05 + index * 0.36
            seat_y = side * (stand_y + 0.03)
            seat = box("Seat", (seat_x, seat_y, height + 0.08), (0.20, 0.20, 0.18), seat_mat, 0.035)
            if index > 0:
                previous = bpy.data.objects.get("Seat")
                # link shared mesh data after creation, retaining separate seat objects.
                seat.data = previous.data
    for side in (-1, 1):
        for index in range(19):
            seat_y = -3.12 + index * 0.35
            seat_x = side * (stand_x + 0.03)
            seat = box("Corner seat", (seat_x, seat_y, height + 0.08), (0.20, 0.20, 0.18), seat_mat, 0.035)
            seat.data = bpy.data.objects.get("Seat").data

# Club-colored fascia, tunnel entrances and sponsor ribbon boards.
for side in (-1, 1):
    box("Long fascia", (0, side * 4.65, 1.95), (12.1, 0.32, 0.42), dark_shell, 0.08)
    box("Long LED ribbon", (0, side * 4.84, 2.00), (11.3, 0.045, 0.20), roof_edge, 0.025)
    box("End fascia", (side * 6.03, 0, 1.95), (0.32, 8.6, 0.42), dark_shell, 0.08)
    box("End LED ribbon", (side * 6.22, 0, 2.00), (0.045, 7.7, 0.20), roof_edge, 0.025)
for y in (-4.90, 4.90):
    box("Players tunnel", (0, y, 0.65), (1.70, 0.38, 0.82), shell, 0.12)
    box("Tunnel opening", (0, y - (0.20 if y < 0 else -0.20), 0.55), (0.88, 0.05, 0.60), dark_shell, 0.06)

# Four canopy wings rather than one flat frame; exposed trusses and lit edges add depth.
for side in (-1, 1):
    box("North canopy", (0, side * 4.95, 3.48), (12.6, 1.30, 0.28), roof, 0.10)
    box("Canopy gold lip", (0, side * 5.57, 3.43), (12.4, 0.10, 0.10), roof_edge, 0.035)
    for x in (-5.75, -3.0, 0, 3.0, 5.75):
        box("Canopy support", (x, side * 4.48, 2.72), (0.12, 0.12, 1.48), shell, 0.025)
        box("Roof truss", (x, side * 5.0, 3.27), (0.12, 1.18, 0.12), roof_edge, 0.025)
    box("East canopy", (side * 5.78, 0, 3.48), (1.24, 8.9, 0.28), roof, 0.10)
    box("East canopy lip", (side * 6.36, 0, 3.43), (0.10, 8.7, 0.10), roof_edge, 0.035)
    for y in (-3.65, -1.8, 0, 1.8, 3.65):
        box("End canopy support", (side * 5.28, y, 2.72), (0.12, 0.12, 1.48), shell, 0.025)

# Enclosed press box, central scoreboard and recognizable floodlight masts.
box("Press box glass", (0, 4.16, 3.02), (3.6, 0.38, 0.78), glass, 0.09)
box("Scoreboard frame", (0, 4.15, 3.63), (2.0, 0.30, 0.72), dark_shell, 0.08)
box("Scoreboard screen", (0, 3.98, 3.63), (1.68, 0.05, 0.48), glass, 0.035)
for side in (-1, 1):
    for end in (-1, 1):
        x, y = side * 6.0, end * 4.45
        box("Floodlight mast", (x, y, 3.02), (0.13, 0.13, 2.65), shell, 0.035)
        box("Floodlight bar", (x, y, 4.38), (0.80, 0.22, 0.27), light_mat, 0.04)

# Orthographic catalog render with transparent background and soft shadows.
bpy.ops.object.camera_add(location=(14.8, -19.0, 21.5))
camera = bpy.context.object
camera.name = "Stadium isometric camera"
target = Vector((0, 0, 1.25))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 23.2
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type="AREA", location=(-8, -9, 18))
key = bpy.context.object
key.name = "Large soft stadium light"
key.data.energy = 2800
key.data.shape = "DISK"
key.data.size = 12
bpy.ops.object.light_add(type="AREA", location=(8, 6, 13))
fill = bpy.context.object
fill.name = "Soft bounce"
fill.data.energy = 1050
fill.data.size = 10

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 80
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.filepath = render_path
bpy.ops.render.render(write_still=True)
print("Rendered upgraded stadium to:", render_path)
