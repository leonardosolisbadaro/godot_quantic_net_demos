# Changelog

Todas as mudanças notáveis para esta demo serão documentadas neste arquivo.

## [Unreleased]

### Adicionado

- **Fase 1, Etapa 1 Concluída:** Implementação do compilador CLI [`tools/l2_build_chunk.py`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/tools/l2_build_chunk.py).
    - Auto-descoberta de caminhos da pasta do Lineage II (`maps/`, `textures/`, `systextures/`, `staticmeshes/`).
    - Painel de logs no terminal com relatório de dependências, dados de terreno e resumo de arquivos.
    - Derivação autoritativa para o Servidor: `server/heightfield.bin` (matriz linear `float32` em metros) e `server/chunk_meta.json` (bounding box e resolução).
    - Derivação otimizada para o Cliente: `client/<chunk>_visual.glb`, `client/heightmap_16bit.png`, `client/lightmap.png`, `client/textures/` e `client/terrain_recipe.json`.
    - Empacotador de máscaras em Splatmaps RGBA de 4 canais (`splatmap_0.png`, `splatmap_1.png`, `splatmap_2.png`).
    - Validação e compilação do chunk real `16_24.unr`.
