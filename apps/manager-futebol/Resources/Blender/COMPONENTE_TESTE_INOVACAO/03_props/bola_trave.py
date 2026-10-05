"""03_props / bola_trave.py — bola (icosaedro truncado real) + trave com rede de malha (v2).
  A) bola classica + trave simples
  B) bola colorida + rede densa
  C) bola neon noturna + trave premium com LED
Funcoes reutilizaveis: criar_bola(), criar_trave(), rede()
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB


def criar_bola(x=0, y=0, z=None, raio=0.14, estilo="classica", nome="Bola"):
    """estilo: classica | colorida | neon. Pentagonos escuros em icosaedro truncado."""
    cores = {
        "classica": ((0.95, 0.95, 0.93), (0.03, 0.03, 0.035), None),
        "colorida": ((0.97, 0.80, 0.10), (0.05, 0.25, 0.85), None),
        "neon": ((0.85, 1.0, 0.25), (0.02, 0.95, 0.55), (0.1, 1.0, 0.5)),
    }
    c_base, c_pent, c_em = cores[estilo]
    m_h = LB.mat(f"{nome}|couro", c_base, 0.28, verniz=0.8)
    m_p = LB.mat(f"{nome}|painel", c_pent, 0.3, verniz=0.6,
                 emissao=c_em, forca=3.0 if c_em else 0.0)
    m_s = LB.mat(f"{nome}|costura", tuple(v * 0.35 for v in c_base), 0.5)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    bmesh.ops.bevel(bm, geom=list(bm.verts), offset=33.3333, offset_type="PERCENT",
                    affect="VERTICES", segments=1)
    for f in bm.faces:
        f.material_index = 1 if len(f.verts) == 5 else 0
    orig = set(bm.faces)
    bmesh.ops.inset_individual(bm, faces=list(bm.faces), thickness=0.045, use_even_offset=True)
    ring = [f for f in bm.faces if f not in orig]
    for f in ring:
        f.material_index = 2
    so_ring = {v for f in ring for v in f.verts} - {v for f in orig for v in f.verts}
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True)
    for v in bm.verts:
        v.co = v.co.normalized()
    for v in so_ring:
        if v.is_valid:
            v.co *= 0.985
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m_h)
    me.materials.append(m_p)
    me.materials.append(m_s)
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.scale = (raio,) * 3
    o.location = (x, y, raio if z is None else z)
    o.rotation_euler = (0.4, 0.3, 0.8)
    return o


def rede(nome, p00, p10, p11, p01, nu=10, nv=6, folga=0.0, material=None, esp=0.006):
    """Plano de rede (grade + Wireframe). Pontos 3D dos 4 cantos; folga = barriga."""
    bm = bmesh.new()
    P = [Vector(p) for p in (p00, p10, p11, p01)]
    grid = []
    for j in range(nv + 1):
        linha = []
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            pt = (P[0] * (1 - u) + P[1] * u) * (1 - v) + (P[3] * (1 - u) + P[2] * u) * v
            n = ((P[1] - P[0]).cross(P[3] - P[0])).normalized()
            pt += n * folga * math.sin(math.pi * u) * math.sin(math.pi * v)
            linha.append(bm.verts.new(pt))
        grid.append(linha)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    w = o.modifiers.new("Fio", "WIREFRAME")
    w.thickness = esp
    w.use_replace = True
    if material:
        o.data.materials.append(material)
    return o


def criar_trave(x0=LB.HL, lado=1, larg=1.9, alt=0.85, prof=0.7,
                rede_densa=False, premium=False, nome="Trave"):
    """Trave em x0 abrindo para dentro do campo (lado=+1 gol da direita, -1 esquerda)."""
    s = lado
    metal = LB.mat(f"{nome}|poste", (0.96, 0.96, 0.94), 0.22, metallic=0.2, verniz=0.5)
    fio = LB.mat(f"{nome}|rede", (0.93, 0.93, 0.93), 0.7)
    r = 0.04
    yl, yr = -larg / 2, larg / 2
    LB.rod(f"{nome} poste E", (x0, yl, 0), (x0, yl, alt), r, metal, 20)
    LB.rod(f"{nome} poste D", (x0, yr, 0), (x0, yr, alt), r, metal, 20)
    LB.rod(f"{nome} travessao", (x0, yl - 0.0, alt), (x0, yr, alt), r, metal, 20)
    LB.sphere(f"{nome} canto E", (x0, yl, alt), (r * 1.02,) * 3, metal, 14, 10)
    LB.sphere(f"{nome} canto D", (x0, yr, alt), (r * 1.02,) * 3, metal, 14, 10)
    xb = x0 + s * prof
    zb = alt * 0.55
    for yy in (yl, yr):  # travas de fundo
        LB.rod(f"{nome} trava topo", (x0, yy, alt), (xb, yy, zb), 0.022, metal, 12)
        LB.rod(f"{nome} trava chao", (xb, yy, 0.0), (xb, yy, zb), 0.022, metal, 12)
        LB.rod(f"{nome} base", (x0, yy, 0.02), (xb, yy, 0.02), 0.022, metal, 12)
    LB.rod(f"{nome} barra fundo", (xb, yl, zb), (xb, yr, zb), 0.022, metal, 12)
    nu, nv = (18, 11) if rede_densa else (10, 6)
    esp = 0.005 if rede_densa else 0.007
    rede(f"{nome} rede fundo", (xb, yl, 0.0), (xb, yr, 0.0), (xb, yr, zb), (xb, yl, zb), nu, nv // 2 + 2, 0.0, fio, esp)
    rede(f"{nome} rede teto", (x0, yl, alt), (x0, yr, alt), (xb, yr, zb), (xb, yl, zb), nu, 5, 0.03, fio, esp)
    for yy in (yl, yr):
        rede(f"{nome} rede lado", (x0, yy, 0.0), (xb, yy, 0.0), (xb, yy, zb), (x0, yy, alt),
             6, nv, 0.0, fio, esp)
    # rede do fundo entre barra e teto
    rede(f"{nome} rede fundo alto", (xb, yl, zb), (xb, yr, zb), (xb, yr, zb), (xb, yl, zb), 1, 1, 0, fio)
    if premium:
        led = LB.mat(f"{nome}|led", (0.1, 0.9, 1.0), 0.3, emissao=(0.1, 0.9, 1.0), forca=6.0)
        LB.box(f"{nome} base LED", (x0 + s * 0.02, 0, 0.012), (0.07, larg + 0.16, 0.025), led, 0.008)
        for yy in (yl, yr):
            LB.rod(f"{nome} led poste", (x0 - s * 0.005, yy, 0.05), (x0 - s * 0.005, yy, alt - 0.05),
                   0.043, led, 12)


def _cena(estilo, densa, premium, noturno):
    LB.limpar_cena()
    criar_trave(x0=0, lado=1, rede_densa=densa, premium=premium)
    criar_bola(-0.9, -0.2, estilo=estilo)


def variacao_a():
    _cena("classica", False, False, False)


def variacao_b():
    _cena("colorida", True, False, False)


def variacao_c():
    _cena("neon", True, True, True)


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/prop.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    LB.chao_sombra(cor=(0.20, 0.45, 0.20) if q != "C" else (0.10, 0.16, 0.22))
    LB.camera_orbita((-0.1, 0, 0.35), 5.0, -35, 16, lente=70)
    LB.luz_estudio(noturno=(q == "C"), fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)) if q != "C" else ((0.06, 0.09, 0.16), (0.02, 0.03, 0.06)))
    LB.render(out, 1000, 800)
