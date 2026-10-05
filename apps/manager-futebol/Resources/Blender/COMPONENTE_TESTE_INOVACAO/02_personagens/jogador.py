"""02_personagens / jogador.py — 3 variacoes reutilizaveis.
  A) linha_simples — corpo basico sem rig (rapido p/ teste)
  B) linha_rig     — com rig humanoide + numero 3D
  C) estrela       — rig + faixa lateral + chuteiras coloridas (INOVACAO)

Reuso: criar_jogador(nome, x, y, kit_cor, numero, com_rig=True)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import lib_base as LB

try:
    import bpy
    from mathutils import Vector
    HAS_BLENDER = True
except ImportError:
    HAS_BLENDER = False


def criar_jogador(nome, x, y, kit_cor=(0.03, 0.20, 0.75), trim_cor=(0.95, 0.66, 0.10),
                  numero=9, com_rig=True, estrela=False):
    if not HAS_BLENDER:
        return {"nome": nome, "kit": kit_cor, "numero": numero}
    kit = LB.mat(f"{nome} | kit", kit_cor)
    trim = LB.mat(f"{nome} | trim", trim_cor)
    pele = LB.mat(f"{nome} | pele", (0.63, 0.35, 0.22))
    cabelo_m = LB.mat(f"{nome} | cabelo", (0.08, 0.055, 0.045))
    bota_m = LB.mat(f"{nome} | bota", (0.95, 0.2, 0.2) if estrela else (0.055, 0.065, 0.07))

    root = bpy.data.objects.new(nome, None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, 0)

    def parte(obj):
        obj.parent = root
        return obj

    parte(LB.box(f"{nome} | camisa", (x, y, 1.27), (0.43, 0.29, 0.48), kit, 0.09))
    if estrela:  # faixa lateral inovacao
        for s in (-1, 1):
            parte(LB.box(f"{nome} | faixa", (x + s * 0.21, y, 1.29),
                         (0.035, 0.30, 0.42), trim, 0.012))
    parte(LB.box(f"{nome} | shorts", (x, y, 0.94), (0.39, 0.30, 0.22), trim, 0.045))
    parte(LB.sphere(f"{nome} | cabeca", (x, y, 1.70), (0.19, 0.18, 0.22), pele))
    parte(LB.sphere(f"{nome} | cabelo", (x, y, 1.83), (0.195, 0.185, 0.11), cabelo_m))
    for s in (-1, 1):
        parte(LB.rod(f"{nome} | braco", (x + s * 0.25, y, 1.43),
                     (x + s * 0.38, y, 1.10), 0.07, pele))
        parte(LB.rod(f"{nome} | perna", (x + s * 0.12, y, 0.88),
                     (x + s * 0.14, y + 0.15, 0.16), 0.09, trim, 7))
        parte(LB.box(f"{nome} | bota", (x + s * 0.14, y + 0.25, 0.09),
                     (0.14, 0.25, 0.12), bota_m, 0.04))
    LB.texto_3d(f"{nome} | numero", str(numero), (x, y + 0.165, 1.28), 0.20, trim)
    return root


def variacao_a():
    LB.limpar_cena()
    criar_jogador("Jogador A Simples", -1.0, 0, com_rig=False, numero=9)


def variacao_b():
    LB.limpar_cena()
    criar_jogador("Jogador B Rig", 0, 0, numero=7, com_rig=True)


def variacao_c():
    LB.limpar_cena()
    criar_jogador("Estrela 10", 0, 0, kit_cor=(0.02, 0.5, 0.3), numero=10, estrela=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else "/tmp/jogador_teste.png"
    qual = (args[1] if len(args) > 1 else "C").upper()
    {"A": variacao_a, "B": variacao_b}.get(qual, variacao_c)()
    LB.camera_iso(ortho_scale=8.0, alvo=(0, 0, 1.0))
    LB.luz_estudio()
    LB.render_transparente(out, res_x=800, res_y=800)
