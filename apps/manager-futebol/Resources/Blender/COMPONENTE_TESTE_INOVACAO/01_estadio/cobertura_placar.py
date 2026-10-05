"""01_estadio / cobertura_placar.py — cobertura, placar, refletores, publicidade LED (v2).
  A) simples — 1 cobertura norte + placar pequeno
  B) dupla   — 2 coberturas + 4 refletores + placas
  C) arena   — 4 coberturas + telao + LED + refletores altos (noite com luz real)

Reutilizaveis: criar_cobertura(lados, fileiras), criar_placar(...), criar_refletores(...),
               criar_publicidade(...), luzes_refletores(...)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "00_core"))
import bpy
import lib_base as LB
from mathutils import Vector

HL, HW = LB.HL, LB.HW
FRENTE, CORRER, SUBIR = 1.3, 0.40, 0.26


def criar_cobertura(lados=("norte",), fileiras=4, vao=2.5):
    """Telhado em balanco sobre as fileiras de tras, com colunas e tirantes."""
    LB.colecao("Cobertura")
    topo_m = LB.mat("Cob|telha", LB.PAL["teal"], 0.45, verniz=0.5, metallic=0.2)
    sub_m = LB.mat("Cob|forro", (0.90, 0.90, 0.86), 0.7)
    col_m = LB.mat("Cob|coluna", (0.82, 0.82, 0.78), 0.35, metallic=0.5)
    led_m = LB.mat("Cob|led", (0.2, 0.95, 0.9), 0.3, emissao=(0.2, 1.0, 0.9), forca=7.0)
    ouro = LB.mat("Cob|ouro", LB.PAL["ouro"], 0.3, metallic=0.9)
    for lado in lados:
        longo = lado in ("norte", "sul")
        s = 1 if lado in ("norte", "leste") else -1
        d0 = (HW if longo else HL) + FRENTE
        dfundo = d0 + fileiras * CORRER
        h_topo = fileiras * SUBIR
        h_tel = h_topo + 1.75
        d_ini = dfundo + 0.28
        d_fim = d_ini - (fileiras - 0.6) * CORRER - vao * 0.0 - 0.0
        d_fim = d0 + max(1.0, fileiras - vao) * CORRER
        prof = d_ini - d_fim
        dc = (d_ini + d_fim) / 2
        comp = (2 * (HL + FRENTE + fileiras * CORRER * 0.95)) if longo else 2 * (HW + FRENTE)
        if longo:
            pos = lambda a, d, z: (a, s * d, z)
            LB.box(f"Cob {lado} telha", (0, s * dc, h_tel), (comp, prof, 0.10), topo_m, 0.03, rot=(s * 0.05, 0, 0))
            LB.box(f"Cob {lado} forro", (0, s * dc, h_tel - 0.06), (comp - 0.1, prof - 0.06, 0.02), sub_m, 0.005, rot=(s * 0.05, 0, 0))
            LB.box(f"Cob {lado} beiral", (0, s * d_fim, h_tel - 0.05), (comp, 0.07, 0.2), ouro, 0.02)
            LB.box(f"Cob {lado} led", (0, s * (d_fim - 0.045), h_tel - 0.06), (comp - 0.3, 0.02, 0.05), led_m, 0.008)
        else:
            LB.box(f"Cob {lado} telha", (s * dc, 0, h_tel), (prof, comp, 0.10), topo_m, 0.03, rot=(0, -s * 0.05, 0))
            LB.box(f"Cob {lado} forro", (s * dc, 0, h_tel - 0.06), (prof - 0.06, comp - 0.1, 0.02), sub_m, 0.005, rot=(0, -s * 0.05, 0))
            LB.box(f"Cob {lado} beiral", (s * d_fim, 0, h_tel - 0.05), (0.07, comp, 0.2), ouro, 0.02)
            LB.box(f"Cob {lado} led", (s * (d_fim - 0.045), 0, h_tel - 0.06), (0.02, comp - 0.3, 0.05), led_m, 0.008)
        n = max(3, int(comp / 2.4))
        for i in range(n + 1):
            a = (i / n - 0.5) * (comp - 0.5)
            if longo:
                LB.rod(f"Cob coluna", (a, s * d_ini, 0), (a, s * d_ini, h_tel), 0.065, col_m, 12)
                LB.rod(f"Cob tirante", (a, s * d_ini, h_tel), (a, s * d_fim, h_tel - 0.04), 0.03, col_m, 8)
                LB.rod(f"Cob escora", (a, s * d_ini, h_tel - 0.7), (a, s * (d_ini - prof * 0.55), h_tel), 0.025, col_m, 8)
            else:
                LB.rod(f"Cob coluna", (s * d_ini, a, 0), (s * d_ini, a, h_tel), 0.065, col_m, 12)
                LB.rod(f"Cob tirante", (s * d_ini, a, h_tel), (s * d_fim, a, h_tel - 0.04), 0.03, col_m, 8)
                LB.rod(f"Cob escora", (s * d_ini, a, h_tel - 0.7), (s * (d_ini - prof * 0.55), a, h_tel), 0.025, col_m, 8)


def criar_placar(texto="CASA 2 : 1 FORA", lado="oeste", fileiras=6, tamanho=(4.6, 1.5), cor=(1.0, 0.82, 0.25), sub="FUTOS ARENA"):
    """Telao com texto emissivo, atras da arquibancada do `lado` (leste|oeste), olhando o campo."""
    LB.colecao("Placar")
    sx = 1 if lado == "leste" else -1      # lado onde fica
    nx = -sx                                # normal da tela (para o campo)
    x = sx * (HL + FRENTE + fileiras * CORRER + 0.75)
    z = fileiras * SUBIR + 2.7
    escuro = LB.mat("Placar|moldura", (0.04, 0.05, 0.06), 0.4, metallic=0.6)
    tela = LB.mat("Placar|tela", (0.01, 0.015, 0.02), 0.1, verniz=1.0)
    txt = LB.mat("Placar|texto", cor, 0.3, emissao=cor, forca=8.0)
    cian = LB.mat("Placar|sub", (0.2, 0.9, 1.0), 0.3, emissao=(0.2, 0.9, 1.0), forca=5.0)
    w, h = tamanho
    LB.box("Placar moldura", (x, 0, z), (0.22, w, h), escuro, 0.04)
    LB.box("Placar tela", (x + nx * 0.115, 0, z), (0.02, w - 0.2, h - 0.2), tela, 0.01)
    for sy in (-1, 1):
        LB.rod("Placar pe", (x + sx * 0.05, sy * w * 0.38, 0), (x + sx * 0.05, sy * w * 0.38, z - h / 2), 0.07, escuro, 12)
    rz = nx * math.pi / 2
    LB.texto_3d("Placar texto", texto, (x + nx * 0.13, 0, z + 0.12), 0.40, txt, rot=(math.pi / 2, 0, rz), extrude=0.01)
    LB.texto_3d("Placar sub", sub, (x + nx * 0.13, 0, z - 0.40), 0.17, cian, rot=(math.pi / 2, 0, rz), extrude=0.008)


def criar_refletores(altura=5.0, afastamento=(HL + 3.3, HW + 2.9), cor_lampada=(1.0, 0.93, 0.75), so_norte=False):
    """so_norte=True: modela so os mastros do fundo (nao tampam a camera), mas devolve os 4 pontos de luz."""
    LB.colecao("Refletores")
    mastro = LB.mat("Ref|mastro", (0.78, 0.78, 0.75), 0.35, metallic=0.7)
    caixa = LB.mat("Ref|caixa", (0.08, 0.08, 0.1), 0.4, metallic=0.6)
    lamp = LB.mat("Ref|lampada", cor_lampada, 0.2, emissao=cor_lampada, forca=18.0)
    pos = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * afastamento[0], sy * afastamento[1]
            if so_norte and sy < 0:
                pos.append(((x, y, altura + 0.2), (0, 0, 0)))
                continue
            LB.rod("Mastro", (x, y, 0), (x, y, altura), 0.07, mastro, 12, radius2=0.045)
            LB.box("Base mastro", (x, y, 0.06), (0.3, 0.3, 0.12), mastro, 0.03)
            # painel orientado para o centro
            alvo = Vector((0, 0, 0))
            d = (alvo - Vector((x, y, altura)))
            yaw = math.atan2(d.y, d.x)
            painel = LB.box("Painel refletor", (x, y, altura + 0.18), (0.18, 1.1, 0.7), caixa, 0.03,
                            rot=(0, 0, yaw))
            for i in range(3):
                for j in range(4):
                    off = Vector((0.1, (j - 1.5) * 0.26, (i - 1) * 0.2))
                    from mathutils import Euler
                    off = Euler((0, 0, yaw)).to_matrix() @ off
                    LB.sphere("Lampada", (x + off.x, y + off.y, altura + 0.18 + off.z), (0.055, 0.055, 0.055), lamp, 10, 6)
            pos.append(((x, y, altura + 0.2), (0, 0, 0)))
    return pos


def luzes_refletores(pos, energia=9000, cor=(1.0, 0.93, 0.78)):
    """Spots reais (so faz sentido na cena noturna)."""
    for i, (p, alvo) in enumerate(pos):
        LB.spot(f"Spot {i}", p, alvo, energia, cor, angulo=75, blend=0.6)


def criar_publicidade(passo=1.25, pular_sul=None):
    """Placas LED em volta do campo (as lateras e as pontas, vazando os gols)."""
    LB.colecao("Publicidade")
    frente = [(0.08, 0.28, 0.42), (0.9, 0.58, 0.1), (0.7, 0.07, 0.1), (0.05, 0.4, 0.45), (0.15, 0.15, 0.2), (0.85, 0.85, 0.8)]
    nomes = ["FUTOS", "ARENA", "BOLA+", "CHUTE", "GOL!", "TOP", "LIGA", "CRAQUE"]
    caixa = LB.mat("Pub|caixa", (0.04, 0.05, 0.06), 0.4, metallic=0.5)
    brilho = []
    for c in frente:
        brilho.append(LB.mat(f"Pub|led{c}", c, 0.3, emissao=c, forca=2.2))
    branco = LB.mat("Pub|texto", (1, 1, 1), 0.3, emissao=(1, 1, 1), forca=3.0)
    k = 0
    for sy in (-1, 1):
        n = int((2 * HL - 0.3) / passo)
        for i in range(n):
            x = (i - (n - 1) / 2) * passo
            if pular_sul and sy == -1 and pular_sul[0] <= x <= pular_sul[1]:
                k += 1
                continue
            LB.box("Pub caixa", (x, sy * (HW + 0.5), 0.17), (passo * 0.97, 0.06, 0.34), caixa, 0.015)
            LB.box("Pub led", (x, sy * (HW + 0.5 - sy * -0.0 - sy * 0.035), 0.17), (passo * 0.9, 0.012, 0.27), brilho[k % len(brilho)], 0.004)
            LB.texto_3d("Pub texto", nomes[k % len(nomes)], (x, sy * (HW + 0.5) - sy * 0.04, 0.17), 0.12, branco,
                        rot=(math.pi / 2, 0, 0 if sy == 1 else math.pi), extrude=0.003)
            k += 1
    for sx in (-1, 1):
        for sy in (-1, 1):
            y = sy * (2.6 + 0.55)  # laterais do gol
            for off in (0, 1.25):
                yy = sy * (1.7 + off + 0.7) if False else sy * (1.45 + off + 0.6)
                LB.box("Pub caixa fundo", (sx * (HL + 0.5), yy, 0.17), (0.06, passo * 0.97, 0.34), caixa, 0.015)
                LB.box("Pub led fundo", (sx * (HL + 0.5 - sx * 0.035), yy, 0.17), (0.012, passo * 0.9, 0.27), brilho[k % len(brilho)], 0.004)
                k += 1


def variacao_a():
    LB.limpar_cena()
    criar_cobertura(("norte",), fileiras=4)
    criar_placar("CASA 0 : 0 FORA", fileiras=4)


def variacao_b():
    LB.limpar_cena()
    criar_cobertura(("norte", "sul"), fileiras=5)
    criar_refletores(altura=4.2)
    criar_publicidade()


def variacao_c():
    LB.limpar_cena()
    criar_cobertura(("norte", "sul", "leste", "oeste"), fileiras=6)
    criar_placar("FINAL 2 : 1")
    criar_refletores(altura=5.6)
    criar_publicidade()


CENAS = {"A": variacao_a, "B": variacao_b, "C": variacao_c}

if __name__ == "__main__":
    a = LB.args_cli()
    out = a[0] if a else "/tmp/cobertura.png"
    q = (a[1] if len(a) > 1 else "C").upper()
    CENAS[q]()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gramado
    gramado.montar_c()
    LB.camera_iso(ortho_scale={"A": 13.0, "B": 24.0, "C": 24.0}[q], alvo={"A": (0, 5.0, 1.2)}.get(q, (0, 0, 1.5)))
    LB.luz_estudio(fundo=((0.80, 0.86, 0.92), (0.45, 0.55, 0.62)))
    LB.render(out, 1200, 800)
