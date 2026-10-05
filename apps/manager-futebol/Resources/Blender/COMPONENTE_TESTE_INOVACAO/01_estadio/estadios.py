"""01_estadio / estadios.py — estadios completos por PORTE (pequeno | medio | grande), com cidade em volta.

  criar_estadio(porte, noturno=False, cidade=True, jogadores=True)

  pequeno : campo municipal, arquibancada tubular de aco (2 lados, 3 fileiras), alambrado, refletores baixos,
            2 barracas, ambulantes, 8 jogadores, bairro de casas.
  medio   : 4 lados (norte/sul 5 fileiras, leste/oeste 3), cobertura norte+sul, placar, publicidade LED,
            bilheteria, barracas + food truck, 14 jogadores, cidade media.
  grande  : bowl de 4 lados com 7 fileiras, camarote VIP, 4 coberturas, telao, refletores altos, traves LED,
            bancos, torcida organizada, bilheterias, calcadao com barracas e food trucks, 22 jogadores, metropole.

Retorna dict com a extensao do estadio (meia_x, meia_y) para o posicionamento da camera.
"""
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
for sub in ("00_core", "01_estadio", "02_personagens", "03_props", "05_cidade"):
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
import vendedores as V
import comercio as COM
import cidade as CID

HL, HW = LB.HL, LB.HW
FRENTE, CORRER = ARQ.FRENTE, ARQ.CORRER

CASA = dict(camisa=(0.03, 0.42, 0.28), detalhe=LB.PAL["ouro"], calcao=LB.PAL["ouro"])
FORA = dict(camisa=(0.70, 0.05, 0.08), detalhe=LB.PAL["branco"], calcao=(0.95, 0.95, 0.95))

# (x, y, pose, cabelo, pele) -- time da casa ataca para +X
_CASA = [(3.9, 0.35, "chutando", "moicano", "bronze"), (4.8, -1.3, "correndo", "afro", "negra"), (4.6, 2.4, "correndo", "curto", "morena"),
         (2.2, 0.9, "parado", "longo", "clara"), (1.4, -1.4, "correndo", "careca", "parda"), (1.0, 2.0, "parado", "curto", "bronze"),
         (-1.5, 0.8, "parado", "coque", "morena"), (-2.2, -2.2, "correndo", "curto", "negra"), (-2.2, 2.5, "parado", "moicano", "clara"),
         (-3.2, 0.2, "parado", "careca", "parda")]
_FORA = [(5.0, 0.9, "correndo", "afro", "negra"), (4.3, -0.5, "defesa", "curto", "clara"), (3.4, 1.7, "correndo", "careca", "morena"),
         (5.0, -1.7, "correndo", "curto", "parda"), (2.4, -0.2, "parado", "coque", "bronze"), (0.7, 0.2, "correndo", "moicano", "morena"),
         (-0.5, -1.8, "parado", "longo", "clara"), (-0.3, 2.4, "parado", "afro", "negra"), (-1.8, -0.8, "lamentando", "curto", "parda")]


def lance(n_casa=10, n_fora=9, noturno=False, goleiros=True):
    bola = (4.3, 0.5)
    for k, (x, y, po, cab, pel) in enumerate(_CASA[:n_casa]):
        JOG.criar_jogador(f"Casa {k + 1}", x, y, **CASA, numero=k + 2 if k else 10, pose=po, cabelo=cab, pele=pel,
                          olhar_para=(HL, 0.0), capitao=(k == 0), estrela=(k == 0))
    for k, (x, y, po, cab, pel) in enumerate(_FORA[:n_fora]):
        JOG.criar_jogador(f"Fora {k + 1}", x, y, **FORA, numero=k + 3, pose=po, cabelo=cab, pele=pel, olhar_para=bola)
    if goleiros:
        GOL.criar_goleiro("Goleiro fora", HL - 0.65, -0.1, cor=(0.95, 0.15, 0.50), luvas_grandes=True, pose="mergulho",
                          olhar_para=(HL - 0.7, 0.9), pele="negra", cabelo="afro", numero=1)
        GOL.criar_goleiro("Goleiro casa", -HL + 0.9, 0.0, cor=(0.97, 0.80, 0.08), olhar_para=(0, 0), pele="clara", numero=1)
    H.arbitro("Arbitro", 2.3, 1.9, pose="apito", olhar_para=bola, pele="clara")
    BT.criar_bola(*bola, estilo="neon" if noturno else "classica", z=0.20)


def _bandeiras():
    for sx in (-1, 1):
        for sy in (-1, 1):
            EXT.criar_bandeira(sx * HL, sy * HW, cor=(0.92, 0.12, 0.10))


def _entorno(ex, ey, itens):
    """Comercio no calcadao: (tipo, x, y, yaw). Sempre olhando para fora do estadio."""
    for tipo, x, y, yaw in itens:
        if tipo in ("lanche", "bebidas", "souvenir", "churrasco"):
            COM.barraca_com_vendedor(tipo, x, y, yaw=yaw, pele=["morena", "negra", "clara", "parda"][len(tipo) % 4],
                                     cabelo=["curto", "afro", "coque", "careca"][len(tipo) % 4], nome=f"Barraca {tipo}{int(x)}")
        elif tipo == "truck":
            COM.criar_food_truck(x, y, yaw=yaw, escala=1.3, cor=[(0.95, 0.75, 0.1), (0.9, 0.2, 0.15), (0.15, 0.6, 0.55)][int(abs(x)) % 3])
        elif tipo == "bilheteria":
            COM.criar_bilheteria(x, y, yaw=yaw, escala=1.4)
        elif tipo == "pipoca":
            V.criar_carrinho("pipoca", x, y, yaw=yaw)
            V.criar_vendedor("guarda", f"Pipoqueiro{int(x)}", x + 0.0, y + 0.5, yaw=yaw, camisa=(0.85, 0.08, 0.1), pele="parda", cabelo="curto")
        elif tipo == "sorvete":
            V.criar_carrinho("sorvete", x, y, yaw=yaw)
            V.criar_vendedor("guarda", f"Sorveteiro{int(x)}", x + 0.0, y + 0.5, yaw=yaw, camisa=(0.2, 0.6, 0.85), pele="morena", cabelo="coque")
        elif tipo == "ambulante":
            V.criar_vendedor("ambulante", f"Ambulante{int(x)}{int(y)}", x, y, yaw=yaw, pele="negra", cabelo="afro")
        elif tipo == "bebidas_amb":
            V.criar_vendedor("bebidas", f"Bebidas{int(x)}{int(y)}", x, y, yaw=yaw, pele="clara", cabelo="curto")
        elif tipo == "guarda":
            V.criar_vendedor("guarda", f"Guarda{int(x)}{int(y)}", x, y, yaw=yaw, pele="morena", cabelo="careca")


def criar_estadio(porte="medio", noturno=False, cidade=True, jogadores=True):
    LB.limpar_cena()
    H.Z_CHAO = 0.06
    refl = None
    if porte == "pequeno":
        G.montar_b()
        ARQ.criar_arquibancada(lados=("norte",), fileiras=3, tubular=True, estilo="xadrez", nome="N",
                               cores=(LB.PAL["azul"], LB.PAL["branco"], LB.PAL["vermelho"]), seed=1, vendedores=2)
        ARQ.criar_arquibancada(lados=("oeste",), fileiras=2, tubular=True, estilo="xadrez", nome="O",
                               cores=(LB.PAL["azul"], LB.PAL["branco"], LB.PAL["vermelho"]), seed=2, muro_fundo=False)
        COB.criar_cobertura(("norte",), fileiras=3, vao=1.5)
        refl = COB.criar_refletores(altura=3.6, afastamento=(HL + 2.2, HW + 2.0), so_norte=True)
        BT.criar_trave(x0=HL, lado=1, nome="Trave D")
        BT.criar_trave(x0=-HL, lado=-1, nome="Trave E")
        _bandeiras()
        ext_x, ext_y = HL + FRENTE + 3 * CORRER + 0.8, HW + FRENTE + 3 * CORRER + 0.8
        if jogadores:
            lance(6, 5, noturno)
        H.Z_CHAO = 0.0
        _entorno(ext_x, ext_y, [("lanche", -4.0, -ext_y - 1.2, math.pi), ("bebidas", 1.5, -ext_y - 1.2, math.pi),
                                ("ambulante", 5.5, -ext_y - 1.0, math.pi), ("pipoca", -7.5, -ext_y - 1.0, math.pi)])
    elif porte == "medio":
        G.montar_c()
        ARQ.criar_arquibancada(lados=("norte",), fileiras=5, estilo="listras", nome="N", bandeiras=True, vendedores=4,
                               cores=(LB.PAL["teal_cl"], LB.PAL["ouro"], LB.PAL["branco"]), seed=1)
        ARQ.criar_arquibancada(lados=("sul",), fileiras=3, estilo="listras", nome="S", muro_fundo=False,
                               cores=(LB.PAL["teal_cl"], LB.PAL["ouro"], LB.PAL["branco"]), seed=2)
        ARQ.criar_arquibancada(lados=("oeste",), fileiras=4, estilo="xadrez", nome="O", seed=3)
        ARQ.criar_arquibancada(lados=("leste",), fileiras=2, estilo="xadrez", nome="L", muro_fundo=False, seed=4)
        COB.criar_cobertura(("norte", "oeste"), fileiras=5)
        COB.criar_placar("CASA 1 : 0 FORA", lado="oeste", fileiras=4)
        refl = COB.criar_refletores(altura=4.6, so_norte=True)
        COB.criar_publicidade(pular_sul=(-4.6, 4.6))
        BT.criar_trave(x0=HL, lado=1, rede_densa=True, nome="Trave D")
        BT.criar_trave(x0=-HL, lado=-1, rede_densa=True, nome="Trave E")
        _bandeiras()
        EXT.criar_banco(-2.6, -HW - 0.95, assentos=5, ocupantes=3, nome="Banco casa")
        EXT.criar_banco(2.6, -HW - 0.95, assentos=5, ocupantes=3, nome="Banco fora")
        ext_x, ext_y = HL + FRENTE + 4 * CORRER + 1.0, HW + FRENTE + 5 * CORRER + 1.0
        if jogadores:
            lance(8, 7, noturno)
        H.Z_CHAO = 0.0
        _entorno(ext_x, ext_y, [("bilheteria", 0.0, -ext_y - 1.4, math.pi), ("truck", -6.5, -ext_y - 1.4, math.pi + 0.3),
                                ("lanche", 5.0, -ext_y - 1.4, math.pi), ("bebidas", 8.5, -ext_y - 1.4, math.pi),
                                ("souvenir", ext_x + 1.6, -3.0, math.pi / 2), ("pipoca", ext_x + 1.6, 2.0, math.pi / 2)])
    else:  # grande
        G.montar_c()
        ARQ.criar_arquibancada(lados=("norte",), fileiras=7, estilo="mosaico", nome="N", bandeiras=True, vendedores=6, seed=1)
        ARQ.criar_arquibancada(lados=("oeste",), fileiras=7, estilo="degrade", nome="O", seed=2,
                               cores=((0.03, 0.30, 0.30), LB.PAL["teal_cl"], LB.PAL["branco"]))
        ARQ.criar_arquibancada(lados=("sul",), fileiras=3, estilo="mosaico", nome="S", muro_fundo=False, seed=3)
        ARQ.criar_arquibancada(lados=("leste",), fileiras=3, estilo="mosaico", nome="L", muro_fundo=False, seed=4)
        ARQ.criar_camarote_vip("norte", fileiras=7)
        COB.criar_cobertura(("norte", "oeste"), fileiras=7)
        COB.criar_placar("CASA 2 : 1 FORA", lado="oeste", fileiras=7)
        refl = COB.criar_refletores(altura=6.0, so_norte=True)
        COB.criar_publicidade(pular_sul=(-4.6, 4.6))
        BT.criar_trave(x0=HL, lado=1, rede_densa=True, premium=True, nome="Trave D")
        BT.criar_trave(x0=-HL, lado=-1, rede_densa=True, premium=True, nome="Trave E")
        _bandeiras()
        EXT.criar_banco(-2.6, -HW - 0.95, assentos=5, ocupantes=3, nome="Banco casa")
        EXT.criar_banco(2.6, -HW - 0.95, assentos=5, ocupantes=3, nome="Banco fora")
        ext_x, ext_y = HL + FRENTE + 7 * CORRER + 1.2, HW + FRENTE + 7 * CORRER + 1.2
        if jogadores:
            lance(10, 9, noturno)
        H.Z_CHAO = 0.0
        _entorno(ext_x, ext_y, [("bilheteria", -3.0, -ext_y - 1.5, math.pi), ("bilheteria", 3.5, -ext_y - 1.5, math.pi),
                                ("truck", -8.5, -ext_y - 1.5, math.pi + 0.25), ("truck", 8.8, -ext_y - 1.5, math.pi - 0.25),
                                ("lanche", -11.5, -ext_y - 1.5, math.pi), ("souvenir", 11.8, -ext_y - 1.5, math.pi),
                                ("bebidas", ext_x + 1.7, -4.5, math.pi / 2), ("churrasco", ext_x + 1.7, -1.5, math.pi / 2),
                                ("pipoca", ext_x + 1.7, 1.5, math.pi / 2), ("sorvete", ext_x + 1.7, 4.5, math.pi / 2),
                                ("ambulante", -5.0, -ext_y - 2.8, math.pi), ("guarda", -2.0, -ext_y - 2.8, math.pi),
                                ("bebidas_amb", 1.5, -ext_y - 2.8, math.pi), ("ambulante", 5.0, -ext_y - 2.8, math.pi)])
    info = dict(meia_x=ext_x, meia_y=ext_y, refletores=refl)
    if cidade:
        CID.criar_cidade(porte, meia_x=ext_x, meia_y=ext_y, noturno=noturno, seed={"pequeno": 3, "medio": 5, "grande": 8}[porte])
    return info


CAMS = {  # location, ortho, alvo (isometrica, mostra o estadio + a cidade)
    "pequeno": dict(location=(21, -26, 22), ortho_scale=36, alvo=(0, -1, 0)),
    "medio": dict(location=(27, -32, 27), ortho_scale=50, alvo=(0, -1, 0)),
    "grande": dict(location=(33, -40, 36), ortho_scale=66, alvo=(0, -1, 2)),
}
CAMS_SO_ESTADIO = {
    "pequeno": dict(location=(15, -19, 15), ortho_scale=24, alvo=(0, 0.5, 0.5)),
    "medio": dict(location=(15.5, -18.5, 17.5), ortho_scale=27, alvo=(0.5, 1.0, 1.0)),
    "grande": dict(location=(17, -21, 20), ortho_scale=32, alvo=(0.5, 1.0, 1.0)),
}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/estadio.png"
    porte = {"A": "pequeno", "B": "medio", "C": "grande"}.get((a[1] if len(a) > 1 else "B").upper(), a[1] if len(a) > 1 else "medio")
    noturno = "--noturno" in a
    sem_cidade = "--sem-cidade" in a
    info = criar_estadio(porte, noturno, cidade=not sem_cidade, jogadores="--sem-jogadores" not in a)
    c = (CAMS_SO_ESTADIO if sem_cidade else CAMS)[porte]
    LB.camera_iso(c["location"], c["ortho_scale"], c["alvo"])
    fundo = ((0.02, 0.04, 0.1), (0.01, 0.02, 0.05)) if noturno else ((0.55, 0.78, 0.95), (0.88, 0.93, 0.98)) if not sem_cidade else ((0.05, 0.30, 0.32), (0.55, 0.78, 0.76))
    LB.luz_estudio(noturno=noturno, fundo=fundo)
    if noturno and info["refletores"]:
        COB.luzes_refletores(info["refletores"], energia=5500)
    rapido = "--rapido" in a
    LB.render(out, 700 if rapido else 1600, 480 if rapido else 1100, samples=16 if rapido else 96)
