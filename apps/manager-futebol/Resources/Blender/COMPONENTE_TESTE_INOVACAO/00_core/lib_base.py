"""Biblioteca base reutilizavel — COMPONENTE_TESTE_INOVACAO / 00_core.

Todos os outros componentes importam daqui para nao duplicar codigo.
Uso dentro do Blender:
    import sys
    sys.path.append(".../00_core")
    import lib_base as LB
"""
import math
import bpy
from mathutils import Vector


def limpar_cena():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=0.82):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
    return m


def box(name, location, dimensions, material, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o = bpy.context.object
    o.name = name
    o.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material:
        o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new("Bisel suave", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        o.modifiers.new("Normals", "WEIGHTED_NORMAL")
    return o


def sphere(name, location, scale, material, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, radius=1, location=location)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    if material:
        o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def rod(name, start, end, radius, material, vertices=8):
    start, end = Vector(start), Vector(end)
    d = end - start
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=d.length,
        location=(start + end) * 0.5)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    if material:
        o.data.materials.append(material)
    return o


def stroke(name, points, material, radius=0.02):
    c = bpy.data.curves.new(name, "CURVE")
    c.dimensions = "3D"
    c.bevel_depth = radius
    c.bevel_resolution = 2
    s = c.splines.new("POLY")
    s.points.add(len(points) - 1)
    for p, co in zip(s.points, points):
        p.co = (*co, 1)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    if material:
        o.data.materials.append(material)
    return o


def texto_3d(name, label, location, size, material, yaw=0.0):
    bpy.ops.object.text_add(location=location, rotation=(math.pi / 2, 0, yaw))
    o = bpy.context.object
    o.name = name
    o.data.body = label
    o.data.align_x = "CENTER"
    o.data.align_y = "CENTER"
    o.data.size = size
    o.data.extrude = 0.002
    if material:
        o.data.materials.append(material)
    return o


def camera_iso(location=(14.8, -19.0, 21.5), ortho_scale=23.0, alvo=(0, 0, 1.0), nome="Camera ISO"):
    bpy.ops.object.camera_add(location=location)
    cam = bpy.context.object
    cam.name = nome
    alvo_v = Vector(alvo)
    cam.rotation_euler = (alvo_v - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho_scale
    bpy.context.scene.camera = cam
    return cam


def luz_estudio(noturno=False):
    if noturno:
        configs = [((-8, -10, 18), 1200), ((8, 6, 12), 2500)]
    else:
        configs = [((-8, -9, 18), 2800), ((8, 6, 13), 1050)]
    for pos, energia in configs:
        bpy.ops.object.light_add(type="AREA", location=pos)
        l = bpy.context.object
        l.data.energy = energia
        l.data.shape = "DISK"
        l.data.size = 12


def render_transparente(path, res_x=1200, res_y=900, samples=64):
    import os
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = samples
    except AttributeError:
        pass
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "Medium High Contrast"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Render OK:", path)
