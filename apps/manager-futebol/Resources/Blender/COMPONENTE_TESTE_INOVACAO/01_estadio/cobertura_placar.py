"""01_estadio / cobertura_placar.py — cobertura, placar, refletor, publicidade.
3 variacoes:
  A) simples — 1 cobertura norte + placar pequeno
  B) dupla — 2 coberturas + 4 refletores + placas
  C) arena — 4 coberturas + telão + LED + refletores altos (INOVACAO)
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB


def criar_cobertura(lados=("norte",), altura=3.4):
    escuro = LB.mat("Cobertura | escura", (0.035, 0.12, 0.12))
    pedra = LB.mat("Cobertura | coluna", (0.61, 0.60, 0.53))
    for lado in lados:
        longo = lado in ("norte", "sul")
        sinal = 1 if lado in ("norte", "leste") else -1
        centro = 4.2
        if longo:
            LB.box(f"Cobertura {lado}", (0, sinal * centro, altura), (10.9, 1.6, 0.18), escuro, 0.08)
            for x in (-4.6, 0, 4.6):
                LB.box("Coluna", (x, sinal * (centro + 0.3), altura / 2), (0.09, 0.09, altura), pedra, 0.015)
        else:
            LB.box(f"Cobertura {lado}", (sinal * centro, 0, altura), (1.6, 7.0, 0.18), escuro, 0.08)


def criar_placar(texto="CASA 0 : 0 FORA", pos=(0, 5.4, 2.2)):
    escuro = LB.mat("Placar | fundo", (0.035, 0.12, 0.12))
    branco = LB.mat("Placar | texto", (0.91, 0.93, 0.84))
    LB.box("Placar", pos, (2.1, 0.25, 0.85), escuro)
    LB.texto_3d("Placar | texto", texto, (pos[0], pos[1] - 0.15, pos[2]), 0.14, branco)


def criar_refletores(altura=3.5):
    pedra = LB.mat("Refletor | mastro", (0.61, 0.60, 0.53))
    luz = LB.mat("Refletor | lampada", (1.0, 0.89, 0.62))
    for x, y in [(-5.7, -3.7), (5.7, -3.7), (-5.7, 3.7), (5.7, 3.7)]:
        LB.box("Mastro", (x, y, altura / 2), (0.095, 0.095, altura), pedra, 0.018)
        LB.box("Holofote", (x, y, altura), (0.65, 0.20, 0.22), luz, 0.025)


def criar_publicidade(qtd=7):
    ouro = LB.mat("Pub | ouro", (0.85, 0.59, 0.16))
    escuro = LB.mat("Pub | fundo", (0.035, 0.12, 0.12))
    branco = LB.mat("Pub | texto", (0.91, 0.93, 0.84))
    nomes = ["BOLA+", "ARENA", "CHUTE", "GOL", "FUTOS", "LOCAL", "TOP"]
    for i in range(qtd):
        x = -4.5 + i * 9 / max(1, qtd - 1)
        LB.box(f"Placa {i}", (x, 3.04, 0.32), (0.76, 0.09, 0.40), ouro if i % 2 == 0 else escuro, 0.02)
        LB.texto_3d(f"Pub texto {i}", nomes[i % len(nomes)], (x, 2.985, 0.32), 0.115, branco)


def variacao_a():
    LB.limpar_cena()
    criar_cobertura(("norte",))
    criar_placar()


def variacao_b():
    LB.limpar_cena()
    criar_cobertura(("norte", "sul"))
    criar_placar()
    criar_refletores()
    criar_publicidade(5)


def variacao_c():
    LB.limpar_cena()
    criar_cobertura(("norte", "sul", "leste", "oeste"), altura=3.8)
    criar_placar("FINAL 2 : 1")
    criar_refletores(altura=4.5)
    criar_publicidade(11)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/cobertura_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a, "B": variacao_b}.get(qual, variacao_c)()
    LB.camera_iso()
    LB.luz_estudio()
    LB.render_transparente(out)
