"""01_estadio / gramado.py — 3 variacoes reutilizaveis de campo.
VARIACOES:
  A) varzea_simples  — terra batida em volta, sem listras
  B) municipal_listrado — listras + base concreto
  C) premium_hibrido — verde rico + listras finas + borda LED (inovacao)
Uso Blender:
  blender --background --python gramado.py -- /tmp/gramado.png A
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB

COR = {
    "grama_a": (0.085, 0.34, 0.15),
    "grama_b": (0.12, 0.43, 0.20),
    "grama_premium": (0.075, 0.38, 0.18),
    "branco": (0.91, 0.93, 0.84),
    "terra": (0.43, 0.32, 0.19),
    "concreto": (0.61, 0.60, 0.53),
    "led": (0.72, 0.49, 0.16),
}


def _base(nome, larg=9.8, comp=5.9, mat_grama=None):
    g = mat_grama or LB.mat("Gramado | verde", COR["grama_a"])
    return LB.box(nome, (0, 0, 0.025), (larg, comp, 0.07), g, bevel=0.04)


def _listras(qtd=10, mat_listra=None):
    m = mat_listra or LB.mat("Gramado | listra", COR["grama_b"])
    for i in range(qtd):
        LB.box("Listra corte", (-4.4 + i * 0.97, 0, 0.067), (0.47, 5.8, 0.012), m, bevel=0.005)


def _linhas(branco=None):
    import math
    w = branco or LB.mat("Linhas | branco", COR["branco"])
    z = 0.085
    LB.stroke("Linhas | contorno", [(-4.7, -2.75, z), (4.7, -2.75, z),
                                   (4.7, 2.75, z), (-4.7, 2.75, z), (-4.7, -2.75, z)], w)
    LB.stroke("Linhas | meio", [(0, -2.75, z), (0, 2.75, z)], w)
    LB.stroke("Linhas | circulo", [(0.75 * math.cos(i * math.tau / 48),
                                    0.75 * math.sin(i * math.tau / 48), z) for i in range(49)], w)


def variacao_a_varzea():
    """A) Campo simples de varzea."""
    LB.limpar_cena()
    LB.box("Base | terra", (0, 0, -0.18), (14.5, 9.0, 0.35),
           LB.mat("Base | terra", COR["terra"]), bevel=0.22)
    _base("Gramado | varzea")
    _linhas()


def variacao_b_municipal():
    """B) Municipal com listras e base concreto."""
    LB.limpar_cena()
    LB.box("Base | concreto", (0, 0, -0.18), (14.0, 10.0, 0.4),
           LB.mat("Base | concreto", COR["concreto"]), bevel=0.25)
    _base("Gramado | municipal")
    _listras()
    _linhas()


def variacao_c_premium():
    """C) Premium hibrido + borda LED (INOVACAO)."""
    LB.limpar_cena()
    LB.box("Base | premium", (0, 0, -0.2), (15.0, 10.5, 0.45),
           LB.mat("Base | premium", (0.035, 0.12, 0.12)), bevel=0.3)
    g = LB.mat("Gramado | premium", COR["grama_premium"])
    _base("Gramado | premium", mat_grama=g)
    _listras(mat_listra=LB.mat("Listra | premium", (0.10, 0.44, 0.22)))
    _linhas()
    led = LB.mat("Borda | LED", COR["led"])
    for y in (-3.2, 3.2):
        LB.box("Borda LED", (0, y, 0.25), (10.4, 0.08, 0.18), led, bevel=0.02)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/gramado_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a_varzea, "B": variacao_b_municipal}.get(qual, variacao_c_premium)()
    LB.camera_iso()
    LB.luz_estudio()
    LB.render_transparente(out)
