# COMPONENTE TESTE INOVACAO (v2)

Pasta isolada para testar ideias **sem mexer** nos `stadium_*.py` / `match_scene_*.py` originais.
Veja o resultado em `exports/catalogo.html`.

## Estrutura

- `00_core/lib_base.py` — materiais PBR/procedurais (`mat`, `mat_ruido`, `mat_gramado`), primitivas (`box`, `sphere`, `rod`, `membro`, `fita`, `stroke`, `texto_3d`), `Lote` (milhares de pecas em 1 objeto), `fundir`, luzes (`luz_estudio`, `spot`), cameras, `render` (EEVEE/Cycles) e `exportar_glb`.
- `01_estadio/` — `gramado.py`, `arquibancada_modular.py` (com torcida e camarote VIP), `cobertura_placar.py` (cobertura, telao, refletores, publicidade LED)
- `02_personagens/` — `humano.py` (esqueleto + 11 poses + papeis), `jogador.py`, `goleiro_arbitro.py`
- `03_props/` — `bola_trave.py` (bola icosaedro truncado + rede de malha), `extras.py` (bandeira, banco, cones, barreira, saco de bolas, trofeu, confete)
- `04_cenas_teste/` — `cena_inovacao.py` (estadio completo, dia/noite, varias cameras), `render_tudo.py`, `gerar_catalogo.py`
- `exports/png|glb` — saidas; `exports/v1_antigo` — renders da v1 para comparacao

## Convencoes

- Campo 12 x 7.6 (`LB.L`, `LB.W`); personagem ~1.05 de altura, olha para +Y; `yaw` gira em Z.
- Pecas sao criadas em coordenadas LOCAIS (a v1 somava o offset duas vezes).
- Cada componente tem `variacao_a/b/c()` e uma API reutilizavel (`criar_*`).
- Todo script aceita `-- saida.png [variacao]`; passe `--so-glb` para exportar GLB sem renderizar.

## Renderizar

```bash
export BLENDER=/caminho/blender      # testado com 4.2.1
python3 04_cenas_teste/render_tudo.py            # todos os PNGs
python3 04_cenas_teste/render_tudo.py --so cena  # so a cena
blender -b --python 04_cenas_teste/cena_inovacao.py -- out.png --noturno --cam tv [--cycles] [--rapido]
python3 04_cenas_teste/gerar_catalogo.py         # reconstroi o catalogo
```

Cameras da cena: `iso`, `tv`, `zoom`, `campo`, `topo`, `gol`.
