# COMPONENTE TESTE INOVACAO

Pasta isolada para testar ideias **sem mexer** nos `stadium_*.py` / `match_scene_*.py` originais.

## Estrutura

- `00_core/lib_base.py` — `mat, box, sphere, rod, stroke, texto_3d, camera_iso, luz_estudio, render_transparente, limpar_cena`
- `01_estadio/` — `gramado.py (A/B/C)`, `arquibancada_modular.py (A/B/C)`, `cobertura_placar.py (A/B/C)`
- `02_personagens/` — `jogador.py (simples/rig/estrela)`, `goleiro_arbitro.py (classico/neon/arbitro+tecnico)`
- `03_props/` — `bola_trave.py`, `extras.py (bandeira, banco, cones, trofeu)`
- `04_cenas_teste/` — `cena_inovacao.py`, `catalogo_teste.py`
- `exports/png|glb|blends/` — saidas

## Variações criadas (12+)

| Categoria | A simples | B media | C inovacao |
|---|---|---|---|
| Gramado | varzea terra | municipal listrado | premium + borda LED |
| Arquibancada | 1 lado em pe | 2 lados cadeiras | bowl 4 lados + VIP |
| Cobertura | 1 + placar | 2 + refletores + pubs | arena 4 + telão + LED |
| Jogador | basico | rig+numero | estrela faixa+bota vermelha |
| Goleiro | amarelo | rosa luvas GG | arbitro+tecnico |
| Bola/Trave | simples | rede densa | neon noturna + base LED |
| Extras | treino (cones+banco) | trofeu | — |
| Cena final | `cena_inovacao.py` junta tudo | `--noturno` testa luz noite | — |

## Como testar qualidade (precisa Blender)

```bash
cd "apps/manager-futebol/Resources/Blender/COMPONENTE_TESTE_INOVACAO"
blender --background --python 04_cenas_teste/cena_inovacao.py -- exports/png/cena_inovacao.png
blender --background --python 04_cenas_teste/cena_inovacao.py -- exports/png/cena_noturna.png --noturno
python3 04_cenas_teste/catalogo_teste.py
```

Sem Blender instalado nesta maquina: os scripts foram validados com `py_compile`, prontos para rodar onde houver Blender.
