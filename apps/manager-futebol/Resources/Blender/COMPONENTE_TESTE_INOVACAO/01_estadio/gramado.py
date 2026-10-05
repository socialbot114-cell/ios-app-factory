"""01_estadio / gramado.py — campo completo (v2). Dimensoes em lib_base (L x W).
  A) varzea     — terra batida, giz irregular, sem listras, 2 manchas de terra no gol
  B) municipal  — listras de corte, calcada de concreto, alambrado baixo
  C) premium    — gramado hibrido xadrez, linhas nitidas, placas LED ao redor, base teal
Marcacao completa: contorno, meio, circulo, marca central, grandes/pequenas areas,
marcas e arcos de penalti, arcos de escanteio.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import bpy
import lib_base as LB

L, W, HL, HW = LB.L, LB.W, LB.HL, LB.HW
MARGEM = 1.15  # calcada entre linha e arquibancada


def linhas(largura=0.05, cor=None, z=0.062, material=None):
    m = material or LB.mat("Linhas|giz", cor or LB.PAL["creme"], 0.9)
    f = lambda nome, pts, fechar=False: LB.fita(nome, pts, largura, z, m, fechar)
    f("Linha contorno", [(-HL, -HW), (HL, -HW), (HL, HW), (-HL, HW)], True)
    f("Linha meio", [(0, -HW), (0, HW)])
    f("Circulo central", LB.arco(0, 0, 0.95, 0, math.tau, 64), True)
    LB.fita("Marca central", LB.arco(0, 0, 0.07, 0, math.tau, 16), 0.07, z, m, True)
    for s in (-1, 1):
        # grande area 1.7 x 4.0 ; pequena area 0.65 x 2.0
        f("Grande area", [(s * HL, -2.0), (s * (HL - 1.7), -2.0), (s * (HL - 1.7), 2.0), (s * HL, 2.0)])
        f("Pequena area", [(s * HL, -1.0), (s * (HL - 0.65), -1.0), (s * (HL - 0.65), 1.0), (s * HL, 1.0)])
        px = s * (HL - 1.15)
        LB.fita("Marca penalti", LB.arco(px, 0, 0.06, 0, math.tau, 14), 0.06, z, m, True)
        # arco da area: circulo r=0.95 em torno do penalti, so a parte fora da grande area
        a = math.acos(0.55 / 0.95)
        if s == 1:
            pts = LB.arco(px, 0, 0.95, math.pi - a, math.pi + a, 24)
        else:
            pts = LB.arco(px, 0, 0.95, -a, a, 24)
        f("Arco da area", pts)
        for sy in (-1, 1):
            cx, cy = s * HL, sy * HW
            a0 = {(1, 1): math.pi, (1, -1): math.pi / 2, (-1, 1): -math.pi / 2, (-1, -1): 0}[(s, sy)]
            f("Escanteio", LB.arco(cx, cy, 0.22, a0, a0 + math.pi / 2, 10))


def _gramado(nome, a, b, faixa=1.2, xadrez=False, rugosidade=0.9):
    mg = LB.mat_gramado(nome, a, b, faixa=faixa, xadrez=xadrez)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0.06))
    p = bpy.context.object
    p.name = nome
    p.dimensions = (L + 0.1, W + 0.1, 0)
    bpy.ops.object.transform_apply(scale=True)
    p.data.materials.append(mg)
    # borda do tablado (grama sobe um pouco do concreto)
    LB.box(nome + " tablado", (0, 0, 0.022), (L + 0.12, W + 0.12, 0.044),
           LB.mat("Terra sob grama", (0.18, 0.12, 0.07), 0.95), 0.015)
    return p


def _calcada(cor, margem=MARGEM, h=0.05, bevel=0.06, nome="Calcada", rug=0.85):
    m = LB.mat_ruido(nome, cor, rug, escala=18, forca=0.8, bump=0.35)
    return LB.box(nome, (0, 0, h / 2 - 0.02), (L + 2 * margem, W + 2 * margem, h + 0.04), m, bevel)


def montar_a():
    """A) Varzea: terra batida e giz."""
    LB.colecao("Gramado")
    terra = LB.mat_ruido("Terra batida", (0.42, 0.28, 0.15), 0.95, escala=14, forca=1.0, bump=0.8)
    LB.box("Base terra", (0, 0, 0.0), (L + 2.6, W + 2.6, 0.12), terra, 0.1)
    g = LB.mat_gramado("Gramado varzea", (0.14, 0.34, 0.09), (0.17, 0.38, 0.11), faixa=100)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0.065))
    p = bpy.context.object
    p.name = "Gramado varzea"
    p.dimensions = (L, W, 0)
    bpy.ops.object.transform_apply(scale=True)
    p.data.materials.append(g)
    # manchas de terra nas areas
    for s in (-1, 1):
        LB.sphere("Mancha gol", (s * (HL - 0.7), 0, 0.066), (0.9, 1.1, 0.002), terra, 20, 6)
    linhas(largura=0.06, cor=(0.88, 0.86, 0.78))
    # traves de varzea de madeira estao em bola_trave; aqui, bandeirinhas de cantos
    # alambrado baixo de madeira nas laterais
    mad = LB.mat("Madeira", (0.45, 0.28, 0.13), 0.7)
    for i in range(-5, 6):
        for sy in (-1, 1):
            LB.rod("Estaca", (i * 1.15, sy * (HW + 0.85), 0), (i * 1.15, sy * (HW + 0.85), 0.35), 0.03, mad, 8)
    for sy in (-1, 1):
        LB.rod("Corrimao", (-5.8, sy * (HW + 0.85), 0.3), (5.8, sy * (HW + 0.85), 0.3), 0.022, mad, 8)


def montar_b():
    """B) Municipal: listras, calcada de concreto, alambrado."""
    LB.colecao("Gramado")
    _calcada(LB.PAL["concreto"], nome="Calcada concreto")
    _gramado("Gramado municipal", LB.PAL["grama"], LB.PAL["grama_cl"], faixa=1.2)
    linhas()
    ferro = LB.mat("Alambrado", (0.35, 0.37, 0.38), 0.4, metallic=0.8)
    for i in range(-5, 6):
        for sy in (-1, 1):
            LB.rod("Poste alambrado", (i * 1.2, sy * (HW + 1.0), 0), (i * 1.2, sy * (HW + 1.0), 0.55), 0.025, ferro, 8)
    for sy in (-1, 1):
        LB.rod("Barra alambrado", (-6, sy * (HW + 1.0), 0.53), (6, sy * (HW + 1.0), 0.53), 0.018, ferro, 8)
        LB.rod("Barra alambrado b", (-6, sy * (HW + 1.0), 0.12), (6, sy * (HW + 1.0), 0.12), 0.015, ferro, 8)


def montar_c():
    """C) Premium: xadrez hibrido + base teal + borda LED."""
    LB.colecao("Gramado")
    base = LB.mat("Base premium", LB.PAL["teal"], 0.55, verniz=0.4)
    LB.box("Base premium", (0, 0, -0.1), (L + 2.8, W + 2.8, 0.26), base, 0.13)
    pista = LB.mat_ruido("Calcada premium", (0.36, 0.40, 0.42), 0.6, escala=22, forca=0.6, bump=0.15)
    LB.box("Calcada premium", (0, 0, 0.0), (L + 2.3, W + 2.3, 0.05), pista, 0.03)
    _gramado("Gramado premium", (0.050, 0.30, 0.095), (0.085, 0.40, 0.14), faixa=0.75, xadrez=True)
    linhas(largura=0.055, cor=(0.97, 0.97, 0.94))
    led = LB.mat("LED borda", (0.1, 0.8, 0.9), 0.3, emissao=(0.12, 0.85, 1.0), forca=5.0)
    ouro = LB.mat("Ouro borda", LB.PAL["ouro"], 0.3, metallic=0.9)
    for sy in (-1, 1):
        LB.box("Borda LED", (0, sy * (HW + 0.12), 0.035), (L + 0.3, 0.04, 0.03), led, 0.01)
    for sx in (-1, 1):
        LB.box("Borda LED", (sx * (HL + 0.12), 0, 0.035), (0.04, W + 0.24, 0.03), led, 0.01)
    LB.box("Ouro borda", (0, 0, 0.002), (L + 2.34, W + 2.34, 0.01), ouro, 0.0)


def _com_limpeza(f):
    def g():
        LB.limpar_cena()
        f()
    g.__doc__ = f.__doc__
    return g


variacao_a_varzea = _com_limpeza(montar_a)
variacao_b_municipal = _com_limpeza(montar_b)
variacao_c_premium = _com_limpeza(montar_c)

CENAS = {"A": variacao_a_varzea, "B": variacao_b_municipal, "C": variacao_c_premium}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/gramado.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    LB.camera_iso(ortho_scale=17.5, alvo=(0, 0, 0.0))
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1200, 800)
