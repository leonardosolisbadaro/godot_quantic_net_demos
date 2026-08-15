# Changelog

Todas as mudanças notáveis para esta demo serão documentadas neste arquivo.

## [Unreleased]

### Adicionado

- **Fase 1, Etapa 4 Concluída:** Validação de Altura e Física Autoritativa no Servidor QuanticNet e Controles de Terceira Pessoa.
    - Implementação da entidade de domínio puro [`HeightfieldSampler`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/domain/heightfield_sampler.gd) com interpolação bilinear $O(1)$ sobre `heightfield.bin`.
    - Implementação do validador de domínio [`ServerMovementValidator`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/domain/server_movement_validator.gd) e do caso de uso [`ValidatePlayerMovementUseCase`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/use_cases/validate_player_movement_use_case.gd) para prevenção de speed-hack, fly-hack e ground clamping.
    - Implementação do gerenciador autoritativo [`ServerWorldManager`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/server_world_manager.gd) e do adaptador [`QuanticNetServerAdapter`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/adapters/quantic_net_server_adapter.gd) operando em modo headless puro ($< 5\text{ MB}$ de RAM para o cluster).
    - Implementação do avatar em terceira pessoa [`PlayerAvatar`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/player_avatar.gd) com `CharacterBody3D`, `SpringArm3D`, mouse orbital (Right Click hold), zoom na roda do mouse, WASD relativo ao ângulo de visão da câmera e submissão contínua de estados ao plugin QuanticNet.
    - Criação de suíte de testes unitários TDD (12 testes passando com 39 asserções).
- **Fase 1, Etapa 3 Concluída:** Shader de Terreno Multi-Textura e Colisão Física no Godot 4.7.
    - Implementação do shader [`l2_terrain.gdshader`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/l2_terrain.gdshader) consumindo Splatmaps RGBA (até 10 camadas de textura simultâneas) e Lightmap macro do Lineage II.
    - Implementação do caso de uso [`BuildChunkCollisionUseCase`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/use_cases/build_chunk_collision_use_case.gd) para geração matemática de `HeightMapShape3D`.
    - Implementação do nó 3D de chunk [`L2TerrainChunkNode`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/l2_terrain_chunk_node.gd) e do gerenciador de streaming [`ChunkManager`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/src/infrastructure/chunk_manager.gd).
- **Fase 1, Etapa 2 Concluída:** Implementação do script orquestrador de build PowerShell [`build_maps.ps1`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/build_maps.ps1).
- **Fase 1, Etapa 1 Concluída:** Implementação do compilador CLI [`tools/l2_build_chunk.py`](file:///c:/Users/LEONARDO/Documents/godot_quantic_net_demos/demos/XX_godot_age_2/tools/l2_build_chunk.py).
