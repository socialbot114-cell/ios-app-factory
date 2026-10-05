"""03_props / extras.py — bandeira escanteio, banco reservas, cones, trofeu.
Cada funcao e reutilizavel: criar_bandeira(), criar_banco(), criar_cones(), criar_trofeu()
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB


def criar_bandeira(x=5.8, y=3.5):
    mastro = LB.mat("Bandeira | mastro", (0.9, 0.9, 0.85))
    pano = LB.mat("Bandeira | pano", (0.95, 0.2, 0.15))
    LB.rod("Mastro escanteio", (x, y, 0), (x, y, 1.5), 0.03, mastro)
    LB.box("Pano", (x + 0.25, y, 1.3), (0.5, 0.04, 0.3), pano, 0.01)


def criar_banco(x=0, y=-4.2):
    base = LB.mat("Banco | base", (0.2, 0.25, 0.35))
    LB.box("Banco reservas", (x, y, 0.5), (3.0, 0.6, 0.15), base, 0.05)
    LB.box("Banco encosto", (x, y - 0.3, 0.9), (3.0, 0.15, 0.7), base, 0.05)
    LB.box("Banco cobertura", (x, y - 0.1, 1.45), (3.2, 1.0, 0.1), base, 0.05)


def criar_cones():
    laranja = LB.mat("Cone | laranja", (0.95, 0.45, 0.05))
    for i, (x, y) in enumerate([(-2, 1), (-1, 1.5), (0, 1), (1, 1.5), (2, 1)]):
        LB.box(f"Cone {i}", (x, y, 0.12), (0.18, 0.18, 0.24), laranja, 0.03)


def criar_trofeu(x=0, y=0):
    ouro = LB.mat("Trofeu | ouro", (0.9, 0.65, 0.12))
    LB.box("Trofeu base", (x, y, 0.1), (0.5, 0.5, 0.2), ouro, 0.03)
    LB.rod("Trofeu haste", (x, y, 0.2), (x, y, 0.7), 0.08, ouro)
    LB.sphere("Trofeu taca", (x, y, 0.9), (0.25, 0.25, 0.2), ouro, 12, 8)


def variacao_treino():
    LB.limpar_cena()
    criar_cones()
    criar_bandeira()
    criar_banco()


def variacao_trofeu():
    LB.limpar_cena()
    criar_trofeu()
    criar_bandeira(1.5, 1.5)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/extras_teste.png"
    qual = (args[1] if len(args) > 1 else "TREINO").upper()
    variacao_trofeu() if qual.startswith("TROF") else variacao_treino()
    LB.camera_iso(ortho_scale=10.0, alvo=(0, 0, 0.5))
    LB.luz_estudio()
    LB.render_transparente(out)
