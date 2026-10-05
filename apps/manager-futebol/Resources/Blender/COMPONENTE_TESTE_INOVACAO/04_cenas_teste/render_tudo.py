"""Renderiza todos os componentes (um processo do Blender por imagem) e exporta GLB.

  python3 04_cenas_teste/render_tudo.py [--so cena|pers|props|estadio] [--blender /caminho/blender]
Saida: exports/png/*.png  e  exports/glb/*.glb
"""
import os
import subprocess
import sys
import time

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BL = os.environ.get("BLENDER", "/tmp/opencode/blender-4.2.1-linux-x64/blender")
if "--blender" in sys.argv:
    BL = sys.argv[sys.argv.index("--blender") + 1]
so = sys.argv[sys.argv.index("--so") + 1] if "--so" in sys.argv else None

# (grupo, script, argumentos extras, nome do png)
LISTA = [
    ("estadio", "01_estadio/gramado.py", ["A"], "gramado_A"),
    ("estadio", "01_estadio/gramado.py", ["B"], "gramado_B"),
    ("estadio", "01_estadio/gramado.py", ["C"], "gramado_C"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["A"], "arquibancada_A"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["B"], "arquibancada_B"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["C"], "arquibancada_C"),
    ("estadio", "01_estadio/cobertura_placar.py", ["A"], "cobertura_A"),
    ("estadio", "01_estadio/cobertura_placar.py", ["B"], "cobertura_B"),
    ("estadio", "01_estadio/cobertura_placar.py", ["C"], "cobertura_C"),
    ("pers", "02_personagens/jogador.py", ["A"], "jogador_A"),
    ("pers", "02_personagens/jogador.py", ["B"], "jogador_B"),
    ("pers", "02_personagens/jogador.py", ["C"], "jogador_C"),
    ("pers", "02_personagens/jogador.py", ["E"], "elenco_poses"),
    ("pers", "02_personagens/goleiro_arbitro.py", ["A"], "goleiro_A"),
    ("pers", "02_personagens/goleiro_arbitro.py", ["B"], "goleiro_B"),
    ("pers", "02_personagens/goleiro_arbitro.py", ["C"], "arbitro_tecnico"),
    ("props", "03_props/bola_trave.py", ["A"], "bola_trave_A"),
    ("props", "03_props/bola_trave.py", ["B"], "bola_trave_B"),
    ("props", "03_props/bola_trave.py", ["C"], "bola_trave_C"),
    ("props", "03_props/extras.py", ["TREINO"], "extras_treino"),
    ("props", "03_props/extras.py", ["TROFEU"], "extras_trofeu"),
    ("props", "03_props/extras.py", ["BANCO"], "extras_banco"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["D"], "arquibancada_D"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["E"], "arquibancada_E"),
    ("estadio", "01_estadio/arquibancada_modular.py", ["F"], "arquibancada_F"),
    ("vend", "03_props/vendedores.py", ["A"], "vendedores_A"),
    ("vend", "03_props/vendedores.py", ["B"], "vendedores_carrinhos"),
    ("vend", "03_props/comercio.py", ["A"], "barracas"),
    ("vend", "03_props/comercio.py", ["B"], "food_truck"),
    ("vend", "03_props/comercio.py", ["C"], "bilheteria"),
    ("cid", "05_cidade/cidade.py", ["A"], "cidade_pequena"),
    ("cid", "05_cidade/cidade.py", ["B"], "cidade_media"),
    ("cid", "05_cidade/cidade.py", ["C"], "cidade_grande"),
    ("cid", "05_cidade/cidade.py", ["C", "--noturno"], "cidade_grande_noite"),
    ("est", "01_estadio/estadios.py", ["A"], "estadio_pequeno"),
    ("est", "01_estadio/estadios.py", ["B"], "estadio_medio"),
    ("est", "01_estadio/estadios.py", ["C"], "estadio_grande"),
    ("est", "01_estadio/estadios.py", ["C", "--noturno"], "estadio_grande_noite"),
    ("est", "01_estadio/estadios.py", ["B", "--sem-cidade"], "estadio_medio_detalhe"),
    ("cena", "04_cenas_teste/cena_inovacao.py", ["--cam", "iso"], "cena_dia"),
    ("cena", "04_cenas_teste/cena_inovacao.py", ["--cam", "iso", "--noturno"], "cena_noite"),
    ("cena", "04_cenas_teste/cena_inovacao.py", ["--cam", "tv"], "cena_tv"),
    ("cena", "04_cenas_teste/cena_inovacao.py", ["--cam", "zoom"], "cena_zoom"),
]

for grupo, script, extra, nome in LISTA:
    if so and grupo != so:
        continue
    out = os.path.join(BASE, "exports", "png", nome + ".png")
    # scripts de componente: "-- saida qual" ; cena: "-- saida --cam ..."
    glb = "--glb" in sys.argv
    args = [out] + extra + (["--so-glb"] if glb else [])
    out = os.path.join(BASE, "exports", "glb", nome + ".glb") if glb else out
    cmd = [BL, "-b", "--python", os.path.join(BASE, script), "--"] + args
    t = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True)
    ok = os.path.exists(out) and "Traceback" not in r.stdout + r.stderr
    print(f"{'OK ' if ok else 'ERRO'} {nome:18s} {time.time() - t:6.1f}s", flush=True)
    if not ok:
        print((r.stdout + r.stderr)[-1500:], flush=True)
