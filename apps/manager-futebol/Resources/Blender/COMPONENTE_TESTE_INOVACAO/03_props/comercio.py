"""03_props / comercio.py — comercio do entorno do estadio (v2).
  criar_barraca(tipo)  — lanche | bebidas | souvenir | churrasco : toldo listrado, balcao, cardapio luminoso
  criar_food_truck()   — caminhao de lanche com janela, toldo e luzes
  criar_bilheteria()   — guiches com catracas e portal
Todos devolvem 1 objeto fundido (origem no chao) com x, y, yaw, escala.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "02_personagens"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import lib_base as LB
import humano as H
import vendedores as V

TIPOS = {
    "lanche": dict(c1=(0.9, 0.12, 0.08), c2=(0.98, 0.85, 0.2), titulo="LANCHE", luz=(1.0, 0.7, 0.2)),
    "bebidas": dict(c1=(0.1, 0.4, 0.85), c2=(0.95, 0.95, 0.95), titulo="BEBIDAS", luz=(0.3, 0.8, 1.0)),
    "souvenir": dict(c1=(0.03, 0.33, 0.32), c2=(0.95, 0.7, 0.1), titulo="LOJA", luz=(1.0, 0.85, 0.3)),
    "churrasco": dict(c1=(0.15, 0.15, 0.17), c2=(0.9, 0.35, 0.1), titulo="ESPETO", luz=(1.0, 0.45, 0.1)),
}


def _fim(antes, nome, x, y, yaw, escala):
    novos = [o for o in bpy.data.objects if o not in antes]
    o = LB.fundir(novos, nome)
    o.scale = (escala,) * 3
    o.rotation_euler = (0, 0, yaw)
    o.location = (x, y, H.Z_CHAO)
    return o


def criar_barraca(tipo="lanche", x=0.0, y=0.0, yaw=0.0, escala=1.0, nome="Barraca"):
    antes = set(bpy.data.objects)
    t = TIPOS[tipo]
    mad = LB.mat(f"{nome}|madeira", (0.55, 0.36, 0.18), 0.6)
    c1 = LB.mat(f"{nome}|c1", t["c1"], 0.55, sheen=0.4)
    c2 = LB.mat(f"{nome}|c2", t["c2"], 0.55, sheen=0.4)
    luz = LB.mat(f"{nome}|luz", t["luz"], 0.3, emissao=t["luz"], forca=3.0)
    esc = LB.mat(f"{nome}|quadro", (0.04, 0.05, 0.06), 0.5)
    w, d = 1.5, 0.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            LB.rod("poste", (sx * w / 2, sy * d / 2, 0), (sx * w / 2, sy * d / 2, 0.95 if sy > 0 else 0.8), 0.022, mad, 10)
    LB.box("balcao", (0, d / 2 - 0.12, 0.42), (w, 0.28, 0.07), mad, 0.015)
    LB.box("balcao frente", (0, d / 2 - 0.13, 0.22), (w - 0.06, 0.04, 0.4), c1, 0.012)
    LB.box("parede fundo", (0, -d / 2, 0.45), (w, 0.04, 0.9), mad, 0.01)
    n = 10
    for i in range(n):  # toldo listrado inclinado
        xx = -w / 2 + (i + 0.5) * w / n
        LB.box("toldo", (xx, 0.02, 0.9), (w / n, d + 0.3, 0.025), c1 if i % 2 == 0 else c2, 0.004, rot=(0.17, 0, 0))
    LB.box("franja toldo", (0, d / 2 + 0.16, 0.8), (w + 0.04, 0.025, 0.1), c2, 0.006)
    LB.box("placa luminosa", (0, d / 2 + 0.07, 1.06), (0.9, 0.04, 0.17), esc, 0.012)
    LB.texto_3d("placa texto", t["titulo"], (0, d / 2 + 0.097, 1.06), 0.12, luz, rot=(math.pi / 2, 0, math.pi), extrude=0.008)
    LB.rod("luminaria", (-0.4, d / 2 + 0.12, 0.88), (-0.4, d / 2 + 0.12, 0.8), 0.008, mad, 6)
    LB.sphere("lampada", (-0.4, d / 2 + 0.12, 0.78), (0.03,) * 3, luz, 8, 6)
    LB.sphere("lampada", (0.4, d / 2 + 0.12, 0.78), (0.03,) * 3, luz, 8, 6)
    # mercadoria
    rng = random.Random(len(tipo))
    for i in range(10):
        xx = -0.62 + i * 0.138
        if tipo == "souvenir":
            LB.box("camisa", (xx, 0.0, 0.7 + rng.random() * 0.1), (0.1, 0.01, 0.14), LB.mat("cam", (rng.random(), rng.random() * 0.6, rng.random()), 0.7), 0.004)
        elif tipo == "bebidas":
            V._item(["refri", "agua"][i % 2], Vector((xx, d / 2 - 0.12, 0.455)), 1.2)
        elif tipo == "churrasco":
            LB.rod("espeto", (xx, d / 2 - 0.2, 0.47), (xx, d / 2 - 0.04, 0.5), 0.008, LB.mat("espeto", (0.55, 0.12, 0.08), 0.6), 6)
        else:
            V._item(list(V.COM)[i % 4], Vector((xx, d / 2 - 0.12, 0.455)), 1.2)
    if tipo == "churrasco":
        LB.box("churrasqueira", (0.0, 0.05, 0.22), (0.9, 0.3, 0.44), LB.mat("brasa base", (0.1, 0.1, 0.1), 0.5), 0.02)
        LB.box("brasa", (0.0, 0.05, 0.45), (0.8, 0.22, 0.02), LB.mat("brasa", (1.0, 0.25, 0.05), 0.4, emissao=(1, 0.25, 0.04), forca=6), 0.004)
    return _fim(antes, nome, x, y, yaw, escala)


def barraca_com_vendedor(tipo, x, y, yaw=0.0, escala=1.5, pele="morena", cabelo="curto", nome="Barraca"):
    """Barraca + vendedor atras do balcao (frente da barraca = +Y local)."""
    from mathutils import Matrix
    M = Matrix.Rotation(yaw, 3, "Z")
    b = criar_barraca(tipo, x, y, yaw, escala, nome)
    p = M @ Vector((0, -0.02 * escala, 0)) + Vector((x, y, 0))
    t = TIPOS[tipo]
    v = V.criar_vendedor("staff", nome + " vendedor", p.x, p.y, yaw=yaw, camisa=t["c1"], pele=pele, cabelo=cabelo)
    return b, v


def criar_food_truck(x=0.0, y=0.0, yaw=0.0, escala=1.0, cor=(0.95, 0.75, 0.1), nome="FoodTruck"):
    antes = set(bpy.data.objects)
    corpo = LB.mat(f"{nome}|corpo", cor, 0.3, verniz=0.8)
    br = LB.mat(f"{nome}|branco", (0.96, 0.96, 0.93), 0.4)
    esc = LB.mat(f"{nome}|escuro", (0.05, 0.06, 0.07), 0.4)
    vidro = LB.mat(f"{nome}|vidro", (0.5, 0.75, 0.85), 0.03, alpha=0.4)
    pneu = LB.mat(f"{nome}|pneu", (0.03, 0.03, 0.035), 0.8)
    luz = LB.mat(f"{nome}|luz", (1.0, 0.9, 0.6), 0.3, emissao=(1.0, 0.85, 0.5), forca=4)
    c1 = LB.mat(f"{nome}|toldo", (0.85, 0.1, 0.1), 0.6)
    LB.box("carroceria", (0.0, 0.0, 0.66), (2.2, 1.0, 0.9), corpo, 0.07)
    LB.box("cabine", (1.45, 0.0, 0.52), (0.75, 0.96, 0.62), corpo, 0.08)
    LB.box("para-brisa", (1.8, 0.0, 0.62), (0.03, 0.8, 0.28), vidro, 0.01)
    LB.box("faixa", (0.0, 0.0, 0.43), (2.22, 1.02, 0.1), br, 0.02)
    LB.box("janela", (0.0, 0.51, 0.78), (1.2, 0.03, 0.4), esc, 0.02)
    LB.box("balcao", (0.0, 0.62, 0.6), (1.3, 0.28, 0.04), br, 0.008)
    for i in range(8):
        LB.box("toldo", (-0.62 + i * 0.1775, 0.72, 1.14), (0.1775, 0.5, 0.02), c1 if i % 2 == 0 else br, 0.004, rot=(-0.28, 0, 0))
    for sx in (-0.45, 0.55, 1.45):
        for sy in (-1, 1):
            LB.rod("roda", (sx, sy * 0.46, 0.2), (sx, sy * 0.52, 0.2), 0.2, pneu, 18)
            LB.rod("calota", (sx, sy * 0.52, 0.2), (sx, sy * 0.53, 0.2), 0.1, br, 14)
    for i in range(7):
        LB.sphere("luz", (-0.62 + i * 0.2, 0.74, 1.02), (0.03,) * 3, luz, 8, 6)
    LB.texto_3d("nome", "FUTOS BURGER", (0.0, 0.52, 1.05), 0.16, br, rot=(math.pi / 2, 0, math.pi), extrude=0.01)
    LB.box("farol", (1.83, 0.3, 0.38), (0.03, 0.14, 0.09), luz, 0.01)
    LB.box("farol", (1.83, -0.3, 0.38), (0.03, 0.14, 0.09), luz, 0.01)
    return _fim(antes, nome, x, y, yaw, escala)


def criar_bilheteria(x=0.0, y=0.0, yaw=0.0, escala=1.0, nome="Bilheteria"):
    antes = set(bpy.data.objects)
    cor = LB.mat(f"{nome}|corpo", LB.PAL["teal"], 0.45, verniz=0.5)
    ouro = LB.mat(f"{nome}|ouro", LB.PAL["ouro"], 0.3, metallic=0.9)
    vidro = LB.mat(f"{nome}|vidro", (0.5, 0.75, 0.85), 0.03, alpha=0.35)
    luz = LB.mat(f"{nome}|luz", (0.3, 0.95, 0.9), 0.3, emissao=(0.3, 1.0, 0.9), forca=5)
    br = LB.mat(f"{nome}|branco", (0.95, 0.95, 0.92), 0.5)
    for i in range(3):
        xx = (i - 1) * 1.1
        LB.box("guiche", (xx, 0, 0.5), (0.9, 0.55, 1.0), cor, 0.04)
        LB.box("guiche vidro", (xx, 0.285, 0.72), (0.7, 0.02, 0.4), vidro, 0.0)
        LB.box("guiche balcao", (xx, 0.33, 0.52), (0.78, 0.14, 0.03), ouro, 0.008)
        LB.box("guiche teto", (xx, 0.05, 1.04), (1.0, 0.7, 0.07), cor, 0.025)
        LB.box("guiche led", (xx, 0.4, 1.0), (0.9, 0.02, 0.025), luz, 0.005)
    LB.box("portal", (0, 0.0, 1.32), (3.6, 0.22, 0.28), cor, 0.05)
    LB.box("portal ouro", (0, 0.12, 1.32), (3.62, 0.02, 0.05), ouro, 0.005)
    LB.texto_3d("portal texto", "BILHETERIA", (0, 0.125, 1.32), 0.14, br, rot=(math.pi / 2, 0, math.pi), extrude=0.008)
    for sx in (-1.7, 1.7):
        LB.box("pilar", (sx, 0, 0.7), (0.16, 0.2, 1.4), cor, 0.03)
    for i in range(5):  # catracas
        xx = -1.0 + i * 0.5
        LB.box("catraca base", (xx, 0.95, 0.2), (0.14, 0.14, 0.4), LB.mat("catraca", (0.7, 0.72, 0.75), 0.3, metallic=0.9), 0.02)
        for a in range(3):
            LB.rod("braco catraca", (xx, 0.95, 0.42), (xx + math.cos(a * 2.09) * 0.2, 0.95 + math.sin(a * 2.09) * 0.2, 0.42), 0.012, br, 6)
    return _fim(antes, nome, x, y, yaw, escala)


def variacao_a():
    LB.limpar_cena()
    for i, t in enumerate(("lanche", "bebidas", "souvenir", "churrasco")):
        barraca_com_vendedor(t, (i - 1.5) * 2.6, 0, yaw=math.pi, pele=["morena", "negra", "clara", "parda"][i],
                             cabelo=["curto", "afro", "coque", "careca"][i], nome=f"Barraca {t}")


def variacao_b():
    LB.limpar_cena()
    criar_food_truck(0, 0, yaw=math.pi + 0.5, escala=1.2)


def variacao_c():
    LB.limpar_cena()
    criar_bilheteria(0, 0, yaw=math.pi)


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c}
CAM = {"A": ((0, 0, 0.7), 16.0, -14, 12), "B": ((0, 0, 0.6), 5.5, -25, 16), "C": ((0, 0.5, 0.6), 6.5, -20, 14)}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/com.png"
    q = (a[1] if len(a) > 1 else "A").upper()
    CENAS[q]()
    LB.chao_sombra()
    al, d, az, el = CAM[q]
    LB.camera_orbita(al, d, az, el, lente=60)
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1200, 800)
