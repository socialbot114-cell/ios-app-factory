"""02_personagens / goleiro_arbitro.py — goleiro, arbitro e tecnico (v2, usa humano.py).
  A) goleiro classico amarelo em posicao de defesa
  B) goleiro neon rosa, luvas GG, mergulhando
  C) trio de arbitragem: arbitro (apito) + arbitro (cartao vermelho) + tecnico (terno)
Compat v1: criar_goleiro(nome, x, y, cor, luvas_grandes), criar_arbitro_tecnico()
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
sys.path.insert(0, os.path.dirname(__file__))
import lib_base as LB
import humano as H


def criar_goleiro(nome, x, y, cor=(0.95, 0.78, 0.1), luvas_grandes=False, pose="defesa", numero=1, **kw):
    kw.setdefault("luvas", (0.95, 0.35, 0.1) if luvas_grandes else (0.92, 0.92, 0.9))
    return H.goleiro(nome, x, y, cor=cor, pose=pose, numero=numero, **kw)


def criar_arbitro_tecnico(x0=0.0, y0=0.0):
    a = H.arbitro("Arbitro", x0 - 0.8, y0, pose="apito", yaw=3.14 + 0.3, pele="clara", cabelo="curto")
    t = H.tecnico("Tecnico", x0 + 0.8, y0, yaw=3.14 - 0.3, pele="parda")
    return a, t


def variacao_a():
    LB.limpar_cena()
    criar_goleiro("Goleiro A", 0, 0, cor=(0.97, 0.80, 0.08), yaw=3.14 + 0.35, pele="morena")


def variacao_b():
    LB.limpar_cena()
    criar_goleiro("Goleiro B", 0, 0, cor=(0.95, 0.15, 0.50), luvas_grandes=True, pose="mergulho",
                  yaw=3.14 + 0.2, pele="negra", cabelo="afro", numero=12)


def variacao_c():
    LB.limpar_cena()
    H.arbitro("Arbitro apito", -1.1, 0, pose="apito", yaw=3.14 + 0.35, pele="clara")
    H.arbitro("Arbitro cartao", 0, 0, pose="cartao", cartao="vermelho", yaw=3.14, pele="negra", cabelo="careca")
    H.tecnico("Tecnico", 1.1, 0, yaw=3.14 - 0.35, pele="parda")


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c}
CAMERAS = {"A": ((0, 0, 0.5), 3.6, 25, 14), "B": ((0, 0, 0.55), 4.2, 25, 14), "C": ((0, 0, 0.5), 6.0, 18, 12)}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/goleiro.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    LB.chao_sombra()
    al, d, az, el = CAMERAS[q]
    LB.camera_orbita(al, d, az, el, lente=65)
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 900, 900 if q != "C" else 700)
