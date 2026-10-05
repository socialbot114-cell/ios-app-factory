"""01_estadio / arquibancada_modular.py — arquibancadas com torcida (v2).
  A) curva_varzea  — 1 lado, 2 degraus de concreto, torcida em pe, sem cadeiras
  B) lateral_dupla — 2 lados longos, 4 fileiras, cadeiras em mosaico, torcida
  C) bowl_premium  — 4 lados, 6 fileiras, mosaico teal/ouro, torcida, camarote VIP de vidro

criar_arquibancada(lados, fileiras, com_cadeiras, torcida, lotacao, seed, altura_fileiras)
Cada lado vira um conjunto de objetos na colecao "Arquibancada". Torcida/cadeiras = 1 objeto cada.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import bpy
import lib_base as LB
from mathutils import Vector

HL, HW = LB.HL, LB.HW
FRENTE = 1.3          # distancia da linha de campo ate a 1a fileira
CORRER = 0.40         # profundidade de cada degrau
SUBIR = 0.26          # altura de cada degrau
ASSENTO = 0.30        # largura de cada cadeira

PELE = [(0.80, 0.55, 0.42), (0.60, 0.36, 0.23), (0.45, 0.25, 0.15), (0.22, 0.11, 0.07), (0.70, 0.45, 0.30)]


def _paleta_torcida(extra=None):
    cores = [LB.PAL["teal_cl"], LB.PAL["ouro"], LB.PAL["branco"], LB.PAL["vermelho"],
             LB.PAL["azul"], (0.15, 0.15, 0.17), (0.3, 0.6, 0.25), (0.85, 0.4, 0.1)]
    return cores


def _geom_lado(lado, fileiras, correr=CORRER, subir=SUBIR):
    """Retorna (eixo_longo, sinal, d0, comprimento, funcao pos(i_fileira, ao, h))."""
    longo = lado in ("norte", "sul")
    sinal = 1 if lado in ("norte", "leste") else -1
    if longo:
        d0 = HW + FRENTE
        # estende alem das pontas p/ fechar as quinas
        comp = 2 * (HL + FRENTE + fileiras * correr * 0.95)
    else:
        d0 = HL + FRENTE
        comp = 2 * (HW + FRENTE)
    return longo, sinal, d0, comp


def criar_arquibancada(lados=("norte",), fileiras=4, com_cadeiras=True, torcida=True,
                       lotacao=0.82, seed=7, mosaico=True, muro_fundo=True, nome="Arq"):
    rng = random.Random(seed)
    LB.colecao("Arquibancada")
    pedra = LB.mat_ruido("Arq|concreto", LB.PAL["concreto"], 0.85, escala=16, forca=0.7, bump=0.25)
    degr = LB.mat_ruido("Arq|degrau claro", (0.72, 0.71, 0.66), 0.8, escala=18, forca=0.5, bump=0.2)
    escada = LB.mat("Arq|escada", (0.86, 0.85, 0.80), 0.7)
    cad = [LB.mat("Cad|teal", LB.PAL["teal_cl"], 0.45, verniz=0.4),
           LB.mat("Cad|ouro", LB.PAL["ouro"], 0.45, verniz=0.4),
           LB.mat("Cad|branca", LB.PAL["branco"], 0.5, verniz=0.4)]
    pessoas = [LB.mat(f"Torc|{i}", c, 0.75, sheen=0.3) for i, c in enumerate(_paleta_torcida())]
    peles = [LB.mat(f"Pele|{i}", c, 0.55) for i, c in enumerate(PELE)]
    cabelos = [LB.mat("Cabelo|esc", (0.05, 0.035, 0.03), 0.6), LB.mat("Cabelo|cast", (0.3, 0.18, 0.08), 0.6),
               LB.mat("Cabelo|loiro", (0.8, 0.65, 0.25), 0.6)]
    L_ass = LB.Lote(f"{nome} cadeiras", cad)
    L_tor = LB.Lote(f"{nome} torcida", pessoas + peles + cabelos)
    n_pes = len(pessoas)
    for lado in lados:
        longo, sinal, d0, comp, = _geom_lado(lado, fileiras)[:4]
        total_ass = int(comp / ASSENTO)
        for f in range(fileiras):
            d = d0 + f * CORRER
            h = (f + 1) * SUBIR
            # bloco solido do degrau (da base ate h)
            if longo:
                dims = (comp, CORRER, h)
                loc = (0, sinal * (d + CORRER / 2), h / 2)
            else:
                dims = (CORRER, comp, h)
                loc = (sinal * (d + CORRER / 2), 0, h / 2)
            LB.box(f"{nome} {lado} degrau {f}", loc, dims, degr if f % 2 else pedra, 0.012)
            for c in range(total_ass):
                ao = (c - (total_ass - 1) / 2) * ASSENTO
                corredor = (c % 14 == 7)
                px, py = (ao, sinal * (d + CORRER * 0.55)) if longo else (sinal * (d + CORRER * 0.55), ao)
                if corredor:
                    LB.box(f"{nome} escada", (px, py, h + 0.008), (0.26, CORRER * 0.98, 0.016) if longo
                           else (CORRER * 0.98, 0.26, 0.016), escada, 0.003)
                    continue
                # cadeira
                if com_cadeiras:
                    mi = ((c // 3) + f) % 3 if mosaico else 0
                    sx, sy = (0.21, 0.16) if longo else (0.16, 0.21)
                    L_ass.cubo((px, py, h + 0.045), (sx, sy, 0.07) if longo else (sy, sx, 0.07), mi)
                    # encosto (aponta para tras)
                    bx, by = (px, py + sinal * 0.085) if longo else (px + sinal * 0.085, py)
                    L_ass.cubo((bx, by, h + 0.13), (0.21, 0.03, 0.15) if longo else (0.03, 0.21, 0.15), mi)
                # torcida
                if torcida and rng.random() < lotacao:
                    cor_i = rng.randrange(n_pes) if rng.random() < 0.55 else (0 if rng.random() < 0.6 else 1)
                    pele_i = n_pes + rng.randrange(len(PELE))
                    cab_i = n_pes + len(PELE) + rng.randrange(3)
                    alt = 0.24 + rng.random() * 0.03
                    zc = h + (0.12 if com_cadeiras else 0.0) + 0.0
                    ox = rng.uniform(-0.02, 0.02)
                    oy = rng.uniform(-0.03, 0.03)
                    # corpo
                    sz = (0.15, 0.10, 0.16) if longo else (0.10, 0.15, 0.16)
                    L_tor.cubo((px + ox, py + oy - sinal * 0.0 if longo else py + oy, zc + 0.14), sz, cor_i) if longo else \
                        L_tor.cubo((px + ox, py + oy, zc + 0.14), sz, cor_i)
                    # bracos levantados as vezes
                    if rng.random() < 0.18:
                        dz = 0.15
                        for sd in (-1, 1):
                            if longo:
                                L_tor.cubo((px + sd * 0.095, py - sinal * 0.01, zc + 0.30), (0.035, 0.035, 0.14), pele_i)
                            else:
                                L_tor.cubo((px - sinal * 0.01, py + sd * 0.095, zc + 0.30), (0.035, 0.035, 0.14), pele_i)
                    # cabeca
                    L_tor.esfera((px + ox, py + oy, zc + 0.295), 0.058, pele_i, (1, 1, 1.05))
                    L_tor.esfera((px + ox, py + oy - (sinal * 0.006 if longo else 0), zc + 0.320), 0.060, cab_i, (1.0, 1.0, 0.7))
        # muro de fundo + guarda-corpo
        topo = fileiras * SUBIR
        dfundo = d0 + fileiras * CORRER
        if muro_fundo:
            if longo:
                LB.box(f"{nome} {lado} muro", (0, sinal * (dfundo + 0.12), topo * 0.5 + 0.35), (comp, 0.22, topo + 0.7), pedra, 0.02)
            else:
                LB.box(f"{nome} {lado} muro", (sinal * (dfundo + 0.12), 0, topo * 0.5 + 0.35), (0.22, comp, topo + 0.7), pedra, 0.02)
        # parapeito + vidro na frente
        vidro = LB.mat("Arq|vidro", (0.55, 0.75, 0.80), 0.05, vidro=1.0, alpha=0.35)
        if longo:
            LB.box(f"{nome} {lado} parapeito", (0, sinal * (d0 - 0.08), 0.16), (comp, 0.14, 0.32), pedra, 0.02)
            LB.box(f"{nome} {lado} vidro", (0, sinal * (d0 - 0.08), 0.46), (comp, 0.02, 0.28), vidro, 0.0)
        else:
            LB.box(f"{nome} {lado} parapeito", (sinal * (d0 - 0.08), 0, 0.16), (0.14, comp, 0.32), pedra, 0.02)
            LB.box(f"{nome} {lado} vidro", (sinal * (d0 - 0.08), 0, 0.46), (0.02, comp, 0.28), vidro, 0.0)
    if com_cadeiras:
        L_ass.criar()
    if torcida:
        L_tor.criar()


def criar_camarote_vip(lado="norte", fileiras=6, nome="VIP"):
    """Camarote de vidro sobre a arquibancada (usa mesmas medidas)."""
    sinal = 1 if lado in ("norte", "leste") else -1
    vidro = LB.mat("VIP|vidro", (0.40, 0.65, 0.75), 0.04, vidro=1.0, alpha=0.4, metallic=0.2)
    ouro = LB.mat("VIP|moldura", LB.PAL["ouro"], 0.25, metallic=0.9)
    esc = LB.mat("VIP|corpo", LB.PAL["teal"], 0.5, verniz=0.4)
    d = HW + FRENTE + fileiras * CORRER
    h0 = fileiras * SUBIR + 0.7
    LB.box(f"{nome} laje", (0, sinal * (d + 0.55), h0), (7.2, 1.3, 0.1), esc, 0.03)
    LB.box(f"{nome} teto", (0, sinal * (d + 0.55), h0 + 0.72), (7.2, 1.3, 0.1), esc, 0.03)
    LB.box(f"{nome} vidro", (0, sinal * (d - 0.07), h0 + 0.36), (7.0, 0.03, 0.66), vidro, 0.0)
    for x in range(-3, 4):
        LB.box(f"{nome} montante", (x * 1.15, sinal * (d - 0.07), h0 + 0.36), (0.045, 0.05, 0.7), ouro, 0.008)
    LB.box(f"{nome} fundo", (0, sinal * (d + 1.15), h0 + 0.36), (7.2, 0.08, 0.7),
           LB.mat("VIP|fundo", (0.1, 0.1, 0.12), 0.5), 0.01)
    # luzes internas quentes
    luz = LB.mat("VIP|luz", (1, 0.85, 0.55), 0.3, emissao=(1, 0.8, 0.45), forca=4.0)
    for x in range(-3, 4):
        LB.box(f"{nome} luz", (x * 1.0, sinal * (d + 0.55), h0 + 0.66), (0.4, 0.2, 0.02), luz, 0.005)


def variacao_a():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte",), fileiras=2, com_cadeiras=False, lotacao=0.6)


def variacao_b():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte", "sul"), fileiras=4, com_cadeiras=True)


def variacao_c():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte", "sul", "leste", "oeste"), fileiras=6, com_cadeiras=True)
    criar_camarote_vip("norte")


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/arq.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    # chao
    LB.box("Chao", (0, 0, -0.03), (24, 18, 0.06), LB.mat_ruido("Chao", (0.38, 0.40, 0.40), 0.9, 10, 0.5, 0.2), 0.0)
    LB.camera_iso(ortho_scale={"A": 12.0, "B": 22.0, "C": 24.0}[q], alvo=(0, 0, 0.7))
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1200, 800)
