"""03_props / bola_trave.py — bola + trave com rede.
  A) bola classica + trave simples
  B) bola colorida + trave com rede densa
  C) bola inovacao (neon noturna) + trave premium (INOVACAO)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB


def criar_bola(x=0, y=0, z=0.15, neon=False):
    base = LB.mat("Bola | neon" if neon else "Bola | couro", (0.9, 0.95, 0.2) if neon else (0.96, 0.95, 0.86))
    esc = LB.mat("Bola | painel", (0.05, 0.9, 0.5) if neon else (0.05, 0.06, 0.07))
    LB.sphere("Bola", (x, y, z), (0.145, 0.145, 0.145), base, 12, 8)
    for a in (0, 2.1, 4.2):
        LB.sphere("Bola | gomo", (x + 0.11 * math.cos(a), y + 0.11 * math.sin(a), z + 0.04),
                  (0.032, 0.018, 0.032), esc, 8, 5)


def criar_trave(larg=1.0, alt=0.7, rede_densa=False, premium=False):
    branco = LB.mat("Trave | branco", (0.92, 0.94, 0.84))
    rede_m = LB.mat("Rede | premium" if premium else "Rede | simples", (0.9, 0.9, 0.9))
    x0 = 4.6
    LB.stroke("Trave", [(x0, -larg / 2, 0.1), (x0, larg / 2, 0.1),
                        (x0, larg / 2, 0.1 + alt), (x0, -larg / 2, 0.1 + alt),
                        (x0, -larg / 2, 0.1)], branco, radius=0.035)
    passos = 6 if rede_densa else 3
    for i in range(passos):
        yy = -larg / 2 + i * larg / max(1, passos - 1)
        LB.stroke(f"Rede {i}", [(x0, yy, 0.1 + alt), (x0 + 0.35, yy, 0.1)], rede_m, radius=0.008)
    if premium:
        LB.box("Trave | base LED", (x0, 0, 0.05), (0.2, larg + 0.4, 0.08),
               LB.mat("LED | base", (0.1, 0.7, 0.9)), 0.02)


def variacao_a():
    LB.limpar_cena()
    criar_bola()
    criar_trave()


def variacao_b():
    LB.limpar_cena()
    criar_bola()
    criar_trave(rede_densa=True)


def variacao_c():
    LB.limpar_cena()
    criar_bola(neon=True)
    criar_trave(rede_densa=True, premium=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/prop_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a, "B": variacao_b}.get(qual, variacao_c)()
    LB.camera_iso(location=(6, -7, 6), ortho_scale=3.5, alvo=(2.5, 0, 0.4))
    LB.luz_estudio()
    LB.render_transparente(out, res_x=800, res_y=800)
