"""03_props / vendedores.py — vendedores ambulantes e de lanche (usa o gancho `acessorio` do humano).
  ambulante  — bandeja de lanches pendurada no pescoco + bone
  bebidas    — caixa de isopor a tiracolo + bone
  pipoqueiro — carrinho de pipoca com toldo listrado (humano atras)
  sorveteiro — carrinho de sorvete com guarda-sol
  guarda     — segurança / staff com colete amarelo e radio

criar_vendedor(tipo, nome, x, y, yaw=0, escala=1.0, ...)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "02_personagens"))
import bpy
from mathutils import Vector
import lib_base as LB
import humano as H

COM = {  # comida: (cor, forma)
    "hotdog": ((0.75, 0.30, 0.10), "caixa"), "pipoca": ((0.98, 0.90, 0.55), "esfera"),
    "refri": ((0.8, 0.05, 0.08), "lata"), "agua": ((0.2, 0.55, 0.95), "lata"),
    "amendoim": ((0.55, 0.35, 0.15), "esfera"), "sorvete": ((0.98, 0.65, 0.78), "esfera"),
}


def _bone(ctx, cor=(0.9, 0.1, 0.1)):
    m = LB.mat(f"{ctx['nome']}|bone", cor, 0.7)
    h = ctx["head"]
    LB.sphere("bone", h + Vector((0, -0.012, 0.065)), (0.19, 0.185, 0.125), m, 24, 14)
    LB.box("aba", h + Vector((0, 0.17, 0.06)), (0.2, 0.12, 0.018), m, 0.01)


def _item(tipo, pos, esc=1.0):
    cor, forma = COM[tipo]
    m = LB.mat(f"item {tipo}", cor, 0.5)
    if forma == "esfera":
        LB.sphere("item", pos, (0.035 * esc,) * 3, m, 10, 6)
    elif forma == "lata":
        LB.rod("item", pos, pos + Vector((0, 0, 0.07 * esc)), 0.018 * esc, m, 10)
    else:
        LB.box("item", pos, (0.1 * esc, 0.035 * esc, 0.03 * esc), m, 0.008)


def _acc_bandeja(ctx):
    _bone(ctx)
    n = ctx["neck"]
    tab = LB.mat(f"{ctx['nome']}|bandeja", (0.92, 0.88, 0.75), 0.6)
    LB.box("bandeja", n + Vector((0, 0.17, -0.19)), (0.34, 0.2, 0.018), tab, 0.008, rot=(0.12, 0, 0))
    for sx in (-1, 1):
        LB.rod("alca", n + Vector((sx * 0.15, 0.17, -0.18)), n + Vector((sx * 0.07, -0.03, 0.0)), 0.008, tab, 6)
    rng = random.Random(len(ctx["nome"]))
    for i in range(6):
        t = list(COM)[rng.randrange(len(COM))]
        _item(t, n + Vector((-0.12 + i * 0.048, 0.17 + rng.uniform(-0.04, 0.04), -0.165)))


def _acc_bebidas(ctx):
    _bone(ctx, (0.1, 0.35, 0.8))
    n = ctx["neck"]
    LB.box("isopor", n + Vector((0.0, 0.16, -0.25)), (0.3, 0.18, 0.16), LB.mat("isopor", (0.95, 0.95, 0.95), 0.7), 0.025)
    LB.box("tampa", n + Vector((0.0, 0.16, -0.165)), (0.31, 0.19, 0.02), LB.mat("isopor tampa", (0.1, 0.4, 0.85), 0.4), 0.01)
    for sx in (-1, 1):
        LB.rod("alca", n + Vector((sx * 0.14, 0.12, -0.17)), n + Vector((sx * 0.07, -0.03, 0.0)), 0.008, LB.mat("alca", (0.1, 0.1, 0.1), 0.6), 6)
    for i in range(3):
        _item("agua" if i % 2 else "refri", n + Vector((-0.08 + i * 0.08, 0.16, -0.15)))


def _acc_colete(ctx):
    n = ctx["neck"]
    m = LB.mat("colete", (0.95, 0.85, 0.05), 0.5, emissao=(0.9, 0.8, 0.0), forca=0.15)
    LB.box("colete", ctx["centro"], (0.30, 0.19, 0.28), m, 0.05)
    LB.box("faixa colete", ctx["centro"] + Vector((0, 0.0, -0.04)), (0.305, 0.195, 0.025), LB.mat("refletiva", (0.85, 0.9, 0.9), 0.3, metallic=0.5), 0.005)
    LB.box("radio", ctx["centro"] + Vector((0.1, 0.1, 0.1)), (0.04, 0.03, 0.09), LB.mat("radio", (0.05, 0.05, 0.05), 0.4), 0.008)


def criar_vendedor(tipo="ambulante", nome="Vendedor", x=0.0, y=0.0, yaw=0.0, escala=1.0, **kw):
    acc = {"ambulante": _acc_bandeja, "bebidas": _acc_bebidas, "guarda": _acc_colete}.get(tipo)
    kw.setdefault("camisa", {"ambulante": (0.95, 0.95, 0.9), "bebidas": (0.95, 0.95, 0.95), "guarda": (0.05, 0.06, 0.12)}.get(tipo, (0.9, 0.9, 0.9)))
    kw.setdefault("calcao", (0.1, 0.12, 0.2))
    kw.setdefault("papel", "tecnico" if False else "jogador")
    kw.setdefault("gola", False)
    kw.setdefault("listra_meia", False)
    kw.setdefault("meia", (0.9, 0.9, 0.9))
    kw.setdefault("pose", "parado")
    return H.criar_humano(nome, x, y, yaw=yaw, escala=escala, acessorio=acc, **kw)


def criar_carrinho(tipo="pipoca", x=0.0, y=0.0, yaw=0.0, nome="Carrinho", escala=1.6):
    """Carrinho de pipoca (vidro + toldo listrado) ou sorvete (guarda-sol). Origem no chao."""
    antes = set(bpy.data.objects)
    X0, Y0, YAW0 = x, y, yaw
    x = y = yaw = 0.0
    from mathutils import Matrix
    M = Matrix.Rotation(yaw, 3, "Z")
    P = lambda v: M @ Vector(v) + Vector((x, y, 0))
    cor = (0.85, 0.08, 0.1) if tipo == "pipoca" else (0.1, 0.6, 0.85)
    corpo = LB.mat(f"{nome}|corpo", cor, 0.35, verniz=0.7)
    br = LB.mat(f"{nome}|branco", (0.96, 0.96, 0.93), 0.4)
    vidro = LB.mat(f"{nome}|vidro", (0.7, 0.85, 0.9), 0.03, alpha=0.3)
    metal = LB.mat(f"{nome}|metal", (0.75, 0.75, 0.78), 0.3, metallic=0.9)
    b = lambda n_, l, d, m_, bv=0.015, r=None: LB.box(n_, P(l), d, m_, bv).__setattr__("rotation_euler", (0, 0, yaw))
    b("base", (0, 0, 0.26), (0.46, 0.32, 0.28), corpo, 0.03)
    b("tampo", (0, 0, 0.415), (0.5, 0.36, 0.03), br, 0.01)
    for sx in (-1, 1):
        LB.sphere("roda", P((sx * 0.25, -0.1, 0.1)), (0.1, 0.03, 0.1), metal, 14, 8).rotation_euler = (0, 0, yaw)
    LB.rod("alca carrinho", P((-0.2, -0.2, 0.3)), P((0.2, -0.2, 0.3)), 0.012, metal, 8)
    LB.rod("alca", P((-0.2, -0.17, 0.3)), P((-0.2, -0.28, 0.42)), 0.01, metal, 8)
    LB.rod("alca", P((0.2, -0.17, 0.3)), P((0.2, -0.28, 0.42)), 0.01, metal, 8)
    if tipo == "pipoca":
        b("vitrine", (0, 0.0, 0.62), (0.44, 0.3, 0.36), vidro, 0.01)
        pip = LB.mat("pipoca", (0.99, 0.92, 0.6), 0.9)
        rng = random.Random(4)
        for i in range(36):
            LB.sphere("pipoca", P((rng.uniform(-0.18, 0.18), rng.uniform(-0.1, 0.1), 0.47 + rng.random() * 0.18)), (0.032,) * 3, pip, 8, 5)
        for i in range(5):
            LB.box("toldo", P((-0.2 + i * 0.1, 0.0, 0.86)), (0.1, 0.46, 0.025), corpo if i % 2 == 0 else br, 0.004).rotation_euler = (0.18, 0, yaw)
        for sx in (-1, 1):
            LB.rod("coluna", P((sx * 0.23, 0.15, 0.43)), P((sx * 0.23, 0.15, 0.84)), 0.012, metal, 8)
    else:
        LB.rod("mastro", P((0, 0, 0.43)), P((0, 0, 1.0)), 0.014, metal, 8)
        for i in range(8):
            a = math.tau * i / 8
            a2 = math.tau * (i + 1) / 8
            # guarda-sol faceta (gomos coloridos)
            c = P((0, 0, 1.0))
            v = [c + Vector((0, 0, 0.12)), c + M @ Vector((math.cos(a) * 0.38, math.sin(a) * 0.38, -0.0)),
                 c + M @ Vector((math.cos(a2) * 0.38, math.sin(a2) * 0.38, -0.0))]
            me = bpy.data.meshes.new("gomo")
            me.from_pydata([tuple(q) for q in v], [], [(0, 1, 2), (0, 2, 1)])
            o = bpy.data.objects.new("gomo", me)
            bpy.context.collection.objects.link(o)
            o.data.materials.append(corpo if i % 2 == 0 else br)
        sv = [(0.98, 0.65, 0.78), (0.95, 0.9, 0.5), (0.45, 0.25, 0.12)]
        for i, c_ in enumerate(sv):
            LB.sphere("sorvete", P((-0.1 + i * 0.1, 0.0, 0.46)), (0.04, 0.04, 0.035), LB.mat("sorv", c_, 0.4), 10, 6)
    novos = [o for o in bpy.data.objects if o not in antes]
    o = LB.fundir(novos, nome)
    o.scale = (escala,) * 3
    o.rotation_euler = (0, 0, YAW0)
    o.location = (X0, Y0, H.Z_CHAO)
    return o


def variacao_a():
    LB.limpar_cena()
    H.Z_CHAO = 0.0
    criar_vendedor("ambulante", "Ambulante lanche", -1.0, 0, yaw=math.pi + 0.3, cabelo="curto", pele="morena", cor_cabelo=(0.05, 0.03, 0.03))
    criar_vendedor("bebidas", "Vendedor bebidas", 0.0, 0, yaw=math.pi, cabelo="afro", pele="negra")
    criar_vendedor("guarda", "Seguranca", 1.0, 0, yaw=math.pi - 0.3, cabelo="careca", pele="clara")


def variacao_b():
    LB.limpar_cena()
    criar_carrinho("pipoca", -1.0, 0.0, yaw=math.pi)
    criar_vendedor("guarda", "Pipoqueiro", -1.0, 0.55, yaw=math.pi, pele="parda", cabelo="curto", camisa=(0.85, 0.08, 0.1))
    criar_carrinho("sorvete", 1.0, 0.0, yaw=math.pi)
    criar_vendedor("guarda", "Sorveteiro", 1.0, 0.55, yaw=math.pi, pele="morena", cabelo="coque", camisa=(0.2, 0.6, 0.85))


CENAS = {"A": variacao_a, "B": variacao_b}
CAM = {"A": ((0, 0, 0.5), 5.0, -22, 14), "B": ((0, -0.1, 0.5), 4.6, -22, 16)}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/vend.png"
    q = (a[1] if len(a) > 1 else "A").upper()
    CENAS[q]()
    LB.chao_sombra()
    al, d, az, el = CAM[q]
    LB.camera_orbita(al, d, az, el, lente=65)
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1000, 800)
