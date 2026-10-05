"""04_cenas_teste / cena_inovacao.py — estadio completo montado com todos os componentes (v2).

  blender -b --python cena_inovacao.py -- saida.png [--noturno] [--cam iso|tv|campo|topo|gol] [--cycles]

Lance de jogo: o camisa 10 (verde) chuta na entrada da area, o goleiro rosa mergulha,
zagueiros correm, arbitro acompanha, tecnicos e reservas nos bancos, torcida lotada,
placar 2 x 1, refletores (acesos a noite).
"""
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
for sub in ("00_core", "01_estadio", "02_personagens", "03_props"):
    sys.path.insert(0, os.path.join(AQUI, "..", sub))

import bpy
import lib_base as LB
import gramado as G
import arquibancada_modular as ARQ
import cobertura_placar as COB
import humano as H
import jogador as JOG
import goleiro_arbitro as GOL
import bola_trave as BT
import extras as EXT

HL, HW = LB.HL, LB.HW
CASA = dict(camisa=(0.03, 0.42, 0.28), detalhe=LB.PAL["ouro"], calcao=LB.PAL["ouro"])
FORA = dict(camisa=(0.70, 0.05, 0.08), detalhe=LB.PAL["branco"], calcao=(0.95, 0.95, 0.95))
FACE = math.pi


def montar_cena(noturno=False, torcida=True):
    LB.limpar_cena()
    # --- estrutura
    G.variacao_c_premium()                       # campo + base + calcada + LED
    LB.colecao("Arquibancada")
    # lados altos (fundo da camera): norte e oeste ; baixos (frente): sul e leste, sem muro
    ARQ.criar_arquibancada(lados=("norte",), fileiras=6, torcida=torcida, nome="N", seed=1)
    ARQ.criar_arquibancada(lados=("oeste",), fileiras=6, torcida=torcida, nome="O", seed=2)
    ARQ.criar_arquibancada(lados=("sul",), fileiras=3, torcida=torcida, muro_fundo=False, nome="S", seed=3)
    ARQ.criar_arquibancada(lados=("leste",), fileiras=3, torcida=torcida, muro_fundo=False, nome="L", seed=4)
    ARQ.criar_camarote_vip("norte", fileiras=6)
    COB.criar_cobertura(("norte", "oeste"), fileiras=6)
    COB.criar_placar("CASA 2 : 1 FORA", lado="oeste", fileiras=6)
    refl = COB.criar_refletores(altura=5.6)
    COB.criar_publicidade(pular_sul=(-4.6, 4.6))
    # --- traves
    BT.criar_trave(x0=HL, lado=1, rede_densa=True, premium=True, nome="Trave D")
    BT.criar_trave(x0=-HL, lado=-1, rede_densa=True, premium=True, nome="Trave E")
    EXT.criar_bandeira(HL, HW)
    EXT.criar_bandeira(HL, -HW)
    EXT.criar_bandeira(-HL, HW, cor=(0.92, 0.12, 0.10))
    EXT.criar_bandeira(-HL, -HW)
    # bancos de reservas na lateral sul (olhando o campo)
    EXT.criar_banco(-2.6, -HW - 0.95, yaw=0.0, assentos=5, ocupantes=3, nome="Banco casa")
    EXT.criar_banco(2.6, -HW - 0.95, yaw=0.0, assentos=5, ocupantes=3, nome="Banco fora")
    # --- lance de jogo (casa ataca para +X)
    bola = (4.3, 0.5)
    JOG.criar_jogador("Casa 10", 3.9, 0.35, **CASA, numero=10, pose="chutando", cabelo="moicano", pele="bronze",
                      capitao=True, estrela=True, olhar_para=(HL, 0.0), cor_cabelo=(0.9, 0.7, 0.1))
    GOL.criar_goleiro("Goleiro fora", HL - 0.65, -0.1, cor=(0.95, 0.15, 0.50), luvas_grandes=True,
                      pose="mergulho", olhar_para=(HL - 0.7, 0.9), pele="negra", cabelo="afro", numero=1, yaw=0)
    GOL.criar_goleiro("Goleiro casa", -HL + 0.9, 0.0, cor=(0.97, 0.80, 0.08), olhar_para=(0, 0),
                      pele="clara", numero=1)
    casa = [("Casa 9", 4.8, -1.3, "correndo", "afro", "negra"), ("Casa 11", 4.6, 2.4, "correndo", "curto", "morena"),
            ("Casa 8", 2.2, 0.9, "parado", "longo", "clara"), ("Casa 6", 1.4, -1.4, "correndo", "careca", "parda"),
            ("Casa 7", 1.0, 2.0, "parado", "curto", "bronze"), ("Casa 4", -1.5, 0.8, "parado", "coque", "morena"),
            ("Casa 3", -2.2, -2.2, "correndo", "curto", "negra"), ("Casa 2", -2.2, 2.5, "parado", "moicano", "clara"),
            ("Casa 5", -3.2, 0.2, "parado", "careca", "parda")]
    for n, x, y, po, cab, pel in casa:
        JOG.criar_jogador(n, x, y, **CASA, numero=int(n.split()[1]), pose=po, cabelo=cab, pele=pel,
                          olhar_para=(HL, 0.0))
    fora = [("Fora 9", 5.0, 0.9, "correndo", "afro", "negra"), ("Fora 4", 4.3, -0.5, "defesa", "curto", "clara"),
            ("Fora 5", 3.4, 1.7, "correndo", "careca", "morena"), ("Fora 3", 5.0, -1.7, "correndo", "curto", "parda"),
            ("Fora 8", 2.4, -0.2, "parado", "coque", "bronze"), ("Fora 10", 0.7, 0.2, "correndo", "moicano", "morena"),
            ("Fora 7", -0.5, -1.8, "parado", "longo", "clara"), ("Fora 11", -0.3, 2.4, "parado", "afro", "negra"),
            ("Fora 6", -1.8, -0.8, "lamentando", "curto", "parda")]
    for n, x, y, po, cab, pel in fora:
        JOG.criar_jogador(n, x, y, **FORA, numero=int(n.split()[1]), pose=po, cabelo=cab, pele=pel,
                          olhar_para=bola)
    H.arbitro("Arbitro", 2.3, 1.9, pose="apito", olhar_para=bola, pele="clara")
    H.arbitro("Bandeirinha", 0.6, -HW - 0.45, pose="parado", olhar_para=(0.6, 0), pele="morena", cabelo="curto")
    H.tecnico("Tecnico casa", -3.9, -HW - 0.62, yaw=0, pele="parda")
    H.tecnico("Tecnico fora", 3.9, -HW - 0.62, yaw=0, pele="clara")
    BT.criar_bola(*bola, estilo="neon" if noturno else "classica", z=0.14)
    return refl


CAMS = {
    "iso":   dict(location=(15.5, -18.5, 17.5), ortho_scale=24.0, alvo=(0.5, 1.0, 1.0)),
    "tv":    dict(persp=((-1, -20, 10.5), (0.5, 0.5, 0.2), 38)),
    "campo": dict(persp=((7.5, -8.0, 1.5), (3.4, 0.4, 0.55), 36)),
    "topo":  dict(persp=((0, -3.5, 24.0), (0, 0, 0), 38)),
    "gol":   dict(persp=((-3.4, -3.8, 1.05), (4.9, 0.4, 0.6), 40)),
}


def camera(nome="iso"):
    c = CAMS[nome]
    if "persp" in c:
        loc, alvo, lente = c["persp"]
        return LB.camera_iso(loc, 1, alvo, perspectiva=True, lente=lente)
    return LB.camera_iso(c["location"], c["ortho_scale"], c["alvo"])


if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else os.path.join(AQUI, "..", "exports", "png", "cena_inovacao.png")
    noturno = "--noturno" in a
    cam = a[a.index("--cam") + 1] if "--cam" in a else "iso"
    refl = montar_cena(noturno)
    camera(cam)
    fundo = ((0.03, 0.05, 0.11), (0.01, 0.02, 0.05)) if noturno else ((0.62, 0.78, 0.95), (0.88, 0.93, 0.98))
    LB.luz_estudio(noturno=noturno, fundo=fundo)
    if noturno:
        COB.luzes_refletores(refl, energia=5500)
    motor = "CYCLES" if "--cycles" in a else "EEVEE"
    LB.render(out, 1600, 1100, samples=96 if motor == "CYCLES" else 96, motor=motor)
