"""02_personagens / humano.py — construtor de personagens articulados (v2).

Um esqueleto simples (quadril, joelhos, ombros, cotovelos) com cinematica direta
gera POSES reais (parado, correndo, chutando, comemorando, defesa, mergulho,
apito, cartao, sentado...). Papeis: jogador, goleiro, arbitro, tecnico.
Proporcao "toy": cabecao, ~1.05 de altura, olhos com brilho, cabelos variados.

Convencao: personagem olha para +Y no espaco local; yaw gira em Z.
Todas as pecas sao criadas em coordenadas LOCAIS e parenteadas ao root
(corrige o bug da v1, que somava o offset duas vezes).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import bpy
from mathutils import Vector
import lib_base as LB

TONS_PELE = {
    "clara": (0.80, 0.55, 0.42),
    "morena": (0.60, 0.36, 0.23),
    "parda": (0.45, 0.25, 0.15),
    "negra": (0.22, 0.11, 0.07),
    "bronze": (0.70, 0.45, 0.30),
}

# ---------------------------------------------------------------- poses
# hip=(flexao, abducao) ; knee=flexao do joelho ; arm=(flexao, abducao) ; elbow=flexao
POSES = {
    "parado": dict(lean=0.03, hl=(0.05, 0.07), hr=(-0.03, 0.07), kl=0.08, kr=0.12,
                   al=(0.05, 0.20), ar=(0.05, 0.20), el=0.25, er=0.25),
    "correndo": dict(lean=0.28, hl=(1.0, 0.05), hr=(-0.65, 0.05), kl=1.15, kr=1.35,
                     al=(-0.9, 0.12), ar=(1.0, 0.12), el=1.5, er=1.45),
    "chutando": dict(lean=-0.12, hl=(-0.15, 0.08), hr=(1.15, 0.05), kl=0.35, kr=0.25,
                     al=(0.8, 0.95), ar=(-0.7, 0.6), el=0.2, er=0.4),
    "comemorando": dict(lean=-0.12, hl=(0.12, 0.28), hr=(0.12, 0.28), kl=0.15, kr=0.15,
                        al=(2.75, 0.45), ar=(2.75, 0.45), el=0.25, er=0.25),
    "defesa": dict(lean=0.32, hl=(0.65, 0.35), hr=(0.65, 0.35), kl=1.0, kr=1.0,
                   al=(1.15, 0.55), ar=(1.15, 0.55), el=0.45, er=0.45),
    "mergulho": dict(lean=0.0, hl=(0.1, 0.1), hr=(-0.2, 0.2), kl=0.2, kr=0.6,
                     al=(2.55, 0.45), ar=(2.55, 0.45), el=0.0, er=0.0, roll=1.25, elev=0.55),
    "apito": dict(lean=0.05, hl=(0.1, 0.07), hr=(-0.1, 0.07), kl=0.1, kr=0.15,
                  al=(0.05, 0.2), ar=(2.15, 0.15), el=0.2, er=2.2),
    "cartao": dict(lean=0.0, hl=(0.1, 0.07), hr=(-0.1, 0.07), kl=0.1, kr=0.15,
                   al=(0.05, 0.2), ar=(2.95, 0.25), el=0.2, er=0.1),
    "sentado": dict(lean=0.08, hl=(1.5, 0.12), hr=(1.5, 0.12), kl=1.45, kr=1.45,
                    al=(0.55, 0.25), ar=(0.55, 0.25), el=0.9, er=0.9),
    "bracos_cruzados": dict(lean=0.0, hl=(0.02, 0.09), hr=(0.02, 0.09), kl=0.05, kr=0.05,
                            al=(0.85, -0.25), ar=(0.85, -0.25), el=2.3, er=2.3),
    "lamentando": dict(lean=0.25, hl=(0.1, 0.1), hr=(0.1, 0.1), kl=0.15, kr=0.15,
                       al=(2.3, 0.1), ar=(2.3, 0.1), el=2.5, er=2.5),
}

# medidas (toy)
COXA, CANELA = 0.19, 0.19
BRACO, ANTEBRACO = 0.14, 0.135
TRONCO = 0.30
Z_QUADRIL = 0.43
RAIO_CABECA = 0.175
Z_CHAO = 0.0   # altura do piso onde os pes pousam (a cena de estadio usa 0.06)


def _dir(flex, abd, lado):
    v = Vector((lado * math.sin(abd), math.sin(flex) * math.cos(abd),
                -math.cos(flex) * math.cos(abd)))
    return v.normalized()


def _esqueleto(p):
    """Posicoes das juntas (frame local, quadril em z=Z_QUADRIL, sem grounding)."""
    sk = {}
    hip = Vector((0, 0, Z_QUADRIL))
    sk["hip"] = hip
    lean = p["lean"]
    up = Vector((0, -math.sin(lean) * -1, math.cos(lean)))  # inclina p/ +Y
    up = Vector((0, math.sin(lean), math.cos(lean)))
    sk["neck"] = hip + up * TRONCO
    sk["up"] = up
    for lado, k in ((-1, "l"), (1, "r")):
        h0 = hip + Vector((lado * 0.078, 0, -0.005))
        fx, ab = p["h" + k]
        knee = h0 + _dir(fx, ab, lado) * COXA
        ankle = knee + _dir(fx - p["k" + k], ab * 0.4, lado) * CANELA
        sk[f"hip_{k}"], sk[f"knee_{k}"], sk[f"ankle_{k}"] = h0, knee, ankle
        sh = sk["neck"] + Vector((lado * 0.168, 0, -0.045)) - up * 0.0
        afx, aab = p["a" + k]
        elbow = sh + _dir(afx, aab, lado) * BRACO
        hand = elbow + _dir(afx + p["e" + k], aab * 0.5, lado) * ANTEBRACO
        sk[f"sh_{k}"], sk[f"elbow_{k}"], sk[f"hand_{k}"] = sh, elbow, hand
    return sk


def criar_humano(nome, x=0.0, y=0.0, yaw=0.0, olhar_para=None, papel="jogador", pose="parado",
                 camisa=LB.PAL["teal_cl"], calcao=LB.PAL["branco"], meia=None,
                 detalhe=LB.PAL["ouro"], bota=(0.03, 0.03, 0.035), numero=None,
                 pele="morena", cabelo="curto", cor_cabelo=(0.05, 0.035, 0.03),
                 capitao=False, escala=1.0, cartao=None, luvas=(0.92, 0.92, 0.9),
                 gola=True, listra_meia=True, acessorio=None):
    """Cria um personagem e devolve o root (Empty). Todos os filhos ficam sob ele."""
    antes = set(bpy.data.objects)
    p = dict(POSES[pose] if isinstance(pose, str) else pose)
    sk = _esqueleto(p)

    # grounding: tornozelo mais baixo toca o chao (bota ~0.055)
    elev = p.get("elev")
    base = min(sk["ankle_l"].z, sk["ankle_r"].z)
    dz = (0.06 - base) if elev is None else elev
    for k in sk:
        if isinstance(sk[k], Vector) and k != "up":
            sk[k] = sk[k] + Vector((0, 0, dz))

    c_pele = TONS_PELE.get(pele, pele)
    if papel == "arbitro":
        camisa, calcao, meia, detalhe = (0.025, 0.026, 0.03), (0.02, 0.02, 0.025), (0.02, 0.02, 0.025), (0.9, 0.78, 0.1)
    elif papel == "tecnico":
        camisa, calcao, meia, detalhe = (0.05, 0.07, 0.17), (0.04, 0.05, 0.13), (0.03, 0.03, 0.04), (0.75, 0.05, 0.08)
    meia = meia or camisa
    m_camisa = LB.mat(f"{nome}|camisa", camisa, 0.78, sheen=0.5)
    m_calcao = LB.mat(f"{nome}|calcao", calcao, 0.8, sheen=0.4)
    m_meia = LB.mat(f"{nome}|meia", meia, 0.85)
    m_det = LB.mat(f"{nome}|detalhe", detalhe, 0.6)
    m_pele = LB.mat(f"{nome}|pele", c_pele, 0.55, sheen=0.2)
    m_bota = LB.mat(f"{nome}|bota", bota, 0.35, verniz=0.5)
    m_cab = LB.mat(f"{nome}|cabelo", cor_cabelo, 0.6)
    m_olho = LB.mat(f"{nome}|olho", (0.01, 0.01, 0.012), 0.2)
    m_bril = LB.mat(f"{nome}|brilho", (1, 1, 1), 0.2)
    m_luva = LB.mat(f"{nome}|luva", luvas, 0.55)
    manga_longa = papel in ("goleiro", "arbitro_longo")

    # ---------------- pernas
    for lado, k in ((-1, "l"), (1, "r")):
        h, kn, an = sk[f"hip_{k}"], sk[f"knee_{k}"], sk[f"ankle_{k}"]
        calca = papel in ("tecnico",) or (papel == "goleiro" and False)
        # coxa: calcao ate ~55%, pele depois
        meio = h.lerp(kn, 0.62 if not calca else 1.0)
        LB.membro(f"{nome} coxa {k} pele", h, kn, 0.060, 0.050, m_calcao if calca else m_pele)
        LB.rod(f"{nome} calcao {k}", h, meio, 0.072, m_calcao, 18, radius2=0.068)
        # canela: meiao
        LB.membro(f"{nome} meia {k}", kn.lerp(an, 0.04), an, 0.052, 0.042, m_calcao if calca else m_meia)
        if listra_meia and papel in ("jogador", "goleiro") and not calca:
            topo = kn.lerp(an, 0.20)
            LB.rod(f"{nome} listra meia {k}", topo, kn.lerp(an, 0.32), 0.054, m_det, 16, radius2=0.052)
        # chuteira
        dirfrente = Vector((0, 1, 0))
        pe_c = an + dirfrente * 0.055 + Vector((0, 0, -0.03))
        b = LB.box(f"{nome} bota {k}", pe_c, (0.085, 0.19, 0.075), m_bota, 0.03)
    # ---------------- quadril/shorts
    pel = sk["hip"] + Vector((0, 0, 0.0))
    LB.box(f"{nome} calcao", pel + Vector((0, 0, 0.0)), (0.275, 0.175, 0.13), m_calcao, 0.05)

    # ---------------- tronco
    up = sk["up"]
    centro = sk["hip"] + up * (TRONCO * 0.5 + 0.02)
    tronco = LB.box(f"{nome} tronco", centro, (0.285, 0.175, TRONCO), m_camisa, 0.07)
    lean = p["lean"]
    tronco.rotation_euler = (-lean, 0, 0)  # rot +X inclina topo p/ -Y; queremos +Y
    # peitoral + ombros arredondados
    for lado, k in ((-1, "l"), (1, "r")):
        s = sk[f"sh_{k}"]
        LB.sphere(f"{nome} ombro {k}", s, (0.062,) * 3, m_camisa)
        # manga
        e = sk[f"elbow_{k}"]
        if manga_longa:
            LB.membro(f"{nome} braco {k}", s, e, 0.052, 0.046, m_camisa)
            LB.membro(f"{nome} antebraco {k}", e, sk[f"hand_{k}"], 0.046, 0.04, m_camisa)
        else:
            LB.membro(f"{nome} braco pele {k}", s, e, 0.046, 0.040, m_pele)
            LB.rod(f"{nome} manga {k}", s, s.lerp(e, 0.50), 0.060, m_camisa, 18, radius2=0.054)
            LB.membro(f"{nome} antebraco {k}", e, sk[f"hand_{k}"], 0.040, 0.034, m_pele)
        hnd = sk[f"hand_{k}"]
        if papel == "goleiro":
            LB.sphere(f"{nome} luva {k}", hnd, (0.085, 0.07, 0.085), m_luva)
            LB.sphere(f"{nome} luva punho {k}", hnd.lerp(e, 0.2), (0.05, 0.05, 0.05), m_det)
        else:
            LB.sphere(f"{nome} mao {k}", hnd, (0.04,) * 3, m_pele)
        if capitao and k == "l":
            ab = s.lerp(e, 0.62)
            LB.rod(f"{nome} braçadeira", ab, ab + (e - s).normalized() * 0.03, 0.058, m_det, 18)
    # gola + pescoco
    neck = sk["neck"]
    LB.rod(f"{nome} pescoco", neck - up * 0.02, neck + up * 0.05, 0.05, m_pele, 14)
    if papel == "tecnico":
        LB.box(f"{nome} camisa social", neck + Vector((0, 0.07, -0.12)), (0.07, 0.02, 0.2),
               LB.mat(f"{nome}|social", (0.9, 0.9, 0.92), 0.6), 0.01)
        LB.box(f"{nome} gravata", neck + Vector((0, 0.088, -0.15)), (0.032, 0.012, 0.19),
               LB.mat(f"{nome}|gravata", (0.7, 0.05, 0.08), 0.5), 0.006)
        for lado in (-1, 1):  # lapelas
            LB.box(f"{nome} lapela", neck + Vector((lado * 0.05, 0.088, -0.10)), (0.045, 0.012, 0.17),
                   m_camisa, 0.006, rot=(0, lado * 0.25, 0))
    elif gola and papel in ("jogador", "goleiro"):
        LB.rod(f"{nome} gola", neck + up * 0.0, neck + up * 0.03, 0.058, m_det, 16, radius2=0.052)
    # numero atras (e pequeno na frente)
    if numero is not None and papel in ("jogador", "goleiro"):
        t = LB.texto_3d(f"{nome} numero", str(numero),
                        centro + Vector((0, -0.092, 0.015)), 0.15, m_det,
                        rot=(math.pi / 2 - lean, 0, 0), extrude=0.006)
        t2 = LB.texto_3d(f"{nome} numero frente", str(numero),
                         centro + Vector((0, 0.092, 0.06)), 0.07, m_det,
                         rot=(math.pi / 2 - lean, 0, math.pi), extrude=0.004)

    # ---------------- cabeca
    H = neck + up * (RAIO_CABECA + 0.02) + Vector((0, 0.01, 0))
    cab = LB.sphere(f"{nome} cabeca", H, (RAIO_CABECA, RAIO_CABECA * 0.96, RAIO_CABECA * 1.02), m_pele, 32, 20)
    for lado in (-1, 1):
        LB.sphere(f"{nome} orelha", H + Vector((lado * RAIO_CABECA * 0.97, -0.005, -0.005)),
                  (0.026, 0.02, 0.04), m_pele, 12, 8)
        ol = H + Vector((lado * 0.068, RAIO_CABECA * 0.92, 0.0))
        LB.sphere(f"{nome} olho", ol, (0.026, 0.016, 0.032), m_olho, 14, 10)
        LB.sphere(f"{nome} brilho", ol + Vector((0.008, 0.012, 0.014)), (0.009,) * 3, m_bril, 8, 6)
        LB.box(f"{nome} sobrancelha", H + Vector((lado * 0.068, RAIO_CABECA * 0.9, 0.058)),
               (0.05, 0.012, 0.011), m_cab, 0.004, rot=(0, lado * 0.12, 0))
    LB.sphere(f"{nome} nariz", H + Vector((0, RAIO_CABECA * 0.97, -0.018)), (0.022, 0.018, 0.02),
              LB.mat(f"{nome}|nariz", tuple(c * 0.85 for c in c_pele), 0.5), 10, 8)
    LB.sphere(f"{nome} boca", H + Vector((0, RAIO_CABECA * 0.92, -0.065)), (0.034, 0.01, 0.011),
              LB.mat(f"{nome}|boca", (0.35, 0.06, 0.07), 0.4), 10, 6)

    # cabelo
    if cabelo == "curto":
        LB.sphere(f"{nome} cabelo", H + Vector((0, -0.02, 0.045)), (0.182, 0.176, 0.150), m_cab, 28, 16)
    elif cabelo == "afro":
        LB.sphere(f"{nome} cabelo", H + Vector((0, -0.015, 0.06)), (0.215, 0.20, 0.175), m_cab, 28, 16)
    elif cabelo == "moicano":
        for i in range(9):
            LB.sphere(f"{nome} moicano", H + Vector((0, 0.10 - i * 0.027, 0.150 + 0.05 * math.sin(i / 8 * math.pi))),
                      (0.034, 0.042, 0.06), m_cab, 10, 8)
        LB.sphere(f"{nome} cabelo base", H + Vector((0, -0.03, 0.065)), (0.176, 0.17, 0.12),
                  LB.mat(f"{nome}|rapado", tuple(c * 0.55 + 0.1 * p_ for c, p_ in zip(c_pele, (0.2, 0.2, 0.2))), 0.7), 24, 14)
    elif cabelo == "longo":
        LB.sphere(f"{nome} cabelo", H + Vector((0, -0.025, 0.04)), (0.186, 0.18, 0.155), m_cab, 28, 16)
        LB.sphere(f"{nome} cabelo costas", H + Vector((0, -0.12, -0.07)), (0.15, 0.08, 0.20), m_cab, 20, 12)
    elif cabelo == "coque":
        LB.sphere(f"{nome} cabelo", H + Vector((0, -0.02, 0.04)), (0.182, 0.176, 0.150), m_cab, 28, 16)
        LB.sphere(f"{nome} coque", H + Vector((0, -0.06, 0.19)), (0.07, 0.07, 0.07), m_cab, 16, 10)
    elif cabelo == "grisalho":
        LB.sphere(f"{nome} cabelo", H + Vector((0, -0.025, 0.055)), (0.182, 0.175, 0.15),
                  LB.mat(f"{nome}|grisalho", (0.65, 0.65, 0.66), 0.7), 24, 14)
    # careca: nada

    # adereços de papel
    if papel == "arbitro":
        hand = sk["hand_r"]
        if pose == "apito":
            LB.sphere(f"{nome} apito", H + Vector((0.0, RAIO_CABECA * 0.95, -0.085)), (0.026, 0.02, 0.018),
                      LB.mat(f"{nome}|apito", (0.9, 0.9, 0.2), 0.3, metallic=0.6), 10, 8)
        if cartao or pose == "cartao":
            cor = {"amarelo": (0.95, 0.75, 0.05), "vermelho": (0.85, 0.05, 0.05)}.get(
                cartao or "vermelho")
            LB.box(f"{nome} cartao", hand + Vector((0, 0.01, 0.07)), (0.06, 0.012, 0.09),
                   LB.mat(f"{nome}|cartao", cor, 0.4, verniz=0.6), 0.004)
    if papel == "tecnico" and pose == "parado":
        LB.box(f"{nome} prancheta", sk["hand_l"] + Vector((0, 0.04, 0.0)), (0.11, 0.012, 0.15),
               LB.mat(f"{nome}|prancheta", (0.9, 0.9, 0.85), 0.5), 0.004, rot=(0.3, 0, 0))

    if acessorio:   # gancho: acessorio(ctx) cria pecas extras (bandeja, bone, caixa...) antes da fusao
        acessorio(dict(sk=sk, neck=neck, up=up, head=H, centro=centro, nome=nome, pele=m_pele, camisa=m_camisa, detalhe=m_det))

    # ---------------- funde tudo em UMA malha (aplica bisel/curvas/texto) e posiciona
    novos = [o for o in bpy.data.objects if o not in antes]
    root = LB.fundir(novos, nome)
    if olhar_para is not None:
        dx, dy = olhar_para[0] - x, olhar_para[1] - y
        yaw = math.atan2(-dx, dy)
    roll = p.get("roll", 0.0)
    off = Vector((0, 0, 0))
    if roll:  # centraliza o corpo deitado sobre (x, y)
        from mathutils import Euler
        off = Euler((0, roll, yaw), "XYZ").to_matrix() @ Vector((0, 0, 0.5 * escala))
    root.location = (x - off.x, y - off.y, Z_CHAO)
    root.rotation_euler = (0, roll, yaw)
    root.scale = (escala,) * 3
    return root


# ---------------------------------------------------------------- presets
def jogador(nome, x, y, **kw):
    return criar_humano(nome, x, y, papel="jogador", **kw)


def goleiro(nome, x, y, cor=(0.95, 0.78, 0.1), **kw):
    kw.setdefault("pose", "defesa")
    kw.setdefault("calcao", (0.04, 0.04, 0.05))
    kw.setdefault("detalhe", (0.05, 0.05, 0.06))
    return criar_humano(nome, x, y, papel="goleiro", camisa=cor, **kw)


def arbitro(nome, x, y, **kw):
    return criar_humano(nome, x, y, papel="arbitro", cabelo=kw.pop("cabelo", "curto"), **kw)


def tecnico(nome, x, y, **kw):
    kw.setdefault("pose", "bracos_cruzados")
    kw.setdefault("cabelo", "grisalho")
    return criar_humano(nome, x, y, papel="tecnico", **kw)
