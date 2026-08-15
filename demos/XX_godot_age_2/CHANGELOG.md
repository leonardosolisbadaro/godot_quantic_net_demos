# Changelog

Todas as mudanças notáveis para esta demo serão documentadas neste arquivo.

## [Unreleased]

### Adicionado

- **Fase 1, Etapa 3 Concluída:** Shader de Terreno Multi-Textura e Colisão Física no Godot 4.7.
    - Implementação do shader [`l2_terrain.gdshader`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/l2_terrain.gdshader) consumindo Splatmaps RGBA (até 10 camadas de textura simultâneas) e Lightmap macro do Lineage II.
    - Implementação do caso de uso [`BuildChunkCollisionUseCase`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/use_cases/build_chunk_collision_use_case.gd) para geração matemática de `HeightMapShape3D`.
    - Implementação do nó 3D de chunk [`L2TerrainChunkNode`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/l2_terrain_chunk_node.gd) e do gerenciador de streaming [`ChunkManager`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/chunk_manager.gd).
    - Integração de carregamento e navegação do cluster 2x2 (`16_24`, `16_25`, `17_24`, `17_25`) no [`main.gd`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/main.gd).
    - Criação de suíte de testes unitários com GUT (6 testes passando).
- **Fase 1, Etapa 2 Concluída:** Implementação do script orquestrador de build PowerShell [`build_maps.ps1`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/build_maps.ps1).
    - Suporte a compilação por chunk individual (`-map "16_24"`), listas em lote (`-maps "16_25, 17_24, 17_25"`) e varredura total (`-all`).
    - Validação e compilação em lote do cluster 2x2 de chunks adjacentes com 100% de sucesso.
- **Fase 1, Etapa 1 Concluída:** Implementação do compilador CLI [`tools/l2_build_chunk.py`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/tools/l2_build_chunk.py).
    - Auto-descoberta de caminhos da pasta do Lineage II (`maps/`, `textures/`, `systextures/`, `staticmeshes/`).
    - Painel de logs no terminal com relatório de dependências, dados de terreno e resumo de arquivos.
    - Derivação autoritativa para o Servidor e Cliente com empacotamento de Splatmaps RGBA.
