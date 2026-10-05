"""Gera exports/catalogo.html (v2) a partir dos PNGs em exports/png.

  python3 04_cenas_teste/gerar_catalogo.py
Imagens ausentes sao ignoradas (o card nao aparece), entao pode rodar com render parcial.
"""
import html
import os
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
PNG = BASE / "exports" / "png"
ANT = BASE / "exports" / "v1_antigo"
GLB = BASE / "exports" / "glb"

# nome do png, titulo, tag, descricao, referencia de codigo
SECOES = [
    ("Estádios por porte", "est", [
        ("estadio_grande", "Estádio grande + metrópole", "grande",
         "Bowl de 7 fileiras, camarote VIP, 4 coberturas, telão, torcida organizada, bilheterias, food trucks e calçadão com barracas, rodeado de torres.",
         "estadios.py :: criar_estadio('grande')"),
        ("estadio_grande_noite", "Estádio grande à noite", "grande",
         "Refletores como luzes reais, janelas acesas, postes e LED.", "criar_estadio('grande', noturno=True)"),
        ("estadio_medio", "Estádio médio + cidade", "médio",
         "Norte e oeste altos com cobertura, leste e sul baixos, placar, bilheteria, food truck e cidade de sobrados e prédios.",
         "criar_estadio('medio')"),
        ("estadio_medio_detalhe", "Estádio médio de perto", "médio", "Mesmo estádio sem a cidade.", "criar_estadio('medio', cidade=False)"),
        ("estadio_pequeno", "Estádio pequeno + bairro", "pequeno",
         "Arquibancada tubular, alambrado, 2 barracas, ambulantes e um bairro de casas com quintais.", "criar_estadio('pequeno')"),
    ]),
    ("Cidade em volta", "cid", [
        ("cidade_grande", "Metrópole", "grande", "Torres de até 18 andares, avenidas largas, parques e fontes.", "05_cidade/cidade.py :: criar_cidade('grande')"),
        ("cidade_grande_noite", "Metrópole à noite", "grande", "Janelas acesas (emissão) e postes de luz.", "criar_cidade('grande', noturno=True)"),
        ("cidade_media", "Cidade média", "médio", "Sobrados, comércio e prédios de 4 a 6 andares, praças e carros.", "criar_cidade('medio')"),
        ("cidade_pequena", "Bairro", "pequeno", "Casas de telhado, quintais com árvores e ruas tranquilas.", "criar_cidade('pequeno')"),
    ]),
    ("Vendedores e comércio", "vend", [
        ("vendedores_A", "Vendedores ambulantes", "novo", "Lanche na bandeja, bebidas no isopor e segurança de colete.", "03_props/vendedores.py :: criar_vendedor(tipo)"),
        ("vendedores_carrinhos", "Carrinhos de pipoca e sorvete", "novo", "Toldo listrado e guarda-sol facetado.", "vendedores.py :: criar_carrinho(tipo)"),
        ("barracas", "Barracas do entorno", "novo", "Lanche, bebidas, loja e espeto, com vendedor atrás do balcão.", "03_props/comercio.py :: barraca_com_vendedor(tipo)"),
        ("food_truck", "Food truck", "novo", "Janela de atendimento, toldo e luzes.", "comercio.py :: criar_food_truck()"),
        ("bilheteria", "Bilheteria e catracas", "novo", "3 guichês, portal e 5 catracas.", "comercio.py :: criar_bilheteria()"),
    ]),
    ("Estádio", "estadio", [
        ("gramado_C", "Gramado Premium", "C · inovação",
         "Xadrez híbrido procedural, marcação completa (áreas, arcos, marcas, escanteios), borda LED e base teal.",
         "01_estadio/gramado.py :: variacao_c_premium()"),
        ("gramado_B", "Gramado Municipal", "B · média",
         "Listras de corte procedurais, calçada de concreto e alambrado.", "gramado.py :: variacao_b_municipal()"),
        ("gramado_A", "Campo de várzea", "A · simples",
         "Terra batida, giz irregular, manchas nas áreas e cerca de estacas de madeira.", "gramado.py :: variacao_a_varzea()"),
        ("arquibancada_C", "Arquibancada Bowl + VIP", "C · inovação",
         "4 lados, 6 fileiras, mosaico teal/ouro, ~1.000 torcedores instanciados em um único objeto, camarote de vidro.",
         "arquibancada_modular.py :: criar_arquibancada(lados=4, fileiras=6)"),
        ("arquibancada_E", "Setor de torcida organizada", "novo",
         "Cadeiras em listras, bandeiras nos corredores e ambulantes de lanche e bebida subindo as escadas.",
         "criar_arquibancada(estilo='listras', bandeiras=True, vendedores=8)"),
        ("arquibancada_D", "Arquibancada tubular de aço", "novo",
         "Estrutura de tubos de aço, tábuas de madeira e xadrez azul e vermelho: o estádio pequeno.",
         "criar_arquibancada(tubular=True, estilo='xadrez')"),
        ("arquibancada_F", "Arena moderna em degradê", "novo",
         "3 lados sem muro, cor por fileira (escuro embaixo, claro no topo).", "criar_arquibancada(estilo='degrade', muro_fundo=False)"),
        ("arquibancada_B", "Arquibancada lateral dupla", "B · média",
         "2 lados, 4 fileiras, cadeiras em mosaico e parapeito com vidro.", "criar_arquibancada(lados=('norte','sul'))"),
        ("arquibancada_A", "Curva de várzea", "A · simples",
         "1 lado, 2 degraus, torcida em pé sem cadeiras.", "criar_arquibancada(fileiras=2, com_cadeiras=False)"),
        ("cobertura_C", "Cobertura arena + telão + refletores", "C · inovação",
         "Telhado em balanço com tirantes, LED no beiral, telão emissivo, mastros com 12 lâmpadas, placas LED.",
         "cobertura_placar.py :: criar_cobertura / criar_placar / criar_refletores"),
        ("cobertura_B", "Cobertura dupla", "B · média", "2 coberturas, refletores e publicidade.", "variacao_b()"),
        ("cobertura_A", "Cobertura simples + placar", "A · simples", "1 cobertura norte e placar.", "variacao_a()"),
    ]),
    ("Personagens", "pers", [
        ("elenco_poses", "Elenco: 6 poses × 6 visuais", "novo",
         "Parado, correndo, chutando, comemorando, lamentando e sentado. Cabelos: curto, afro, moicano, longo, coque, careca.",
         "02_personagens/humano.py :: POSES + criar_humano()"),
        ("jogador_C", "Estrela 10", "C · inovação",
         "Capitão com braçadeira, moicano, chuteira vermelha, número nas costas e no peito.", "jogador.py :: variacao_c()"),
        ("jogador_B", "Jogador correndo", "B · média", "Corrida com inclinação do tronco e braços opostos.", "variacao_b()"),
        ("jogador_A", "Jogador parado", "A · simples", "Kit simples, careca, pose neutra.", "variacao_a()"),
        ("goleiro_B", "Goleiro neon em mergulho", "B · média", "Luvas GG, pose de voo (roll + elevação).", "goleiro_arbitro.py :: criar_goleiro(pose='mergulho')"),
        ("goleiro_A", "Goleiro clássico", "A · simples", "Pose de defesa, luvas e punhos.", "criar_goleiro(pose='defesa')"),
        ("arbitro_tecnico", "Arbitragem e técnico", "C · inovação",
         "Árbitro com apito, árbitro com cartão vermelho e técnico de terno e gravata.", "humano.py :: arbitro() / tecnico()"),
    ]),
    ("Props", "props", [
        ("bola_trave_C", "Bola neon + trave premium LED", "C · inovação",
         "Bola em icosaedro truncado real (pentágonos + costuras), rede de malha com folga, postes e base emissivos.",
         "03_props/bola_trave.py :: criar_bola(estilo='neon') + criar_trave(premium=True)"),
        ("bola_trave_B", "Bola colorida + rede densa", "B · média", "Rede 18×11 com fio fino.", "variacao_b()"),
        ("bola_trave_A", "Bola clássica + trave simples", "A · simples", "Rede 10×6.", "variacao_a()"),
        ("extras_trofeu", "Troféu de ouro no pódio", "novo",
         "Taça por revolução de perfil, alças em arco, base de mogno, confete instanciado.", "extras.py :: criar_trofeu() + confete()"),
        ("extras_banco", "Banco de reservas", "novo", "Abrigo com vidro, assentos e reservas sentados.", "extras.py :: criar_banco()"),
        ("extras_treino", "Kit de treino", "novo", "Cones com faixa, barreiras, saco de bolas, bandeira e bola.", "extras.py :: variacao_treino()"),
    ]),
]

ANTES_DEPOIS = [
    ("cena_inovacao", "cena_dia", "Cena final"),
    ("jogador_C", "jogador_C", "Jogador"),
    ("bola_trave_C", "bola_trave_C", "Bola + trave"),
    ("arquibancada_C", "arquibancada_C", "Arquibancada"),
]

MUDANCAS = [
    ("Bug de posicionamento", "As peças eram criadas em coordenadas de mundo e depois parenteadas a um root já deslocado: o offset era somado duas vezes e o goleiro caía fora do campo. Agora tudo nasce em coordenadas locais e cada personagem vira uma malha única."),
    ("Personagens articulados", "Esqueleto com cinemática direta (quadril, joelho, ombro, cotovelo) gera 11 poses reais, com auto-aterramento dos pés. Olhos com brilho, sobrancelhas, 6 penteados, 5 tons de pele, número nas costas e no peito."),
    ("Materiais PBR e procedurais", "Metal, verniz, vidro, emissão (neon/LED/telão), tecido com sheen; gramado com padrão de corte e fibra; concreto com ruído e bump."),
    ("Iluminação e render", "Sol suave + céu + rim light, sombras de contato e raytracing do EEVEE, tonemap AgX. Cena noturna com refletores como spots reais. Modo Cycles opcional."),
    ("Torcida e arquibancada de verdade", "Geometria em lote (1 objeto, 9 materiais): cerca de 1.000 torcedores. A criação caiu de 139 s para 0,4 s trocando bmesh.ops por geometria bruta."),
    ("Estrutura de projeto", "Coleções por componente, API compatível com a v1, exportação GLB, pipeline único (render_tudo.py) e este catálogo gerado por script."),
]

CSS = """
:root{--bg:#06191a;--bg2:#0b2a2c;--card:#0f3033;--line:#1d5256;--tx:#e7f3f1;--mut:#8fb5b2;--ouro:#f2b705;--ciano:#33e0d0}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#0f4a4c 0,transparent 60%),var(--bg);color:var(--tx);font:15px/1.55 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
a{color:var(--ciano)}
.wrap{max-width:1280px;margin:0 auto;padding:0 20px}
header.hero{padding:40px 0 20px}
.eyebrow{color:var(--ouro);font-weight:700;letter-spacing:.14em;text-transform:uppercase;font-size:12px}
h1{font-size:clamp(28px,4.4vw,52px);line-height:1.05;margin:8px 0 12px;letter-spacing:-.02em}
.lead{max-width:760px;color:var(--mut);font-size:17px}
.heroimg{margin:26px 0 8px;border-radius:18px;overflow:hidden;border:1px solid var(--line);box-shadow:0 30px 80px #0008}
.heroimg img{display:block;width:100%;height:auto;cursor:zoom-in}
.chips{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}
.chip{background:var(--bg2);border:1px solid var(--line);border-radius:999px;padding:6px 14px;font-size:13px;color:var(--mut)}
.chip b{color:var(--tx)}
section{padding:34px 0}
h2{font-size:26px;margin:0 0 4px}.sub{color:var(--mut);margin:0 0 20px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;display:flex;flex-direction:column}
.card.big{grid-column:span 2}
@media(max-width:820px){.card.big{grid-column:auto}}
.card img{display:block;width:100%;aspect-ratio:4/3;object-fit:cover;background:#0a2224;cursor:zoom-in}
.card.big img{aspect-ratio:16/9}
.card .b{padding:14px 16px 16px}
.tag{display:inline-block;font-size:11px;font-weight:800;border-radius:99px;padding:2px 10px;margin-bottom:8px;background:var(--ciano);color:#012}
.tag.n{background:var(--ouro)}
.card h3{margin:0 0 4px;font-size:17px}.card p{margin:0 0 10px;color:var(--mut);font-size:13.5px}
code{font:12px ui-monospace,Menlo,Consolas,monospace;background:#06191a;border:1px solid var(--line);border-radius:6px;padding:3px 7px;color:#bfe9e3;display:inline-block;word-break:break-all}
.ba{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:18px}
@media(max-width:620px){.ba{grid-template-columns:1fr}}
.pair{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px}
.pair h4{margin:0 0 8px}.pair .two{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.pair figure{margin:0;position:relative}.pair img{width:100%;display:block;border-radius:8px;aspect-ratio:4/3;object-fit:cover;background:#fff;cursor:zoom-in}
.pair figcaption{position:absolute;left:8px;top:8px;background:#000a;border-radius:99px;padding:2px 10px;font-size:11px;font-weight:700}
.pair figcaption.n{background:var(--ouro);color:#201700}
ul.mud{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:14px;list-style:none;padding:0;margin:0}
ul.mud li{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px}
ul.mud b{display:block;color:var(--ouro);margin-bottom:4px}ul.mud span{color:var(--mut);font-size:13.5px}
pre{background:#041213;border:1px solid var(--line);border-radius:10px;padding:14px;overflow:auto;color:#bfe9e3;font-size:12.5px}
footer{padding:30px 0 60px;color:var(--mut);font-size:13px}
#lb{position:fixed;inset:0;background:#000d;display:none;align-items:center;justify-content:center;z-index:9;cursor:zoom-out}
#lb img{max-width:96vw;max-height:94vh;border-radius:10px}
"""

JS = """
const lb=document.getElementById('lb'),li=lb.querySelector('img');
document.querySelectorAll('img[data-z]').forEach(i=>i.addEventListener('click',()=>{li.src=i.src;lb.style.display='flex'}));
lb.addEventListener('click',()=>lb.style.display='none');
addEventListener('keydown',e=>{if(e.key==='Escape')lb.style.display='none'});
"""


def existe(nome):
    return (PNG / f"{nome}.png").exists()


def card(nome, titulo, tag, desc, ref, big=False):
    glb = GLB / f"{nome}.glb"
    extra = f' · <a href="glb/{nome}.glb">GLB</a>' if glb.exists() else ""
    t = "tag n" if tag == "novo" else "tag"
    return (f'<article class="card{" big" if big else ""}"><img data-z loading="lazy" src="png/{nome}.png" alt="{html.escape(titulo)}">'
            f'<div class="b"><span class="{t}">{html.escape(tag)}</span><h3>{html.escape(titulo)}</h3>'
            f'<p>{html.escape(desc)}</p><code>{html.escape(ref)}</code>{extra}</div></article>')


def main():
    n_cards = sum(1 for _, _, itens in SECOES for i in itens if existe(i[0]))
    hero = "cena_noite" if existe("cena_noite") else "cena_dia"
    out = [f"<!doctype html><html lang='pt-BR'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
           "<title>Componentes Blender v2 — FutOS Manager</title>", f"<style>{CSS}</style></head><body><div class='wrap'>"]
    out.append("<header class='hero'><div class='eyebrow'>FutOS Manager · Componente Teste Inovação · v2</div>"
               "<h1>Estádio, elenco e props<br>reconstruídos do zero</h1>"
               "<p class='lead'>Todos os componentes foram reescritos: personagens articulados com poses, torcida instanciada, materiais PBR, "
               "iluminação de estúdio e render com sombras reais. Cada card mostra a variação, o que ela traz e onde está o código.</p>")
    out.append(f"<div class='chips'><span class='chip'><b>{n_cards}</b> componentes renderizados</span><span class='chip'><b>3</b> portes de estádio</span><span class='chip'><b>11</b> poses</span>"
               "<span class='chip'><b>~1.000</b> torcedores</span><span class='chip'><b>3</b> cidades</span>"
               "<span class='chip'>Blender <b>4.2.1</b> · EEVEE</span></div>")
    if existe(hero):
        out.append(f"<div class='heroimg'><img data-z src='png/{hero}.png' alt='Cena final'></div>")
    out.append("</header>")
    # cena
    cenas = [(n, t, d) for n, t, d in [("cena_dia", "Cena final — dia", "Lance de jogo completo: o 10 chuta, o goleiro mergulha, zagueiros correm."),
                                        ("cena_noite", "Cena final — noite", "Os 4 refletores viram spots reais; LED, telão e bola neon ganham destaque."),
                                        ("cena_tv", "Câmera de TV", "Perspectiva de transmissão a partir do lado do banco."),
                                        ("cena_zoom", "Zoom na área", "Detalhe dos personagens, rede e placas de publicidade.")] if existe(n)]
    if cenas:
        out.append("<section><h2>Cena de estádio</h2><p class='sub'>Todos os componentes juntos em <code>04_cenas_teste/cena_inovacao.py</code>.</p><div class='grid'>")
        for n, t, d in cenas:
            out.append(card(n, t, "cena", d, f"cena_inovacao.py -- --cam {'iso' if n in ('cena_dia', 'cena_noite') else n.split('_')[1]}" + (" --noturno" if n == "cena_noite" else ""), big=n in ("cena_dia", "cena_noite")))
        out.append("</div></section>")
    # antes/depois
    pares = [(a, d, t) for a, d, t in ANTES_DEPOIS if (ANT / f"{a}.png").exists() and existe(d)]
    if pares:
        out.append("<section><h2>Antes × depois</h2><p class='sub'>Mesma ideia, v1 (esquerda) e v2 (direita).</p><div class='ba'>")
        for a, d, t in pares:
            out.append(f"<div class='pair'><h4>{t}</h4><div class='two'><figure><img data-z src='v1_antigo/{a}.png'><figcaption>v1</figcaption></figure>"
                       f"<figure><img data-z src='png/{d}.png'><figcaption class='n'>v2</figcaption></figure></div></div>")
        out.append("</div></section>")
    for titulo, _, itens in SECOES:
        itens = [i for i in itens if existe(i[0])]
        if not itens:
            continue
        out.append(f"<section><h2>{titulo}</h2><p class='sub'>{len(itens)} componentes</p><div class='grid'>")
        for i in itens:
            out.append(card(*i, big=(i is itens[0] and titulo not in ("Props", "Vendedores e comércio"))))
        out.append("</div></section>")
    out.append("<section><h2>O que mudou</h2><p class='sub'>Resumo técnico.</p><ul class='mud'>")
    for t, d in MUDANCAS:
        out.append(f"<li><b>{html.escape(t)}</b><span>{html.escape(d)}</span></li>")
    out.append("</ul></section>")
    out.append("<section><h2>Como re-renderizar</h2><pre>cd apps/manager-futebol/Resources/Blender/COMPONENTE_TESTE_INOVACAO\n"
               "python3 04_cenas_teste/render_tudo.py            # todos os PNGs (usa o Blender em $BLENDER)\n"
               "python3 04_cenas_teste/render_tudo.py --so cena  # so a cena de estadio\n"
               "blender -b --python 04_cenas_teste/cena_inovacao.py -- saida.png --noturno --cam tv\n"
               "python3 04_cenas_teste/gerar_catalogo.py         # reconstroi este catalogo</pre></section>")
    out.append("<footer>Render real Blender 4.2.1 (EEVEE, raytracing, AgX). Clique em qualquer imagem para ampliar.</footer></div>")
    out.append("<div id='lb'><img alt=''></div>")
    out.append(f"<script>{JS}</script></body></html>")
    (BASE / "exports" / "catalogo.html").write_text("\n".join(out), encoding="utf-8")
    print("catalogo.html gerado com", n_cards, "componentes")


if __name__ == "__main__":
    main()
