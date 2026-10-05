"""Biblioteca base reutilizavel — COMPONENTE_TESTE_INOVACAO / 00_core  (v2).

Tudo importa daqui. Novidades da v2:
  * materiais PBR (metal, emissao, verniz, vidro) + materiais procedurais
  * primitivas bmesh (milhares de pecas num unico objeto: torcida, cadeiras)
  * render Cycles com GI, sombras suaves, denoise, fundo degrade e "shadow catcher"
  * iluminacao de estudio (sol + ceu + rim) e noturna (refletores)
  * exportacao GLB por colecao

Uso dentro do Blender:
    sys.path.append(".../00_core"); import lib_base as LB
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

# ----------------------------------------------------------------- dimensoes
# Diorama "toy": campo 12 x 7.6, jogadores ~1.0 de altura (cabecao).
L, W = 12.0, 7.6          # gramado (X comprimento, Y largura)
HL, HW = L / 2, W / 2

# ------------------------------------------------------------------ paleta
PAL = {
    "teal": (0.020, 0.150, 0.150),
    "teal_cl": (0.050, 0.330, 0.320),
    "ouro": (0.90, 0.58, 0.10),
    "ouro_cl": (0.98, 0.78, 0.30),
    "creme": (0.93, 0.92, 0.84),
    "concreto": (0.60, 0.59, 0.55),
    "concreto_esc": (0.30, 0.31, 0.31),
    "grama": (0.060, 0.320, 0.100),
    "grama_cl": (0.090, 0.420, 0.140),
    "azul": (0.050, 0.200, 0.560),
    "vermelho": (0.75, 0.06, 0.08),
    "preto": (0.025, 0.027, 0.032),
    "branco": (0.95, 0.95, 0.93),
}


def srgb(h):
    """'#rrggbb' -> linear rgb."""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# ------------------------------------------------------------------- cena
def limpar_cena():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights):
        for b in list(blk):
            if b.users == 0:
                blk.remove(b)


def colecao(nome):
    """Cria (ou reutiliza) uma colecao e a torna ativa — organiza exportacao."""
    c = bpy.data.collections.get(nome)
    if not c:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    lc = bpy.context.view_layer.layer_collection.children.get(nome)
    if lc:
        bpy.context.view_layer.active_layer_collection = lc
    return c


# --------------------------------------------------------------- materiais
def _in(bsdf, nome, valor):
    if nome in bsdf.inputs:
        bsdf.inputs[nome].default_value = valor


def mat(name, color, roughness=0.62, metallic=0.0, emissao=None, forca=0.0,
        verniz=0.0, vidro=0.0, alpha=1.0, sheen=0.0, ior=1.45):
    """Material PBR. emissao=(r,g,b) + forca>0 => luminoso."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    b = m.node_tree.nodes.get("Principled BSDF")
    _in(b, "Base Color", (*color, 1))
    _in(b, "Roughness", roughness)
    _in(b, "Metallic", metallic)
    _in(b, "IOR", ior)
    if verniz:
        _in(b, "Coat Weight", verniz)
        _in(b, "Coat Roughness", 0.08)
    if sheen:
        _in(b, "Sheen Weight", sheen)
        _in(b, "Sheen Roughness", 0.5)
    if vidro:
        _in(b, "Transmission Weight", vidro)
    if alpha < 1.0:
        _in(b, "Alpha", alpha)
    if emissao is not None and forca > 0:
        _in(b, "Emission Color", (*emissao, 1))
        _in(b, "Emission Strength", forca)
    return m


def mat_ruido(name, color, roughness=0.7, escala=40.0, forca=0.12, bump=0.25):
    """Material com variacao sutil de tom + bump (concreto, asfalto, tecido)."""
    m = mat(name, color, roughness)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = escala
    n.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["Factor"].default_value = forca
    mix.inputs[6].default_value = (*color, 1)
    mix.inputs[7].default_value = (color[0] * 0.55, color[1] * 0.55, color[2] * 0.55, 1)
    nt.links.new(n.outputs["Fac"], mix.inputs["Factor"])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump")
    bm.inputs["Strength"].default_value = bump
    bm.inputs["Distance"].default_value = 0.02
    nt.links.new(n.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], b.inputs["Normal"])
    return m


def mat_gramado(name="Gramado", a=None, b=None, faixa=1.0, padrao="listras", xadrez=False):
    """Gramado procedural: faixas de corte (listras/xadrez) + ruido de fibra + bump."""
    a = a or PAL["grama"]
    b = b or PAL["grama_cl"]
    m = mat(name, a, 0.9)
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    # faixa = pingpong(x/faixa) arredondado
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.inputs[1].default_value = faixa
    nt.links.new(sep.outputs["X"], div.inputs[0])
    fl = nt.nodes.new("ShaderNodeMath")
    fl.operation = "FLOOR"
    nt.links.new(div.outputs[0], fl.inputs[0])
    if xadrez:
        div2 = nt.nodes.new("ShaderNodeMath")
        div2.operation = "DIVIDE"
        div2.inputs[1].default_value = faixa
        nt.links.new(sep.outputs["Y"], div2.inputs[0])
        fl2 = nt.nodes.new("ShaderNodeMath")
        fl2.operation = "FLOOR"
        nt.links.new(div2.outputs[0], fl2.inputs[0])
        soma = nt.nodes.new("ShaderNodeMath")
        soma.operation = "ADD"
        nt.links.new(fl.outputs[0], soma.inputs[0])
        nt.links.new(fl2.outputs[0], soma.inputs[1])
        fonte = soma
    else:
        fonte = fl
    md = nt.nodes.new("ShaderNodeMath")
    md.operation = "MODULO"
    md.inputs[1].default_value = 2.0
    nt.links.new(fonte.outputs[0], md.inputs[0])
    # fibra
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 90
    n.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    cor = nt.nodes.new("ShaderNodeMix")
    cor.data_type = "RGBA"
    cor.inputs[6].default_value = (*a, 1)
    cor.inputs[7].default_value = (*b, 1)
    nt.links.new(md.outputs[0], cor.inputs["Factor"])
    var = nt.nodes.new("ShaderNodeMix")
    var.data_type = "RGBA"
    var.inputs["Factor"].default_value = 0.0
    nt.links.new(cor.outputs[2], var.inputs[6])
    var.inputs[7].default_value = (a[0] * 0.5, a[1] * 0.55, a[2] * 0.5, 1)
    nm = nt.nodes.new("ShaderNodeMath")
    nm.operation = "MULTIPLY"
    nm.inputs[1].default_value = 0.35
    nt.links.new(n.outputs["Fac"], nm.inputs[0])
    nt.links.new(nm.outputs[0], var.inputs["Factor"])
    nt.links.new(var.outputs[2], bs.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump")
    bm.inputs["Strength"].default_value = 0.6
    bm.inputs["Distance"].default_value = 0.01
    nt.links.new(n.outputs["Fac"], bm.inputs["Height"])
    nt.links.new(bm.outputs["Normal"], bs.inputs["Normal"])
    return m


# -------------------------------------------------------------- primitivas
def _suave(o, bevel=0.0, seg=3):
    """Shade smooth + bisel com normais endurecidas (borda limpa sem auto-smooth)."""
    if o.type == "MESH":
        o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
    if bevel:
        mod = o.modifiers.new("Bisel", "BEVEL")
        mod.width = bevel
        mod.segments = seg
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = True


def box(name, location, dimensions, material=None, bevel=0.03, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o = bpy.context.object
    o.name = name
    o.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        o.rotation_euler = rot
    if material:
        o.data.materials.append(material)
    _suave(o, min(bevel, min(dimensions) * 0.45))
    return o


def sphere(name, location, scale, material=None, segments=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=1, location=location)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    if material:
        o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def rod(name, start, end, radius, material=None, vertices=16, radius2=None, tampas=True):
    """Cilindro/tronco de cone entre dois pontos."""
    s, e = Vector(start), Vector(end)
    d = e - s
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                    radius2=radius if radius2 is None else radius2,
                                    depth=d.length, location=(s + e) * 0.5)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    if material:
        o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def membro(name, a, b, r1, r2, material, vertices=16):
    """Segmento arredondado (capsula cônica): tronco + esferas nas juntas."""
    o = rod(name, a, b, r1, material, vertices, radius2=r2)
    sphere(name + " j1", a, (r1,) * 3, material, 16, 10)
    sphere(name + " j2", b, (r2,) * 3, material, 16, 10)
    return o


def fundir(objs, nome):
    """Converte (aplica modificadores/curvas/texto) e junta tudo em UM objeto de malha.
    O destino e um objeto novo, sem rotacao, na origem (evita herdar a rotacao de uma peca)."""
    objs = [o for o in objs if o.name in bpy.data.objects]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    alvo = bpy.data.objects.new(nome + "_fusao", bpy.data.meshes.new(nome))
    bpy.context.collection.objects.link(alvo)
    alvo.select_set(True)
    bpy.context.view_layer.objects.active = alvo
    bpy.ops.object.join()
    alvo.name = nome
    return alvo


def stroke(name, points, material=None, radius=0.02, fechar=False):
    c = bpy.data.curves.new(name, "CURVE")
    c.dimensions = "3D"
    c.bevel_depth = radius
    c.bevel_resolution = 3
    c.use_fill_caps = True
    s = c.splines.new("POLY")
    s.points.add(len(points) - 1)
    for p, co in zip(s.points, points):
        p.co = (*co, 1)
    s.use_cyclic_u = fechar
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    if material:
        o.data.materials.append(material)
    return o


def fita(name, pontos, largura, z, material, fechar=False):
    """Faixa plana (linha de campo nitida) seguindo uma polilinha 2D."""
    bm = bmesh.new()
    n = len(pontos)
    hw = largura / 2
    lados = []
    for i, p in enumerate(pontos):
        a = Vector(pontos[(i - 1) % n] if (fechar or i > 0) else pontos[i])
        b = Vector(pontos[(i + 1) % n] if (fechar or i < n - 1) else pontos[i])
        t = (b - a)
        if t.length == 0:
            t = Vector((1, 0))
        t.normalize()
        nrm = Vector((-t.y, t.x))
        lados.append((bm.verts.new((p[0] + nrm.x * hw, p[1] + nrm.y * hw, z)),
                      bm.verts.new((p[0] - nrm.x * hw, p[1] - nrm.y * hw, z))))
    rng = range(n) if fechar else range(n - 1)
    for i in rng:
        l0, r0 = lados[i]
        l1, r1 = lados[(i + 1) % n]
        bm.faces.new((l0, l1, r1, r0))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def arco(cx, cy, r, a0, a1, n=40):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n),
             cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def texto_3d(name, label, location, size, material=None, rot=(math.pi / 2, 0, 0),
             extrude=0.004, bold=True):
    bpy.ops.object.text_add(location=location, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.body = label
    o.data.align_x = "CENTER"
    o.data.align_y = "CENTER"
    o.data.size = size
    o.data.extrude = extrude
    if material:
        o.data.materials.append(material)
    return o


# ---------------------------------------------------- malhas em lote (bmesh)
_CUBO_V = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, .5, -.5), (-.5, .5, -.5),
           (-.5, -.5, .5), (.5, -.5, .5), (.5, .5, .5), (-.5, .5, .5)]
_CUBO_F = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def _esfera_tpl(seg=8, ane=5):
    v = [(0, 0, 1)]
    for j in range(1, ane):
        th = math.pi * j / ane
        for i in range(seg):
            ph = math.tau * i / seg
            v.append((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
    v.append((0, 0, -1))
    f = []
    for i in range(seg):
        f.append((0, 1 + i, 1 + (i + 1) % seg))
    for j in range(ane - 2):
        for i in range(seg):
            a0, a1 = 1 + j * seg + i, 1 + j * seg + (i + 1) % seg
            b0, b1 = a0 + seg, a1 + seg
            f.append((a0, b0, b1, a1))
    last = len(v) - 1
    base = 1 + (ane - 2) * seg
    for i in range(seg):
        f.append((base + i, last, base + (i + 1) % seg))
    return v, f


_ESF = _esfera_tpl()


class Lote:
    """Acumula milhares de cubos/esferas coloridos em UM objeto com N materiais (geometria bruta, rapido)."""

    def __init__(self, nome, materiais):
        self.nome = nome
        self.mats = materiais
        self.V, self.F, self.M = [], [], []

    def _add(self, verts, faces, mi):
        o = len(self.V)
        self.V.extend(verts)
        self.F.extend(tuple(i + o for i in f) for f in faces)
        self.M.extend([mi] * len(faces))

    def cubo(self, centro, dim, mi=0, rotz=0.0):
        cx, cy, cz = centro
        c, s = (math.cos(rotz), math.sin(rotz)) if rotz else (1.0, 0.0)
        vs = []
        for x, y, z in _CUBO_V:
            x, y, z = x * dim[0], y * dim[1], z * dim[2]
            vs.append((cx + x * c - y * s, cy + x * s + y * c, cz + z))
        self._add(vs, _CUBO_F, mi)

    def esfera(self, centro, raio, mi=0, esc=(1, 1, 1)):
        cx, cy, cz = centro
        vs = [(cx + x * raio * esc[0], cy + y * raio * esc[1], cz + z * raio * esc[2]) for x, y, z in _ESF[0]]
        self._add(vs, _ESF[1], mi)

    def criar(self):
        me = bpy.data.meshes.new(self.nome)
        me.from_pydata(self.V, [], self.F)
        me.update()
        me.polygons.foreach_set("material_index", self.M)
        me.polygons.foreach_set("use_smooth", [False] * len(self.F))
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(self.nome, me)
        bpy.context.collection.objects.link(o)
        return o


# -------------------------------------------------------------------- luz
def _mundo(cor_luz=(0.75, 0.85, 1.0), forca=0.9, fundo=None):
    """Mundo: ilumina com cor_luz e, para a camera, mostra degrade 'fundo'."""
    w = bpy.context.scene.world or bpy.data.worlds.new("Mundo")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    luz = nt.nodes.new("ShaderNodeBackground")
    luz.inputs["Color"].default_value = (*cor_luz, 1)
    luz.inputs["Strength"].default_value = forca
    if fundo is None:
        nt.links.new(luz.outputs[0], out.inputs[0])
        return
    topo, base = fundo
    lp = nt.nodes.new("ShaderNodeLightPath")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].color = (*base, 1)
    rampa.color_ramp.elements[1].color = (*topo, 1)
    nt.links.new(sep.outputs["Y"], rampa.inputs[0])
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(rampa.outputs[0], bg.inputs["Color"])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(luz.outputs[0], mix.inputs[1])
    nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])


def luz_estudio(noturno=False, fundo=None, sol_forca=None, azimute=-35, elevacao=48):
    """Sol suave + ceu + rim light fria. noturno=True => escuro azulado (refletores fazem o resto)."""
    if noturno:
        _mundo((0.20, 0.28, 0.55), 0.18, fundo)
        forca = 0.6 if sol_forca is None else sol_forca
        cor = (0.60, 0.70, 1.0)
    else:
        _mundo((0.78, 0.86, 1.0), 0.85, fundo)
        forca = 3.4 if sol_forca is None else sol_forca
        cor = (1.0, 0.95, 0.86)
    bpy.ops.object.light_add(type="SUN")
    s = bpy.context.object
    s.name = "Sol"
    s.data.energy = forca
    s.data.color = cor
    s.data.angle = math.radians(5)
    s.rotation_euler = (math.radians(90 - elevacao), 0, math.radians(azimute + 180))
    bpy.ops.object.light_add(type="AREA", location=(14, 12, 9))
    r = bpy.context.object
    r.name = "Rim"
    r.data.energy = 90 if not noturno else 40
    r.data.color = (0.75, 0.85, 1.0)
    r.data.size = 10
    r.rotation_euler = (Vector((0, 0, 1.0)) - r.location).to_track_quat("-Z", "Y").to_euler()


def ponto_luz(nome, loc, energia, cor=(1, 0.95, 0.85), raio=0.15):
    bpy.ops.object.light_add(type="POINT", location=loc)
    l = bpy.context.object
    l.name = nome
    l.data.energy = energia
    l.data.color = cor
    l.data.shadow_soft_size = raio
    return l


def spot(nome, loc, alvo, energia, cor=(1, 0.95, 0.85), angulo=70, blend=0.5):
    bpy.ops.object.light_add(type="SPOT", location=loc)
    l = bpy.context.object
    l.name = nome
    l.data.energy = energia
    l.data.color = cor
    l.data.spot_size = math.radians(angulo)
    l.data.spot_blend = blend
    l.data.shadow_soft_size = 0.3
    l.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return l


def chao_sombra(tamanho=80, z=0.0, cor=(0.50, 0.58, 0.64)):
    """Chao de estudio: recebe sombras; mesma cor do fundo => horizonte invisivel."""
    bpy.ops.mesh.primitive_plane_add(size=tamanho, location=(0, 0, z))
    p = bpy.context.object
    p.name = "ChaoSombra"
    p.data.materials.append(mat("Chao estudio", cor, 0.9))
    return p


# ----------------------------------------------------------------- camera
def camera_iso(location=(14.8, -19.0, 21.5), ortho_scale=23.0, alvo=(0, 0, 1.0),
               nome="Camera ISO", perspectiva=False, lente=60):
    bpy.ops.object.camera_add(location=location)
    cam = bpy.context.object
    cam.name = nome
    cam.rotation_euler = (Vector(alvo) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if perspectiva:
        cam.data.lens = lente
    else:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho_scale
    bpy.context.scene.camera = cam
    return cam


def camera_orbita(alvo, dist, azimute, elevacao, ortho_scale=None, lente=70):
    """Camera em coordenadas esfericas (azimute 0 = olhando de -Y). ortho_scale=None => perspectiva."""
    az, el = math.radians(azimute), math.radians(elevacao)
    t = Vector(alvo)
    pos = t + Vector((dist * math.sin(az) * math.cos(el),
                      -dist * math.cos(az) * math.cos(el), dist * math.sin(el)))
    if ortho_scale is None:
        return camera_iso(tuple(pos), 1, alvo, perspectiva=True, lente=lente)
    return camera_iso(tuple(pos), ortho_scale, alvo)


# ----------------------------------------------------------------- render
def render(path, res_x=1200, res_y=900, samples=64, transparente=False, motor="EEVEE"):
    """motor 'EEVEE' (rapido, raytracing+sombras suaves) ou 'CYCLES' (final, lento em CPU)."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sc = bpy.context.scene
    if motor == "CYCLES":
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
        sc.cycles.max_bounces = 5
        sc.cycles.sample_clamp_indirect = 8
    else:
        try:
            sc.render.engine = "BLENDER_EEVEE_NEXT"
        except TypeError:
            sc.render.engine = "BLENDER_EEVEE"
        e = sc.eevee
        for attr, val in (("taa_render_samples", samples), ("use_shadows", True),
                          ("use_raytracing", True), ("shadow_ray_count", 2),
                          ("shadow_step_count", 8), ("use_shadow_jitter_viewport", False),
                          ("fast_gi_method", "GLOBAL_ILLUMINATION"), ("gtao_distance", 0.4)):
            try:
                setattr(e, attr, val)
            except (AttributeError, TypeError):
                pass
        for l in bpy.data.lights:
            try:
                l.use_shadow = True
                if l.type == "SUN":
                    l.use_contact_shadow = True
            except AttributeError:
                pass
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparente else "RGB"
    sc.render.film_transparent = transparente
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Punchy"
    except TypeError:
        sc.view_settings.view_transform = "Standard"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Render OK:", path)


# compat com a v1
render_transparente = lambda path, res_x=1200, res_y=900, samples=96: render(
    path, res_x, res_y, samples, transparente=True)


def exportar_glb(path, colecao_nome=None):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = (bpy.data.collections[colecao_nome].all_objects if colecao_nome
            else [o for o in bpy.context.scene.objects if o.type in ("MESH", "CURVE", "EMPTY")])
    for o in objs:
        if o.name != "ChaoSombra" and o.type in ("MESH", "CURVE", "EMPTY", "FONT"):
            o.select_set(True)
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_apply=True)
        print("GLB OK:", path)
    except Exception as e:  # exportador pode faltar em builds minimos
        print("GLB falhou:", e)


def args_cli():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
