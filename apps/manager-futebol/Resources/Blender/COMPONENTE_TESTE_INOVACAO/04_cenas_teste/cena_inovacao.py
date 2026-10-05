"""04_cenas_teste / cena_inovacao.py — monta tudo junto (playground).
  Junta: gramado premium + arquibancada 4 lados + cobertura arena +
         2 jogadores + goleiro inovacao + bola neon + bandeira + banco.

  blender --background --python cena_inovacao.py -- /tmp/cena_inovacao.png
"""
import os
import sys

AQUI = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(AQUI, "..", "00_core"))
sys.path.insert(0, os.path.join(AQUI, "..", "01_estadio"))
sys.path.insert(0, os.path.join(AQUI, "..", "02_personagens"))
sys.path.insert(0, os.path.join(AQUI, "..", "03_props"))

import lib_base as LB
import gramado as G
import arquibancada_modular as ARQ
import cobertura_placar as COB
import jogador as JOG
import goleiro_arbitro as GOL
import bola_trave as BT
import extras as EXT


def montar_cena():
    LB.limpar_cena()
    # campo + arquibancada (reuso direto das funcoes)
    G.variacao_c_premium()
    ARQ.criar_arquibancada(lados=("norte", "sul", "leste", "oeste"), fileiras=4, com_cadeiras=True)
    COB.criar_cobertura(("norte", "sul"), altura=3.8)
    COB.criar_placar("INOVACAO 1 : 0 TESTE")
    COB.criar_refletores(altura=4.0)
    COB.criar_publicidade(7)
    # personagens
    JOG.criar_jogador("Casa 10", -1.0, 0.2, kit_cor=(0.02, 0.5, 0.3), numero=10, estrela=True)
    JOG.criar_jogador("Fora 4", 1.2, -0.3, kit_cor=(0.78, 0.07, 0.12),
                      trim_cor=(0.92, 0.91, 0.82), numero=4)
    GOL.criar_goleiro("Goleiro Neon", 4.0, 0, cor=(0.95, 0.25, 0.55), luvas_grandes=True)
    BT.criar_bola(x=0.1, y=0.1, neon=True)
    EXT.criar_bandeira()
    EXT.criar_banco()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if len(args) > 0 else os.path.join(
        AQUI, "..", "exports", "png", "cena_inovacao.png")
    montar_cena()
    LB.camera_iso()
    noturno = "--noturno" in sys.argv
    LB.luz_estudio(noturno=noturno)
    LB.render_transparente(out)
