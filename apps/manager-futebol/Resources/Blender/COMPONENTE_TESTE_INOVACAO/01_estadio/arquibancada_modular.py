"""01_estadio / arquibancada_modular.py — 3 variacoes de arquibancada.
  A) curva_varzea  — 1 lado, 2 fileiras, em pe, sem cadeiras
  B) lateral_dupla — 2 lados, 4 fileiras, cadeiras alternadas
  C) bowl_premium  — 4 lados, 6 fileiras, VIP + cores (INOVACAO)

Funcao reutilizavel:
  criar_arquibancada(lados=['norte'], fileiras=4, com_cadeiras=True)
"""
import os
import sys
import random

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB


def criar_arquibancada(lados=("norte",), fileiras=4, com_cadeiras=True, seed=7):
    rng = random.Random(seed)
    pedra = LB.mat("Arquibancada | concreto", (0.61, 0.60, 0.53))
    azul = LB.mat("Arquibancada | assento", (0.08, 0.35, 0.49))
    ouro = LB.mat("Arquibancada | vip", (0.85, 0.59, 0.16))
    for lado in lados:
        longo = lado in ("norte", "sul")
        sinal = 1 if lado in ("norte", "leste") else -1
        total = 25 if longo else 15
        for f in range(fileiras):
            h = 0.27 + f * 0.29
            off = (3.30 if longo else 5.20) + f * 0.25
            loc = (0, sinal * off, h) if longo else (sinal * off, 0, h)
            dims = (10.3, 0.43, 0.25) if longo else (0.43, 6.5, 0.25)
            LB.box(f"Arquibancada {lado} f{f}", loc, dims, pedra, bevel=0.035)
            for col in range(total):
                if col % 8 == 0:
                    continue  # corredor
                ao = (col - (total - 1) / 2) * 0.38
                px, py = (ao, sinal * off) if longo else (sinal * off, ao)
                if com_cadeiras and rng.random() < 0.8:
                    LB.box(f"Cadeira {lado}{f}-{col}", (px, py, h + 0.19),
                           (0.20, 0.19, 0.17), ouro if f % 3 == 0 else azul, bevel=0.025)


def variacao_a():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte",), fileiras=2, com_cadeiras=False)


def variacao_b():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte", "sul"), fileiras=4, com_cadeiras=True)


def variacao_c():
    LB.limpar_cena()
    criar_arquibancada(lados=("norte", "sul", "leste", "oeste"), fileiras=6, com_cadeiras=True)
    vidro = LB.mat("VIP | vidro", (0.20, 0.45, 0.50))
    LB.box("VIP | fachada", (0, 5.6, 1.9), (7.6, 0.35, 0.72), vidro, bevel=0.06)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/arquibancada_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a, "B": variacao_b}.get(qual, variacao_c)()
    LB.camera_iso()
    LB.luz_estudio()
    LB.render_transparente(out)
