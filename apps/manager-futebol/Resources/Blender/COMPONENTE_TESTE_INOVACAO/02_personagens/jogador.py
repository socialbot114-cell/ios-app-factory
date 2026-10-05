"""02_personagens / jogador.py — variacoes de jogador (v2, usa humano.py).
  A) parado  — kit simples, careca/curto, em pe
  B) correndo — camisa 7, afro, corrida dinamica
  C) estrela  — camisa 10 capitao, chutando, chuteira vermelha, moicano
  E) elenco   — 6 poses lado a lado (parado, correndo, chutando, comemorando, lamentando, sentado)

Reuso: criar_jogador(nome, x, y, kit_cor, ...) (compativel com a v1)
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
sys.path.insert(0, os.path.dirname(__file__))
import lib_base as LB
import humano as H


def criar_jogador(nome, x, y, kit_cor=None, trim_cor=None, numero=9, estrela=False, pose="parado", **kw):
    if kit_cor is not None:
        kw["camisa"] = kit_cor
    if trim_cor is not None:
        kw["detalhe"] = trim_cor
    if estrela:
        kw.setdefault("bota", (0.85, 0.08, 0.10))
    return H.jogador(nome, x, y, numero=numero, pose=pose, **kw)


def variacao_a():
    LB.limpar_cena()
    criar_jogador("Jogador A", 0, 0, kit_cor=LB.PAL["azul"], trim_cor=LB.PAL["branco"],
                  numero=5, cabelo="careca", pele="clara", yaw=3.14 + 0.4)


def variacao_b():
    LB.limpar_cena()
    criar_jogador("Jogador B", 0, 0, kit_cor=LB.PAL["vermelho"], trim_cor=LB.PAL["branco"],
                  calcao=LB.PAL["branco"], numero=7, pose="correndo", cabelo="afro", pele="negra",
                  yaw=3.14 - 0.5)


def variacao_c():
    LB.limpar_cena()
    criar_jogador("Estrela 10", 0, 0, kit_cor=(0.03, 0.42, 0.28), trim_cor=LB.PAL["ouro"],
                  calcao=LB.PAL["ouro"], numero=10, pose="chutando", cabelo="moicano",
                  pele="bronze", capitao=True, estrela=True, yaw=3.14 + 0.45, cor_cabelo=(0.9, 0.7, 0.1))


def variacao_elenco():
    LB.limpar_cena()
    poses = [("parado", "curto", "morena"), ("correndo", "afro", "negra"), ("chutando", "moicano", "bronze"),
             ("comemorando", "longo", "clara"), ("lamentando", "careca", "parda"), ("sentado", "coque", "morena")]
    for i, (po, cab, pel) in enumerate(poses):
        criar_jogador(f"Elenco {i}", (i - 2.5) * 0.75, 0, kit_cor=LB.PAL["teal_cl"], trim_cor=LB.PAL["ouro"],
                      calcao=LB.PAL["branco"], numero=i + 1, pose=po, cabelo=cab, pele=pel, yaw=3.14 + 0.3)


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c, "E": variacao_elenco}
CAMERAS = {"A": ((0, 0, 0.55), 3.4, 28, 16), "B": ((0, 0, 0.55), 3.4, 28, 16),
           "C": ((0, 0, 0.55), 3.4, 28, 16), "E": ((0, 0, 0.5), 8.2, 18, 14)}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/jogador.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    LB.chao_sombra()
    al, d, az, el = CAMERAS[q]
    LB.camera_orbita(al, d, az, el, lente=70 if q != "E" else 55)
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 900, 900 if q != "E" else 700)
