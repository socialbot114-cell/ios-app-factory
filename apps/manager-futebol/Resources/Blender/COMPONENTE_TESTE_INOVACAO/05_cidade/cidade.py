"""05_cidade / cidade.py — cidade ao redor do estadio (v2), 3 portes.

  pequeno : bairro — casas de 1-2 andares com telhado, quintais, ruas de terra/asfalto, poucas arvores
  medio   : cidade — sobrados, comercio e predios de 4-6 andares, avenida, praca, estacionamento
  grande  : metropole — torres de 8-18 andares, avenidas largas, parques, onibus, arranha-ceus ao fundo

criar_cidade(porte, meia_x, meia_y, noturno=False, seed=1)
  meia_x/meia_y = meia-extensao do estadio (a cidade comeca depois dele).
Tudo em poucos objetos (Lote): predios, janelas, arvores, carros, postes, faixas.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import bpy
import lib_base as LB

PORTES = {
    #          raio(celulas) quarteirao  rua   alt min/max  densidade verde  carros
    "pequeno": dict(nx=4, ny=3, bloco=4.2, rua=1.5, alt=(0.5, 1.3), dens=0.80, verde=0.22, carros=0.20, torres=0.0),
    "medio":   dict(nx=5, ny=4, bloco=4.6, rua=1.7, alt=(0.9, 3.2), dens=0.92, verde=0.12, carros=0.35, torres=0.10),
    "grande":  dict(nx=6, ny=5, bloco=4.8, rua=2.1, alt=(1.6, 7.5), dens=1.00, verde=0.09, carros=0.5, torres=0.30),
}

PAREDES = [(0.93, 0.88, 0.76), (0.85, 0.55, 0.40), (0.95, 0.95, 0.92), (0.55, 0.70, 0.78), (0.90, 0.80, 0.45),
           (0.70, 0.50, 0.55), (0.62, 0.74, 0.58), (0.80, 0.82, 0.86)]
PREDIOS = [(0.78, 0.80, 0.84), (0.60, 0.66, 0.74), (0.88, 0.84, 0.78), (0.45, 0.55, 0.66), (0.72, 0.62, 0.55), (0.86, 0.88, 0.9)]
TELHAS = [(0.72, 0.28, 0.18), (0.55, 0.22, 0.15), (0.35, 0.35, 0.40), (0.78, 0.45, 0.2)]
CARROS = [(0.85, 0.1, 0.1), (0.95, 0.95, 0.95), (0.1, 0.25, 0.7), (0.95, 0.8, 0.1), (0.1, 0.1, 0.12), (0.5, 0.55, 0.6), (0.1, 0.55, 0.3)]


def _mats(noturno):
    n = {}
    n["paredes"] = [LB.mat(f"Cid|parede{i}", c, 0.85) for i, c in enumerate(PAREDES)]
    n["predios"] = [LB.mat(f"Cid|predio{i}", c, 0.6) for i, c in enumerate(PREDIOS)]
    n["telhas"] = [LB.mat(f"Cid|telha{i}", c, 0.8) for i, c in enumerate(TELHAS)]
    n["vidro"] = LB.mat("Cid|vidro", (0.18, 0.28, 0.38), 0.12, metallic=0.3)
    n["vidro_aceso"] = LB.mat("Cid|janela acesa", (1.0, 0.78, 0.4), 0.3, emissao=(1.0, 0.72, 0.3), forca=5.0 if noturno else 0.0)
    if not noturno:
        n["vidro_aceso"] = LB.mat("Cid|janela clara", (0.35, 0.5, 0.62), 0.12, metallic=0.2)
    n["porta"] = LB.mat("Cid|porta", (0.35, 0.2, 0.1), 0.7)
    return n


def _predio(lote_p, lote_j, cx, cy, w, d, h, rng, estilo, M):
    """Predio com janelas. lote_p: paredes+telhas (multi-material), lote_j: janelas (vidro / aceso)."""
    mi = rng.randrange(len(M["_n_p"])) if estilo != "torre" else rng.randrange(len(M["_n_pr"])) + M["_off_pr"]
    lote_p.cubo((cx, cy, h / 2), (w, d, h), mi)
    if estilo == "casa":
        lote_p.telhado((cx, cy, h), (w + 0.12, d + 0.12, 0.28 + rng.random() * 0.12), M["_off_t"] + rng.randrange(4), eixo="x" if w >= d else "y")
        lote_p.cubo((cx + w * 0.15, cy - d / 2 - 0.0, 0.14), (0.14, 0.02, 0.28), M["_off_porta"])
    elif estilo == "comercio":
        lote_p.cubo((cx, cy, h + 0.04), (w + 0.08, d + 0.08, 0.08), M["_off_pr"] + 3)
    else:
        lote_p.cubo((cx, cy, h + 0.05), (w * 0.96, d * 0.96, 0.1), M["_off_pr"] + 3)
        if rng.random() < 0.6:
            lote_p.cubo((cx + rng.uniform(-0.3, 0.3) * w, cy, h + 0.25), (w * 0.3, d * 0.3, 0.35), M["_off_pr"] + 3)
    # janelas nas 4 faces
    nand = max(1, int(h / 0.38))
    for lado in range(4):
        face_w = w if lado < 2 else d
        n = max(1, int(face_w / 0.36))
        for a in range(nand):
            if estilo == "casa" and a == 0 and lado == 0:
                continue
            for k in range(n):
                off = (k - (n - 1) / 2) * (face_w / n)
                z = 0.17 + a * (h - 0.12) / nand + 0.08
                if z > h - 0.08:
                    continue
                mj = 1 if rng.random() < 0.38 else 0
                sx = (face_w / n) * 0.52
                if lado == 0:
                    lote_j.cubo((cx + off, cy - d / 2 - 0.004, z), (sx, 0.012, 0.17), mj)
                elif lado == 1:
                    lote_j.cubo((cx + off, cy + d / 2 + 0.004, z), (sx, 0.012, 0.17), mj)
                elif lado == 2:
                    lote_j.cubo((cx - w / 2 - 0.004, cy + off, z), (0.012, sx, 0.17), mj)
                else:
                    lote_j.cubo((cx + w / 2 + 0.004, cy + off, z), (0.012, sx, 0.17), mj)


def _arvore(lt, x, y, rng, esc=1.0):
    h = 0.22 * esc
    lt.cilindro((x, y, 0), 0.025 * esc, h, 0, 6)
    c = 1 + rng.randrange(3)
    r = (0.16 + rng.random() * 0.07) * esc
    lt.esfera((x, y, h + r * 0.7), r, c, (1, 1, 1.05))
    if rng.random() < 0.5:
        lt.esfera((x + 0.07 * esc, y + 0.04 * esc, h + r * 1.2), r * 0.7, c)


def _carro(lc, x, y, ang, rng, escala=1.7):
    c = rng.randrange(len(CARROS))
    ca, sa = math.cos(ang), math.sin(ang)
    def P(dx, dy, dz):
        return (x + (dx * ca - dy * sa) * escala, y + (dx * sa + dy * ca) * escala, dz * escala)
    lc.cubo(P(0, 0, 0.09), (0.46 * escala, 0.2 * escala, 0.1 * escala), c, rotz=ang)
    lc.cubo(P(-0.02, 0, 0.17), (0.24 * escala, 0.17 * escala, 0.08 * escala), len(CARROS), rotz=ang)  # vidro
    for dx in (-0.15, 0.15):
        for dy in (-0.1, 0.1):
            lc.cubo(P(dx, dy, 0.035), (0.07 * escala, 0.03 * escala, 0.07 * escala), len(CARROS) + 1, rotz=ang)


def criar_cidade(porte="medio", meia_x=9.0, meia_y=7.0, noturno=False, seed=1, chao=True):
    P = PORTES[porte]
    rng = random.Random(seed)
    LB.colecao("Cidade")
    M = _mats(noturno)
    bloco, rua = P["bloco"], P["rua"]
    passo = bloco + rua
    # grade de quarteiroes (centros). A area do estadio (+praca) fica livre.
    ex, ey = meia_x + 2.4, meia_y + 2.4
    nx, ny = P["nx"], P["ny"]
    ox = -(nx + 0.5) * passo + passo / 2
    oy = -(ny + 0.5) * passo + passo / 2
    # --- materiais agrupados (um Lote por categoria)
    mats_p = M["paredes"] + M["predios"] + M["telhas"] + [M["porta"]]
    M["_n_p"], M["_n_pr"] = M["paredes"], M["predios"]
    M["_off_pr"], M["_off_t"], M["_off_porta"] = len(M["paredes"]), len(M["paredes"]) + len(M["predios"]), len(mats_p) - 1
    lp = LB.Lote("Cidade predios", mats_p)
    lj = LB.Lote("Cidade janelas", [M["vidro"], M["vidro_aceso"]])
    verde = [LB.mat("Cid|tronco", (0.30, 0.18, 0.08), 0.8), LB.mat("Cid|copa1", (0.10, 0.40, 0.14), 0.8),
             LB.mat("Cid|copa2", (0.18, 0.5, 0.18), 0.8), LB.mat("Cid|copa3", (0.28, 0.55, 0.2), 0.8)]
    lt = LB.Lote("Cidade arvores", verde)
    lc = LB.Lote("Cidade carros", [LB.mat(f"Cid|carro{i}", c, 0.3) for i, c in enumerate(CARROS)] +
                 [LB.mat("Cid|carro vidro", (0.12, 0.17, 0.22), 0.1), LB.mat("Cid|pneu", (0.03, 0.03, 0.035), 0.8)])
    luz_m = LB.mat("Cid|lampada", (1.0, 0.85, 0.55), 0.3, emissao=(1.0, 0.8, 0.45), forca=9.0 if noturno else 0.3)
    poste_m = LB.mat("Cid|poste", (0.25, 0.27, 0.3), 0.5, metallic=0.6)
    lposte = LB.Lote("Cidade postes", [poste_m, luz_m])
    faixa_m = LB.mat("Cid|faixa rua", (0.95, 0.95, 0.9), 0.6)
    lf = LB.Lote("Cidade faixas", [faixa_m])
    grama_m = LB.mat_ruido("Cid|jardim", (0.20, 0.42, 0.18), 0.9, 20, 0.5, 0.2)
    calcada_m = LB.mat_ruido("Cid|calcada", (0.66, 0.65, 0.62), 0.85, 25, 0.5, 0.15)
    # --- chao: asfalto
    extx = (nx + 1) * passo
    exty = (ny + 1) * passo
    if chao:
        asf = LB.mat_ruido("Cid|asfalto", (0.17, 0.18, 0.2), 0.9, 40, 0.5, 0.12)
        LB.box("Cidade asfalto", (0, 0, -0.06), (extx * 2 + 4, exty * 2 + 4, 0.1), asf, 0.0)
    # --- quarteiroes
    blocos = []
    for i in range(-nx, nx + 1):
        for j in range(-ny, ny + 1):
            cx, cy = i * passo, j * passo
            if abs(cx) - bloco / 2 < ex and abs(cy) - bloco / 2 < ey:
                continue   # zona do estadio + praca
            blocos.append((cx, cy, i, j))
    for cx, cy, i, j in blocos:
        dist = math.hypot(cx / max(1, nx * passo), cy / max(1, ny * passo))
        LB.box("Quarteirao", (cx, cy, 0.0), (bloco, bloco, 0.06), calcada_m, 0.02)
        if rng.random() < P["verde"]:     # praca/parque
            LB.box("Parque", (cx, cy, 0.034), (bloco * 0.9, bloco * 0.9, 0.02), grama_m, 0.01)
            for _ in range(int(7 + rng.random() * 6)):
                _arvore(lt, cx + rng.uniform(-1, 1) * bloco * 0.42, cy + rng.uniform(-1, 1) * bloco * 0.42, rng, 1.4 + rng.random() * 0.5)
            if rng.random() < 0.5:
                LB.rod("Fonte", (cx, cy, 0.04), (cx, cy, 0.18), 0.28, LB.mat("Cid|fonte", (0.7, 0.72, 0.75), 0.5), 20, radius2=0.22)
                LB.rod("Agua", (cx, cy, 0.17), (cx, cy, 0.19), 0.24, LB.mat("Cid|agua", (0.3, 0.7, 0.9), 0.05, alpha=0.7), 20)
            continue
        # construcoes: subdivide o quarteirao em lotes
        nl = 2 if porte != "grande" or rng.random() < 0.5 else 1
        sub = bloco / nl
        for a in range(nl):
            for b in range(nl):
                if rng.random() > P["dens"]:
                    continue
                lx = cx + (a - (nl - 1) / 2) * sub
                ly = cy + (b - (nl - 1) / 2) * sub
                w = sub * (0.62 + rng.random() * 0.22)
                d = sub * (0.62 + rng.random() * 0.22)
                alt_min, alt_max = P["alt"]
                centro = 1.0 - min(1.0, dist)       # mais alto perto do centro (longe do estadio nao)
                if porte == "pequeno":
                    h = rng.uniform(*P["alt"]); est = "casa"
                elif porte == "medio":
                    if rng.random() < 0.45:
                        h = rng.uniform(0.5, 1.0); est = "casa"
                    else:
                        h = rng.uniform(1.2, P["alt"][1]); est = "comercio"
                else:
                    if rng.random() < P["torres"] + 0.25 * dist:
                        h = rng.uniform(4.0, P["alt"][1]); est = "torre"
                    else:
                        h = rng.uniform(1.4, 3.6); est = "comercio"
                _predio(lp, lj, lx, ly, w, d, h, rng, est, M)
                if est == "casa":
                    for _ in range(rng.randrange(0, 3)):
                        _arvore(lt, lx + rng.uniform(-1, 1) * sub * 0.44, ly + rng.uniform(-1, 1) * sub * 0.44, rng, 1.1)
    # --- ruas: faixas tracejadas + carros + postes
    ruas_x = [(i + 0.5) * passo for i in range(-nx - 1, nx + 1)]
    ruas_y = [(j + 0.5) * passo for j in range(-ny - 1, ny + 1)]
    pos_livre = lambda x, y: not (abs(x) < ex + rua / 2 and abs(y) < ey + rua / 2) or False
    for yy in ruas_y:           # ruas horizontais (ao longo de X)
        x = -extx
        while x < extx:
            if not (abs(yy) < ey - 0.5 and abs(x) < ex):
                lf.cubo((x, yy, 0.0), (0.5, 0.05, 0.012), 0)
            x += 1.1
        for k in range(int(P["carros"] * 14)):
            x = rng.uniform(-extx, extx)
            if abs(yy) < ey - 0.5 and abs(x) < ex:
                continue
            lado = rng.choice((-1, 1))
            _carro(lc, x, yy + lado * rua * 0.25, 0.0 if lado > 0 else math.pi, rng)
        for x in [v * 3.2 for v in range(int(-extx / 3.2), int(extx / 3.2))]:
            if abs(yy) < ey - 0.5 and abs(x) < ex:
                continue
            lposte.cilindro((x, yy + rua / 2 - 0.1, 0), 0.02, 0.38, 0, 6)
            lposte.esfera((x, yy + rua / 2 - 0.1, 0.4), 0.045, 1)
    for xx in ruas_x:           # ruas verticais (ao longo de Y)
        y = -exty
        while y < exty:
            if not (abs(xx) < ex - 0.5 and abs(y) < ey):
                lf.cubo((xx, y, 0.0), (0.05, 0.5, 0.012), 0)
            y += 1.1
        for k in range(int(P["carros"] * 12)):
            y = rng.uniform(-exty, exty)
            if abs(xx) < ex - 0.5 and abs(y) < ey:
                continue
            lado = rng.choice((-1, 1))
            _carro(lc, xx + lado * rua * 0.25, y, math.pi / 2 if lado > 0 else -math.pi / 2, rng)
    # --- praca do estadio (calcadao) + arvores nos cantos
    LB.box("Praca estadio", (0, 0, -0.01), (ex * 2, ey * 2, 0.07),
           LB.mat_ruido("Cid|praca", (0.62, 0.60, 0.56), 0.8, 14, 0.5, 0.2), 0.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(3):
                _arvore(lt, sx * (ex - 0.4 - k * 0.6), sy * (ey - 0.4 - rng.random()), rng, 1.1)
    for o in (lp, lj, lt, lc, lposte, lf):
        o.criar()
    return dict(ex=ex, ey=ey, passo=passo, extx=extx, exty=exty)


def variacao(porte, noturno=False):
    LB.limpar_cena()
    return criar_cidade(porte, meia_x=0.0, meia_y=0.0, noturno=noturno)


CAMS = {"pequeno": dict(location=(22, -26, 24), ortho_scale=44, alvo=(0, 0, 0)),
        "medio": dict(location=(28, -32, 30), ortho_scale=58, alvo=(0, 0, 0)),
        "grande": dict(location=(34, -38, 36), ortho_scale=76, alvo=(0, 0, 2))}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/cidade.png"
    porte = {"A": "pequeno", "B": "medio", "C": "grande"}.get((a[1] if len(a) > 1 else "B").upper(), (a[1] if len(a) > 1 else "medio"))
    variacao(porte, noturno="--noturno" in a)
    c = CAMS[porte]
    LB.camera_iso(c["location"], c["ortho_scale"], c["alvo"])
    LB.luz_estudio(noturno="--noturno" in a, fundo=((0.55, 0.78, 0.95), (0.88, 0.93, 0.98)) if "--noturno" not in a else ((0.02, 0.04, 0.1), (0.01, 0.02, 0.05)))
    LB.render(out, 1400, 950)
