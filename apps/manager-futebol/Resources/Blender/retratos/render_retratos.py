"""Retratos de atletas, treinador e contatos (busto, fundo transparente), a partir dos personagens de
COMPONENTE_TESTE_INOVACAO. Cada retrato tem duas imagens: a cor e a máscara da camisa, para o app pintar a camisa
com as cores do clube sem renderizar um retrato por clube.

Uso (headless, Cycles na CPU):
    blender -b --python retratos/render_retratos.py -- saida/ [--so pele:cabelo,...] [--rapido]

Saída: <pele>_<cabelo>.png (cor, camisa branca) e <pele>_<cabelo>_camisa.png (máscara: branco onde é camisa).
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(AQUI, "..", "COMPONENTE_TESTE_INOVACAO")
sys.path.insert(0, os.path.join(BASE, "00_core"))
sys.path.insert(0, os.path.join(BASE, "02_personagens"))
import bpy  # noqa: E402
import lib_base as LB  # noqa: E402
import humano as H  # noqa: E402

PELES = ["clara", "morena", "parda", "negra", "bronze"]
CABELOS = ["careca", "curto", "afro", "moicano", "longo", "coque", "grisalho"]
COR_CABELO = {
    "curto": (0.05, 0.035, 0.03), "afro": (0.03, 0.025, 0.02), "moicano": (0.55, 0.40, 0.08),
    "longo": (0.10, 0.06, 0.04), "coque": (0.04, 0.03, 0.03), "grisalho": (0.65, 0.65, 0.66),
}
BRANCO = (0.92, 0.92, 0.92)


def montar(pele, cabelo, mascara):
    LB.limpar_cena()
    # Para a máscara: camisa branca pura e todo o resto preto; para a cor: camisa branca e o resto natural.
    kw = dict(pele=pele, cabelo=cabelo, cor_cabelo=COR_CABELO.get(cabelo, (0.05, 0.035, 0.03)),
              camisa=BRANCO, detalhe=BRANCO, calcao=BRANCO, numero=None, yaw=3.14 + 0.15)
    if mascara:
        kw.update(pele=(0, 0, 0), cor_cabelo=(0, 0, 0), calcao=(0, 0, 0), bota=(0, 0, 0), luvas=(0, 0, 0))
    H.jogador("Retrato", 0, 0, **kw)


def enquadrar():
    # Busto: câmera perto, na altura da cabeça, perspectiva suave.
    LB.camera_orbita(alvo=(0, 0, 0.88), dist=2.6, azimute=0, elevacao=4, ortho_scale=None, lente=85)


def luz(mascara):
    if mascara:
        # Máscara sem sombra nem céu: só branco ou preto.
        w = bpy.context.scene.world or bpy.data.worlds.new("W")
        bpy.context.scene.world = w
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    else:
        LB.luz_estudio(noturno=False)


def pintar_mascara():
    """Deixa a camisa emissiva branca e o resto preto emissivo, para a máscara sair chapada."""
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            # Só o material da camisa (nome "...|camisa") fica branco; olhos, dentes e calção ficam pretos.
            e_camisa = mat.name.endswith("|camisa") or mat.name.endswith("|gola")
            bsdf.inputs["Emission Color"].default_value = (1, 1, 1, 1) if e_camisa else (0, 0, 0, 1)
            bsdf.inputs["Emission Strength"].default_value = 1.0
            bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)


def render(pele, cabelo, pasta, mascara, rapido):
    montar(pele, cabelo, mascara)
    enquadrar()
    luz(mascara)
    if mascara:
        pintar_mascara()
    sufixo = "_camisa" if mascara else ""
    caminho = os.path.join(pasta, f"{pele}_{cabelo}{sufixo}.png")
    LB.render(caminho, res_x=360 if rapido else 540, res_y=450 if rapido else 675,
              samples=12 if rapido else 48, transparente=True, motor="CYCLES")


if __name__ == "__main__":
    args = LB.args_cli()
    pasta = args[0] if args else os.path.join(AQUI, "saida")
    rapido = "--rapido" in args
    combos = [(p, c) for p in PELES for c in CABELOS]
    if "--so" in args:
        pedido = args[args.index("--so") + 1].split(",")
        combos = [tuple(item.split(":")) for item in pedido]
    for pele, cabelo in combos:
        render(pele, cabelo, pasta, mascara=False, rapido=rapido)
        render(pele, cabelo, pasta, mascara=True, rapido=rapido)
