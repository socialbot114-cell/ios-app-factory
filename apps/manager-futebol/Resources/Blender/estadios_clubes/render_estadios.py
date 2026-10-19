"""Um estádio para cada clube da liga, com as cores do clube nas arquibancadas, na cobertura e no uniforme dos jogadores.

Uso (headless, Cycles na CPU):
    blender -b --python estadios_clubes/render_estadios.py -- saida/ [--so 0,3,9] [--rapido] [--noturno]

Saída: clube_<id>.png (900x610). O porte (pequeno, médio, grande) segue a capacidade do estádio do clube,
a mesma regra usada pelo app (`FootballClubView.stadiumImageName`).
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(AQUI, "..", "COMPONENTE_TESTE_INOVACAO")
for sub in ("00_core", "01_estadio", "02_personagens", "03_props", "05_cidade"):
    sys.path.insert(0, os.path.join(BASE, sub))
sys.path.insert(0, os.path.join(BASE, "01_estadio"))
import lib_base as LB  # noqa: E402
import estadios as E  # noqa: E402
import cobertura_placar as COB  # noqa: E402

# id: (capacidade, cor principal, cor secundária) — iguais às do app (FootballSeason.teams e LeagueTeam.primaryColor/secondaryColor)
CLUBES = {
    0: (52000, (0.95, 0.55, 0.10), (0.98, 0.86, 0.40)), 1: (38000, (0.72, 0.11, 0.14), (1, 1, 1)),
    2: (45000, (0.05, 0.42, 0.70), (0.55, 0.85, 0.95)), 3: (48000, (0.16, 0.18, 0.22), (0.98, 0.86, 0.40)),
    4: (44000, (0.10, 0.25, 0.55), (1, 1, 1)), 5: (27000, (0.00, 0.50, 0.48), (1, 1, 1)),
    6: (40000, (0.45, 0.20, 0.55), (0.95, 0.78, 0.20)), 7: (33000, (0.16, 0.55, 0.24), (1, 1, 1)),
    8: (26000, (0.00, 0.62, 0.78), (1, 1, 1)), 9: (22000, (0.62, 0.36, 0.16), (0.98, 0.92, 0.75)),
    10: (30000, (0.33, 0.47, 0.18), (1, 1, 1)), 11: (24000, (0.92, 0.72, 0.05), (0.20, 0.30, 0.15)),
    12: (18000, (0.18, 0.36, 0.78), (1, 1, 1)), 13: (15000, (0.50, 0.12, 0.16), (0.98, 0.86, 0.40)),
    14: (21000, (0.85, 0.30, 0.10), (1, 1, 1)), 15: (25000, (0.10, 0.30, 0.42), (0.55, 0.85, 0.95)),
    16: (16000, (0.30, 0.30, 0.32), (0.98, 0.86, 0.40)), 17: (12000, (0.70, 0.55, 0.20), (0.20, 0.18, 0.12)),
    18: (14000, (0.12, 0.40, 0.30), (1, 1, 1)), 19: (13000, (0.20, 0.45, 0.65), (1, 1, 1)),
}


def porte(capacidade):
    if capacidade < 30_000:
        return "pequeno"
    if capacidade < 42_000:
        return "medio"
    return "grande"


def aplicar_cores(principal, secundaria):
    """As arquibancadas e o uniforme usam estas entradas da paleta; trocá-las pinta o estádio com as cores do clube."""
    for chave in ("teal_cl", "azul"):
        LB.PAL[chave] = principal
    for chave in ("ouro", "vermelho"):
        LB.PAL[chave] = secundaria
    E.CASA.update(camisa=principal, detalhe=secundaria, calcao=secundaria)


def renderizar(clube, pasta, rapido, noturno):
    capacidade, principal, secundaria = CLUBES[clube]
    tamanho = porte(capacidade)
    aplicar_cores(principal, secundaria)
    info = E.criar_estadio(tamanho, noturno, cidade=True, jogadores=True)
    cam = E.CAMS[tamanho]
    LB.camera_iso(cam["location"], cam["ortho_scale"], cam["alvo"])
    fundo = ((0.02, 0.04, 0.1), (0.01, 0.02, 0.05)) if noturno else ((0.55, 0.78, 0.95), (0.88, 0.93, 0.98))
    LB.luz_estudio(noturno=noturno, fundo=fundo)
    if noturno and info["refletores"]:
        COB.luzes_refletores(info["refletores"], energia=5500)
    nome = f"clube_{clube}{'_noite' if noturno else ''}.png"
    LB.render(os.path.join(pasta, nome), 560 if rapido else 900, 380 if rapido else 610,
              samples=10 if rapido else 40, motor="CYCLES")


if __name__ == "__main__":
    args = LB.args_cli()
    pasta = args[0] if args else os.path.join(AQUI, "saida")
    rapido = "--rapido" in args
    noturno = "--noturno" in args
    ids = sorted(CLUBES)
    if "--so" in args:
        ids = [int(x) for x in args[args.index("--so") + 1].split(",")]
    for clube in ids:
        renderizar(clube, pasta, rapido, noturno)
