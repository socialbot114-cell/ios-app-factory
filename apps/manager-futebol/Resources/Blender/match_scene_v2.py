"""Create the upgraded match scene: detailed figurines plus two reusable rig actions.

Run from the repo root:
  blender --background --python apps/manager-futebol/Resources/Blender/match_scene_v2.py -- \
    apps/manager-futebol/Resources/Assets.xcassets/MatchSceneV2.imageset/match-scene.png \
    apps/manager-futebol/Resources/Blender/exports/match-scene-v2.glb
"""

import math
import os
import sys

import bpy
from mathutils import Vector


def arguments():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    fallback = ["/tmp/manager-match-v2.png", "/tmp/manager-match-v2.glb"]
    return (args + fallback)[:2]


def mat(name, color, roughness=0.82):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def box(name, location, dimensions, material, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Figurine soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def sphere(name, location, scale, material, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def rod(name, start, end, radius, material, vertices=8):
    start, end = Vector(start), Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length,
                                       location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    return obj


def stroke(name, points, material, radius=0.019):
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


def parent_bone(obj, armature, bone_name):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    bone_world = armature.matrix_world @ armature.pose.bones[bone_name].matrix
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = bone_world.inverted()
    obj.matrix_world = world


def make_rig(name, x, y, yaw):
    data = bpy.data.armatures.new(f"{name} | humanoid skeleton")
    arm = bpy.data.objects.new(f"{name} | rig", data)
    bpy.context.collection.objects.link(arm)
    arm.location = (x, y, 0)
    arm.rotation_euler.z = yaw
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    specs = {
        "root": ((0, 0, 0.02), (0, 0, 0.94), None),
        "spine": ((0, 0, 0.86), (0, 0, 1.47), "root"),
        "head": ((0, 0, 1.43), (0, 0, 1.90), "spine"),
        "thigh.L": ((-0.12, 0, 0.93), (-0.12, 0, 0.53), "root"),
        "shin.L": ((-0.12, 0, 0.53), (-0.12, 0, 0.15), "thigh.L"),
        "thigh.R": ((0.12, 0, 0.93), (0.12, 0, 0.53), "root"),
        "shin.R": ((0.12, 0, 0.53), (0.12, 0, 0.15), "thigh.R"),
        "upper_arm.L": ((-0.25, 0, 1.42), (-0.37, 0, 1.20), "spine"),
        "forearm.L": ((-0.37, 0, 1.20), (-0.38, 0, 1.00), "upper_arm.L"),
        "upper_arm.R": ((0.25, 0, 1.42), (0.37, 0, 1.20), "spine"),
        "forearm.R": ((0.37, 0, 1.20), (0.38, 0, 1.00), "upper_arm.R"),
    }
    bones = {}
    for bone_name, (head, tail, parent_name) in specs.items():
        bone = data.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        if parent_name:
            bone.parent = bones[parent_name]
            bone.use_connect = False
        bones[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.select_set(False)
    return arm


def coords(x, y, yaw, point):
    px, py, pz = point
    c, s = math.cos(yaw), math.sin(yaw)
    return (x + px * c - py * s, y + px * s + py * c, pz)


def character(name, x, y, yaw, kit, trim, skin, hair, number, rig=None):
    arm = rig or make_rig(name, x, y, yaw)

    def put(obj, bone):
        parent_bone(obj, arm, bone)
        return obj

    # Layered kit: torso, contrasting side panels, collar, cuffs, shorts and socks.
    put(box(f"{name} | shirt", coords(x, y, yaw, (0, 0, 1.28)), (0.45, 0.32, 0.54), kit, 0.10), "spine")
    for side in (-1, 1):
        put(box(f"{name} | side stripe", coords(x, y, yaw, (side * 0.21, 0, 1.29)), (0.035, 0.326, 0.42), trim, 0.012), "spine")
    put(box(f"{name} | collar", coords(x, y, yaw, (0, 0, 1.565)), (0.21, 0.23, 0.065), trim, 0.025), "spine")
    put(box(f"{name} | shorts", coords(x, y, yaw, (0, 0, 0.94)), (0.41, 0.32, 0.23), trim, 0.05), "root")

    # Neck, faceted head, hair cap, ears and a tiny nose give each figure a readable face.
    put(rod(f"{name} | neck", coords(x, y, yaw, (0, 0, 1.49)), coords(x, y, yaw, (0, 0, 1.62)), 0.075, skin), "head")
    put(sphere(f"{name} | head", coords(x, y, yaw, (0, 0, 1.72)), (0.19, 0.18, 0.22), skin, 12, 8), "head")
    put(sphere(f"{name} | hair cap", coords(x, y, yaw, (0, -0.005, 1.84)), (0.195, 0.187, 0.105), hair, 12, 6), "head")
    for side in (-1, 1):
        put(sphere(f"{name} | ear", coords(x, y, yaw, (side * 0.185, 0, 1.72)), (0.045, 0.06, 0.065), skin, 10, 6), "head")
        put(sphere(f"{name} | eye", coords(x, y, yaw, (side * 0.065, 0.165, 1.735)), (0.022, 0.018, 0.024), hair, 10, 6), "head")
    put(sphere(f"{name} | nose", coords(x, y, yaw, (0, 0.185, 1.70)), (0.035, 0.04, 0.045), skin, 10, 6), "head")

    # Sleeve and forearm segments follow separate bones, so actions move limbs in-game.
    for side, upper_bone, lower_bone in ((-1, "upper_arm.L", "forearm.L"), (1, "upper_arm.R", "forearm.R")):
        put(rod(f"{name} | sleeve", coords(x, y, yaw, (side * 0.25, 0, 1.43)), coords(x, y, yaw, (side * 0.37, 0, 1.20)), 0.085, kit), upper_bone)
        put(sphere(f"{name} | cuff", coords(x, y, yaw, (side * 0.37, 0, 1.20)), (0.07, 0.073, 0.07), trim, 10, 6), lower_bone)
        put(rod(f"{name} | forearm", coords(x, y, yaw, (side * 0.37, 0, 1.20)), coords(x, y, yaw, (side * 0.38, 0.015, 1.00)), 0.052, skin), lower_bone)
        put(sphere(f"{name} | hand", coords(x, y, yaw, (side * 0.38, 0.015, 0.98)), (0.065, 0.055, 0.075), skin, 10, 6), lower_bone)

    for side, thigh_bone, shin_bone in ((-1, "thigh.L", "shin.L"), (1, "thigh.R", "shin.R")):
        hip = (side * 0.12, 0, 0.87)
        knee = (side * 0.12, 0, 0.52)
        ankle = (side * 0.12, 0, 0.15)
        put(rod(f"{name} | thigh", coords(x, y, yaw, hip), coords(x, y, yaw, knee), 0.105, trim, 7), thigh_bone)
        put(sphere(f"{name} | knee", coords(x, y, yaw, knee), (0.083, 0.085, 0.085), skin, 10, 6), shin_bone)
        put(rod(f"{name} | sock", coords(x, y, yaw, knee), coords(x, y, yaw, ankle), 0.066, white_kit, 7), shin_bone)
        put(box(f"{name} | boot", coords(x, y, yaw, (side * 0.12, 0.075, 0.095)), (0.14, 0.25, 0.12), boot_mat, 0.04), shin_bone)

    # Jersey number is modeled as shallow 3D text on the chest.
    bpy.ops.object.text_add(location=coords(x, y, yaw, (0, 0.165, 1.28)))
    text = bpy.context.object
    text.name = f"{name} | shirt number {number}"
    text.data.body = str(number)
    text.data.align_x = "CENTER"
    text.data.align_y = "CENTER"
    text.data.size = 0.20
    text.data.extrude = 0.003
    text.rotation_euler = (math.pi / 2, 0, yaw)
    text.data.materials.append(trim)
    put(text, "spine")
    return arm


def add_actions(armature):
    armature.animation_data_create()
    jog = bpy.data.actions.new("Player | Jog loop")
    armature.animation_data.action = jog
    for frame, stride in ((1, 0.0), (7, 0.48), (13, 0.0), (19, -0.48), (25, 0.0)):
        bpy.context.scene.frame_set(frame)
        for name, value in (("thigh.L", stride), ("thigh.R", -stride),
                            ("upper_arm.L", -stride * 0.55), ("upper_arm.R", stride * 0.55)):
            bone = armature.pose.bones[name]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler[0] = value
            bone.keyframe_insert(data_path="rotation_euler", index=0, frame=frame, group=name)

    kick = bpy.data.actions.new("Player | Kick")
    armature.animation_data.action = kick
    for frame, swing in ((1, 0.0), (6, -0.20), (10, 1.05), (14, 0.28), (20, 0.0)):
        bpy.context.scene.frame_set(frame)
        for name, value in (("thigh.R", swing), ("shin.R", -0.35 if frame == 10 else 0.0),
                            ("thigh.L", -0.12 if frame in (6, 10, 14) else 0.0),
                            ("upper_arm.L", 0.24 if frame in (6, 10, 14) else 0.0),
                            ("upper_arm.R", -0.20 if frame in (6, 10, 14) else 0.0)):
            bone = armature.pose.bones[name]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler[0] = value
            bone.keyframe_insert(data_path="rotation_euler", index=0, frame=frame, group=name)

    # Give the lead runner a tidy rest pose in the editable file and the render.
    armature.animation_data.action = None
    bpy.context.scene.frame_set(1)
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
    for action in (jog, kick):
        track = armature.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, int(action.frame_range[0]), action)
    return jog, kick


render_path, glb_path = arguments()
os.makedirs(os.path.dirname(os.path.abspath(render_path)), exist_ok=True)
os.makedirs(os.path.dirname(os.path.abspath(glb_path)), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

field = mat("Pitch | match green", (0.07, 0.33, 0.16))
stripe = mat("Pitch | alternating green", (0.10, 0.40, 0.20))
chalk = mat("Pitch lines | warm ivory", (0.92, 0.94, 0.84))
blue = mat("Home shirt | cobalt", (0.025, 0.19, 0.73))
gold = mat("Home kit | gold", (0.91, 0.61, 0.11))
red = mat("Away shirt | vermilion", (0.78, 0.075, 0.12))
white_kit = mat("Away kit | ivory", (0.92, 0.91, 0.82))
skin_tan = mat("Skin | warm tan", (0.65, 0.38, 0.25))
skin_deep = mat("Skin | deep brown", (0.30, 0.145, 0.10))
skin_light = mat("Skin | light", (0.82, 0.61, 0.46))
hair_dark = mat("Hair | espresso", (0.075, 0.045, 0.035))
hair_brown = mat("Hair | chestnut", (0.25, 0.105, 0.045))
boot_mat = mat("Boots | charcoal", (0.055, 0.065, 0.07))
ball_mat = mat("Ball | cream", (0.96, 0.95, 0.86))

# Field and markings.
box("Field base", (0, 0, -0.16), (13.2, 8.25, 0.34), field, 0.26)
for index in range(10):
    box("Mowing stripe", (-5.75 + index * 1.28, 0, 0.018), (0.62, 7.72, 0.012), stripe, 0.006)
z = 0.026
stroke("Touchlines", [(-6.15, -3.78, z), (6.15, -3.78, z), (6.15, 3.78, z), (-6.15, 3.78, z), (-6.15, -3.78, z)], chalk)
stroke("Halfway line", [(0, -3.78, z), (0, 3.78, z)], chalk)
stroke("Center circle", [(0.95 * math.cos(i * math.tau / 64), 0.95 * math.sin(i * math.tau / 64), z) for i in range(65)], chalk)
for side in (-1, 1):
    edge, inner = side * 6.15, side * 4.0
    stroke("Penalty box", [(edge, -1.95, z), (inner, -1.95, z), (inner, 1.95, z), (edge, 1.95, z)], chalk)
    stroke("Goal box", [(edge, -0.95, z), (side * 5.05, -0.95, z), (side * 5.05, 0.95, z), (edge, 0.95, z)], chalk)

# Six detailed figures, each with a bone hierarchy; jerseys share a reusable animation rig.
home_rig = make_rig("Home 09 Striker", -0.95, 0.05, math.pi / 2)
jog_action, kick_action = add_actions(home_rig)
for args in [
    ("Home 09 Striker", -0.95, 0.05, math.pi / 2, blue, gold, skin_tan, hair_dark, 9),
    ("Home 07 Winger", -2.35, 1.50, math.pi / 2, blue, gold, skin_deep, hair_dark, 7),
    ("Home 06 Midfielder", -3.15, -1.48, math.pi / 2, blue, gold, skin_light, hair_brown, 6),
    ("Away 04 Defender", 0.90, -0.08, -math.pi / 2, red, white_kit, skin_deep, hair_dark, 4),
    ("Away 05 Defender", 2.38, 1.46, -math.pi / 2, red, white_kit, skin_tan, hair_brown, 5),
    ("Away 08 Midfielder", 3.45, -1.52, -math.pi / 2, red, white_kit, skin_light, hair_dark, 8),
]:
    name, x, y, yaw, kit, trim, skin, hair, number = args
    rig = home_rig if name == "Home 09 Striker" else None
    character(name, x, y, yaw, kit, trim, skin, hair, number, rig=rig)

# A faceted ball with a few dark pentagon-like panels.
sphere("Match ball", (0.06, 0.10, 0.15), (0.145, 0.145, 0.145), ball_mat, 12, 8)
for angle in (0, 2.1, 4.2):
    sphere("Ball dark panel", (0.06 + 0.11 * math.cos(angle), 0.10 + 0.11 * math.sin(angle), 0.19),
           (0.032, 0.018, 0.032), boot_mat, 8, 5)

# Iso composition and soft studio lighting.
bpy.ops.object.camera_add(location=(13.6, -17.0, 20.5))
camera = bpy.context.object
camera.name = "Match action camera"
target = Vector((0, 0, 0.48))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 18.5
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type="AREA", location=(-7, -8, 16))
key = bpy.context.object
key.name = "Softbox key"
key.data.energy = 2400
key.data.shape = "DISK"
key.data.size = 11
bpy.ops.object.light_add(type="AREA", location=(8, 5, 11))
fill = bpy.context.object
fill.name = "Softbox fill"
fill.data.energy = 950
fill.data.size = 9

scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 25
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 80
scene.render.resolution_x = 1200
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.filepath = render_path
scene.frame_set(1)
bpy.ops.render.render(write_still=True)

# Save editable native scene; export glTF with rig actions to use in an animated scene.
blend_path = os.path.splitext(glb_path)[0] + ".blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    export_apply=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=True,
    export_optimize_animation_size=True,
)
print("Rendered upgraded footballers:", render_path)
print("Exported rigged players and animations:", glb_path)
