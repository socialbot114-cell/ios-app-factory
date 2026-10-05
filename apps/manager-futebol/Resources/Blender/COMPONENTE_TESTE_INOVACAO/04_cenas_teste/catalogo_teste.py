"""04_cenas_teste / catalogo_teste.py — lista o que renderizar para avaliar qualidade.
Sem Blender instalado aqui, este script valida a sintaxe e gera o guia.

Para renderizar (com Blender instalado):
  blender --background --python 01_estadio/gramado.py -- exports/png/gramado_C.png C
  blender --background --python 01_estadio/arquibancada_modular.py -- exports/png/arq_C.png C
  blender --background --python 01_estadio/cobertura_placar.py -- exports/png/cobertura_C.png C
  blender --background --python 02_personagens/jogador.py -- exports/png/jogador_C.png C
  blender --background --python 02_personagens/goleiro_arbitro.py -- exports/png/goleiro_B.png B
  blender --background --python 03_props/bola_trave.py -- exports/png/bola_C.png C
  blender --background --python 03_props/extras.py -- exports/png/treino.png TREINO
  blender --background --python 04_cenas_teste/cena_inovacao.py -- exports/png/cena_inovacao.png [--noturno]
"""
import py_compile
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
ALVOS = [
    "00_core/lib_base.py",
    "01_estadio/gramado.py",
    "01_estadio/arquibancada_modular.py",
    "01_estadio/cobertura_placar.py",
    "02_personagens/jogador.py",
    "02_personagens/goleiro_arbitro.py",
    "03_props/bola_trave.py",
    "03_props/extras.py",
    "04_cenas_teste/cena_inovacao.py",
]

if __name__ == "__main__":
    ok, falha = [], []
    for rel in ALVOS:
        try:
            py_compile.compile(str(BASE / rel), doraise=True)
            ok.append(rel)
            print("OK:", rel)
        except Exception as e:
            falha.append((rel, e))
            print("FALHA:", rel, e)
    print(f"\n{len(ok)} OK, {len(falha)} falhas.")
