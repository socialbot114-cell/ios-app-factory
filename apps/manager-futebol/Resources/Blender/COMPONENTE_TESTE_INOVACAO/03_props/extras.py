"""03_props / extras.py — bandeira, banco de reservas, cones, barreiras, bolas, trofeu (v2).
Funcoes reutilizaveis: criar_bandeira(), criar_banco(), criar_cones(), criar_barreira(),
criar_saco_bolas(), criar_trofeu(), confete()
  TREINO  — cones em slalom, barreiras, saco de bolas, bandeira
  TROFEU  — trofeu de ouro em podio com confete
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "02_personagens"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_base as LB
import humano as H
import bola_trave as BT


def criar_bandeira(x=0.0, y=0.0, cor=(0.92, 0.12, 0.10), alt=0.62):
    mastro = LB.mat("Bandeira|mastro", (0.95, 0.95, 0.9), 0.3, metallic=0.4)
    pano = LB.mat("Bandeira|pano", cor, 0.7, sheen=0.4)
    LB.rod("Mastro escanteio", (x, y, 0), (x, y, alt), 0.014, mastro, 10)
    LB.sphere("Mastro ponta", (x, y, alt), (0.02,) * 3, mastro, 8, 6)
    # pano triangular com ondulacao
    bm = bmesh.new()
    n = 8
    larg, alto = 0.24, 0.15
    linhas = []
    for j in range(2):
        linha = []
        for i in range(n + 1):
            t = i / n
            z = alt - 0.02 - j * alto * (1 - t * 0.0) * (1 - 0.0)
            hh = alto * (1 - t * 0.75)
            zz = alt - 0.02 - j * hh
            linha.append(bm.verts.new((x + t * larg, y + math.sin(t * 5.0) * 0.018 * t, zz)))
        linhas.append(linha)
    for i in range(n):
        bm.faces.new((linhas[0][i], linhas[0][i + 1], linhas[1][i + 1], linhas[1][i]))
    me = bpy.data.meshes.new("Pano")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Bandeira pano", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(pano)
    sol = o.modifiers.new("Esp", "SOLIDIFY")
    sol.thickness = 0.004
    return o


def criar_banco(x=0.0, y=-5.0, yaw=0.0, assentos=6, ocupantes=3, cor=(0.04, 0.2, 0.2), nome="Banco"):
    """Banco coberto de reservas: corpo curvo de vidro + assentos + reservas sentados."""
    c = Vector((x, y, 0))
    R = lambda v: (Vector(v) @ __import__("mathutils").Matrix.Rotation(yaw, 3, "Z")) + c
    from mathutils import Matrix
    M = Matrix.Rotation(yaw, 3, "Z")
    P = lambda v: M @ Vector(v) + c
    corpo = LB.mat(f"{nome}|corpo", cor, 0.45, verniz=0.5)
    vidro = LB.mat(f"{nome}|vidro", (0.55, 0.78, 0.85), 0.04, alpha=0.22)
    assento = LB.mat(f"{nome}|assento", (0.85, 0.85, 0.80), 0.5, verniz=0.3)
    ouro = LB.mat(f"{nome}|ouro", LB.PAL["ouro"], 0.3, metallic=0.9)
    w = assentos * 0.36 + 0.3
    objs = []
    def b(n, loc, dim, m, bev=0.02, rot=None):
        o = LB.box(n, P(loc), dim, m, bev, rot=(rot or (0, 0, 0)) if False else None)
        o.rotation_euler = (0, 0, yaw)
        return o
    b(f"{nome} base", (0, 0.0, 0.03), (w, 0.9, 0.06), corpo, 0.02)
    b(f"{nome} fundo", (0, -0.4, 0.45), (w, 0.04, 0.9), vidro, 0.0)
    for sx in (-1, 1):
        b(f"{nome} lateral", (sx * w / 2, 0, 0.45), (0.04, 0.9, 0.9), vidro, 0.0)
        b(f"{nome} coluna", (sx * w / 2, 0.42, 0.45), (0.05, 0.05, 0.9), ouro, 0.01)
    b(f"{nome} teto", (0, 0.0, 0.92), (w + 0.1, 1.0, 0.06), corpo, 0.03)
    b(f"{nome} frisoteto", (0, 0.48, 0.92), (w + 0.1, 0.03, 0.07), ouro, 0.008)
    for i in range(assentos):
        ax = (i - (assentos - 1) / 2) * 0.36
        b(f"{nome} assento", (ax, 0.05, 0.22), (0.28, 0.28, 0.05), assento, 0.02)
        b(f"{nome} encosto", (ax, -0.12, 0.38), (0.28, 0.04, 0.26), assento, 0.02)
        b(f"{nome} pe", (ax, 0.05, 0.11), (0.05, 0.05, 0.2), corpo, 0.005)
    # reservas sentados, olhando para +Y local
    for i in range(min(ocupantes, assentos)):
        ax = (i - (assentos - 1) / 2) * 0.36
        pos = P((ax, 0.05, 0.0))
        H.criar_humano(f"{nome} reserva {i}", pos.x, pos.y, yaw=yaw, papel="jogador", pose="sentado",
                       camisa=LB.PAL["teal_cl"], detalhe=LB.PAL["ouro"], numero=12 + i,
                       cabelo=["curto", "afro", "careca", "coque"][i % 4],
                       pele=["morena", "negra", "clara", "parda"][i % 4], escala=0.9)


def criar_cones(pontos=((-2, 1), (-1, 1.5), (0, 1), (1, 1.5), (2, 1)), cor=(0.98, 0.42, 0.05)):
    laranja = LB.mat("Cone|laranja", cor, 0.45, verniz=0.6)
    branco = LB.mat("Cone|faixa", (0.95, 0.95, 0.95), 0.5)
    for i, (x, y) in enumerate(pontos):
        LB.box(f"Cone base {i}", (x, y, 0.012), (0.2, 0.2, 0.024), laranja, 0.01)
        LB.rod(f"Cone {i}", (x, y, 0.02), (x, y, 0.26), 0.092, laranja, 20, radius2=0.012)
        LB.rod(f"Cone faixa {i}", (x, y, 0.1), (x, y, 0.14), 0.0615, branco, 20, radius2=0.0555)


def criar_barreira(x=0, y=0, larg=0.7, alt=0.3, yaw=0.0, cor=(0.9, 0.12, 0.1)):
    vermelho = LB.mat("Barreira|poste", cor, 0.4, verniz=0.5)
    branco = LB.mat("Barreira|barra", (0.95, 0.95, 0.95), 0.4)
    from mathutils import Matrix
    M = Matrix.Rotation(yaw, 3, "Z")
    for s in (-1, 1):
        a = M @ Vector((s * larg / 2, 0, 0)) + Vector((x, y, 0))
        LB.rod("Barreira poste", a, a + Vector((0, 0, alt)), 0.022, vermelho, 12)
        LB.box("Barreira pe", a + Vector((0, 0, 0.012)), (0.05, 0.22, 0.024), vermelho, 0.006)
    a = M @ Vector((-larg / 2, 0, alt)) + Vector((x, y, 0))
    b = M @ Vector((larg / 2, 0, alt)) + Vector((x, y, 0))
    LB.rod("Barreira barra", a, b, 0.02, branco, 12)


def criar_saco_bolas(x=0, y=0, n=7, seed=3):
    rng = random.Random(seed)
    lona = LB.mat("Saco|lona", LB.PAL["teal_cl"], 0.9, sheen=0.5)
    LB.sphere("Saco", (x, y, 0.2), (0.28, 0.28, 0.2), lona, 24, 14)
    LB.rod("Saco alca", (x - 0.16, y, 0.36), (x + 0.16, y, 0.36), 0.016, LB.mat("Saco|alca", LB.PAL["ouro"], 0.5), 8)
    for i in range(n):
        a = rng.random() * math.tau
        r = rng.random() * 0.2
        BT.criar_bola(x + math.cos(a) * r, y + math.sin(a) * r, 0.34 + (i // 4) * 0.14 + rng.random() * 0.03,
                      raio=0.1, estilo=["classica", "colorida"][i % 2], nome=f"BolaSaco{i}")


def criar_trofeu(x=0.0, y=0.0, escala=1.0):
    """Taca de ouro por revolucao de perfil + alcas + base escalonada."""
    ouro = LB.mat("Trofeu|ouro", (1.0, 0.70, 0.12), 0.18, metallic=1.0)
    mogno = LB.mat("Trofeu|base", (0.07, 0.035, 0.025), 0.3, verniz=0.8)
    perfil = [(0.0, 0.0), (0.26, 0.0), (0.26, 0.05), (0.2, 0.09), (0.1, 0.14), (0.065, 0.2), (0.05, 0.3),
              (0.07, 0.42), (0.12, 0.5), (0.16, 0.56), (0.18, 0.66), (0.2, 0.78), (0.225, 0.9), (0.235, 1.0),
              (0.215, 1.0), (0.2, 0.9), (0.17, 0.74), (0.13, 0.64), (0.0, 0.62)]
    seg = 40
    V, F = [], []
    for (r, z) in perfil:
        for i in range(seg):
            a = math.tau * i / seg
            V.append((x + r * escala * math.cos(a), y + r * escala * math.sin(a), 0.28 * escala + z * 0.62 * escala))
    n = len(perfil)
    for j in range(n - 1):
        for i in range(seg):
            a0, a1 = j * seg + i, j * seg + (i + 1) % seg
            F.append((a0, a1, a1 + seg, a0 + seg))
    me = bpy.data.meshes.new("Trofeu")
    me.from_pydata(V, [], F)
    me.update()
    me.polygons.foreach_set("use_smooth", [True] * len(F))
    me.materials.append(ouro)
    o = bpy.data.objects.new("Trofeu", me)
    bpy.context.collection.objects.link(o)
    # alcas em arco
    for sgn in (-1, 1):
        pts = []
        for k in range(15):
            t = k / 14 * math.pi
            pts.append((x + sgn * (0.17 + 0.2 * math.sin(t)) * escala, y,
                        (0.28 + 0.62 * (0.80 - 0.26 * (1 - math.cos(t)) / 2 * 2 * 0.5 - 0.0) - 0.0 * t) * escala
                        - 0.0 + (0.0)))
        z0, z1 = (0.28 + 0.62 * 0.86) * escala, (0.28 + 0.62 * 0.52) * escala
        pts = [(x + sgn * (0.19 + 0.17 * math.sin(k / 14 * math.pi)) * escala, y,
                z0 + (z1 - z0) * (k / 14)) for k in range(15)]
        LB.stroke("Alca", pts, ouro, 0.028 * escala)
    LB.sphere("Bola trofeu", (x, y, (0.28 + 0.62 + 0.14) * escala), (0.12 * escala,) * 3, ouro, 24, 14)
    LB.box("Base 1", (x, y, 0.07 * escala), (0.7 * escala, 0.7 * escala, 0.14 * escala), mogno, 0.02)
    LB.box("Base 2", (x, y, 0.2 * escala), (0.5 * escala, 0.5 * escala, 0.12 * escala), mogno, 0.02)
    LB.box("Placa", (x, y - 0.351 * escala, 0.07 * escala), (0.3 * escala, 0.012, 0.07 * escala), ouro, 0.004)
    return o


def confete(n=220, raio=1.8, altura=2.6, seed=5):
    rng = random.Random(seed)
    cores = [LB.mat(f"Confete{i}", c, 0.5, emissao=c, forca=0.8) for i, c in enumerate(
        [LB.PAL["ouro"], LB.PAL["teal_cl"], LB.PAL["vermelho"], LB.PAL["branco"], (0.3, 0.5, 1.0), (0.95, 0.35, 0.7)])]
    lote = LB.Lote("Confete", cores)
    for i in range(n):
        a = rng.random() * math.tau
        r = raio * math.sqrt(rng.random())
        lote.cubo((math.cos(a) * r, math.sin(a) * r, 0.2 + rng.random() * altura),
                  (0.07, 0.04, 0.004), rng.randrange(len(cores)), rotz=rng.random() * math.tau)
    return lote.criar()


def variacao_treino():
    LB.limpar_cena()
    criar_cones(pontos=[(-2.2 + i * 0.75, 0.55 * (-1) ** i) for i in range(7)])
    criar_barreira(-1.5, -1.3, yaw=0.2)
    criar_barreira(-0.4, -1.45, yaw=0.0)
    criar_barreira(0.7, -1.3, yaw=-0.2)
    criar_saco_bolas(2.2, -1.0)
    criar_bandeira(-2.7, -1.2)
    BT.criar_bola(1.1, 0.9, estilo="colorida")


def variacao_trofeu():
    LB.limpar_cena()
    criar_trofeu(0, 0, 1.6)
    confete()
    pod = LB.mat("Podio", LB.PAL["teal"], 0.35, verniz=0.6)
    LB.box("Podio", (0, 0, -0.1), (3.2, 3.2, 0.2), pod, 0.08)
    LB.box("Podio ouro", (0, 0, 0.005), (3.25, 3.25, 0.02), LB.mat("Podio|ouro", LB.PAL["ouro"], 0.4, metallic=0.6), 0.0)


def variacao_banco():
    LB.limpar_cena()
    criar_banco(0, 0, yaw=math.pi, assentos=6, ocupantes=4)


CENAS = {"TREINO": variacao_treino, "TROFEU": variacao_trofeu, "BANCO": variacao_banco}
CAM = {"TREINO": ((0, -0.2, 0.1), 6.5, -25, 24, 55), "TROFEU": ((0, 0, 1.0), 6.0, -20, 14, 60), "BANCO": ((0, 0, 0.5), 5.0, -28, 18, 60)}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/extras.png"
    q = (a[1] if len(a) > 1 else "TREINO").upper()
    CENAS[q]()
    LB.chao_sombra(cor=(0.20, 0.45, 0.20) if q == "TREINO" else (0.50, 0.58, 0.64))
    al, d, az, el, ln = CAM[q]
    LB.camera_orbita(al, d, az, el, lente=ln)
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1000, 800)
