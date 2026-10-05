"""02_personagens / goleiro_arbitro.py — variacoes especiais.
  A) goleiro classico (amarelo)
  B) goleiro inovacao (rosa + luvas grandes)
  C) arbitro + tecnico lado a lado (INOVACAO p/ cena lateral)
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB

try:
    import bpy
    HAS_BLENDER = True
except ImportError:
    HAS_BLENDER = False


def criar_goleiro(nome, x, y, cor=(0.95, 0.8, 0.1), luvas_grandes=False):
    if not HAS_BLENDER:
        return {"nome": nome}
    kit = LB.mat(f"{nome} | kit", cor)
    preto = LB.mat(f"{nome} | preto", (0.05, 0.05, 0.06))
    pele = LB.mat(f"{nome} | pele", (0.65, 0.38, 0.25))
    luva = LB.mat(f"{nome} | luva", (0.95, 0.95, 0.95))
    root = bpy.data.objects.new(nome, None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, 0)

    def p(o):
        o.parent = root
        return o
    p(LB.box(f"{nome} | camisa", (x, y, 1.27), (0.47, 0.32, 0.50), kit, 0.09))
    p(LB.box(f"{nome} | shorts", (x, y, 0.94), (0.41, 0.32, 0.24), preto, 0.05))
    p(LB.sphere(f"{nome} | cabeca", (x, y, 1.70), (0.19, 0.18, 0.22), pele))
    s = 0.16 if luvas_grandes else 0.09
    for lado in (-1, 1):
        # bracos abertos (pose goleiro)
        p(LB.rod(f"{nome} | braco", (x + lado * 0.25, y, 1.43),
                 (x + lado * 0.55, y, 1.35), 0.075, kit))
        p(LB.sphere(f"{nome} | luva", (x + lado * 0.58, y, 1.35),
                    (s, s, s), luva, 10, 6))
        p(LB.rod(f"{nome} | perna", (x + lado * 0.12, y, 0.88),
                 (x + lado * 0.14, y, 0.16), 0.095, preto, 7))
    LB.texto_3d(f"{nome} | numero", "1", (x, y + 0.175, 1.28), 0.22, preto)
    return root


def criar_arbitro_tecnico():
    if not HAS_BLENDER:
        return {}
    am = LB.mat("Arbitro | preto", (0.08, 0.08, 0.09))
    pele = LB.mat("Arbitro | pele", (0.82, 0.59, 0.43))
    # arbitro
    r = bpy.data.objects.new("Arbitro", None)
    bpy.context.collection.objects.link(r)
    r.location = (-1.2, 0, 0)

    def p2(o):
        o.parent = r
        return o
    p2(LB.box("Arbitro | camisa", (-1.2, 0, 1.27), (0.43, 0.29, 0.48), am, 0.09))
    p2(LB.sphere("Arbitro | cabeca", (-1.2, 0, 1.70), (0.19, 0.18, 0.22), pele))
    p2(LB.box("Arbitro | cartao", (-0.95, 0.2, 1.2), (0.08, 0.02, 0.12),
              LB.mat("Cartao | vermelho", (0.8, 0.05, 0.05)), 0.005))
    # tecnico de terno (inovacao)
    t = bpy.data.objects.new("Tecnico", None)
    bpy.context.collection.objects.link(t)
    t.location = (1.2, 0, 0)

    def p3(o):
        o.parent = t
        return o
    terno = LB.mat("Tecnico | terno", (0.12, 0.15, 0.35))
    p3(LB.box("Tecnico | paleto", (1.2, 0, 1.27), (0.45, 0.31, 0.52), terno, 0.09))
    p3(LB.sphere("Tecnico | cabeca", (1.2, 0, 1.70), (0.19, 0.18, 0.22), pele))
    return {"arbitro": r, "tecnico": t}


def variacao_a():
    LB.limpar_cena()
    criar_goleiro("Goleiro Classico", 0, 0)


def variacao_b():
    LB.limpar_cena()
    criar_goleiro("Goleiro Inovacao", 0, 0, cor=(0.95, 0.25, 0.55), luvas_grandes=True)


def variacao_c():
    LB.limpar_cena()
    criar_arbitro_tecnico()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/goleiro_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a, "B": variacao_b}.get(qual, variacao_c)()
    LB.camera_iso(ortho_scale=8.0, alvo=(0, 0, 1.0))
    LB.luz_estudio()
    LB.render_transparente(out, res_x=800, res_y=800)
