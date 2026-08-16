# TODO (XX_godot_age_2 — Godotage II / Lineage II MMO)

Roadmap e tarefas específicas para a infraestrutura e implementação desta demo definitiva.

## Fase 1: Pipeline de Build e Conversão (".unr to Godotage II")

### Etapa 1: Compilador de Chunks CLI (`tools/l2_build_chunk.py`)

- [x] Implementar auto-descoberta inteligente da raiz do Lineage II (`--l2-root` com fallback automático pelo caminho do `.unr`).
- [x] Implementar painel de logs estruturados e legíveis no terminal (cabeçalho UE2, pacotes dependentes encontrados vs ausentes, tabela de camadas, dimensões e altitudes em metros).
- [x] Implementar gerador de artefatos do Servidor:
    - [x] `server/heightfield.bin`: matriz linear binária em `float32` Little-Endian normalizada para metros no eixo Y.
    - [x] `server/chunk_meta.json`: metadados com bounding box mundial, resolução de grade e fatores de escala.
- [x] Implementar gerador de artefatos do Cliente:
    - [x] `client/<chunk>_visual.glb`: malha 3D limpa em GLB binário com normais e coordenadas UV.
    - [x] `client/heightmap_16bit.png`: heightmap puro 16-bit em escala de cinza.
    - [x] `client/lightmap.png`: lightmap de iluminação pré-calculada do L2 (`_C`).
    - [x] `client/textures/`: texturas difusas extraídas de pacotes `.utx` em PNG.
    - [x] `client/terrain_recipe.json`: receita de materiais, escalas UV e metadados.
- [x] Implementar empacotador de máscaras em Splatmaps RGBA (`splatmap_0.png`, `splatmap_1.png`, `splatmap_2.png`) com 4 camadas por textura.
- [x] Testar e validar a compilação do chunk real `16_24.unr` gerando a estrutura de pastas completa.

### Etapa 2: Orquestrador de Build PowerShell (`build_maps.ps1`)

- [x] Criar script PowerShell para automatizar a compilação de chunks individuais ou em lote diretamente da pasta do Lineage II para a pasta de assets da demo.
- [x] Validar compilação em lote do cluster 2x2 de chunks adjacentes (`16_25`, `17_24`, `17_25`).

### Etapa 3: Shader e Terreno no Cliente Godot 4.7

- [x] Criar Shader multi-textura no Godot 4.7 (`src/infrastructure/l2_terrain.gdshader`) consumindo os Splatmaps RGBA e o Lightmap.
- [x] Configurar streaming e colisão local com `ConcavePolygonShape3D` contínua eliminando frestas de fronteira (`ChunkManager`, `L2TerrainChunkNode`).
- [x] Validar carregamento contínuo em memória e renderização limpa do cluster 2x2.

### Etapa 4: Validação de Altura e Física no Servidor QuanticNet

- [x] Criação da entidade de domínio puro `HeightfieldSampler` com interpolação bilinear $O(1)$ sobre o buffer `server/heightfield.bin`.
- [x] Criação do caso de uso `ValidatePlayerMovementUseCase` e `ServerMovementValidator` (anti-cheat autoritativo contra fly-hack, speed-hack e queda livre).
- [x] Criação do `ServerWorldManager` e `QuanticNetServerAdapter` dedicados para o servidor headless ($< 5\text{ MB}$ de RAM para o cluster).
- [x] Implementação do avatar em terceira pessoa `PlayerAvatar` (`CharacterBody3D`, `SpringArm3D`, inércia de queda, câmera orbital e sincronização QuanticNet).
- [x] Implementação de visualizadores de depuração de colisão (`F1` para cápsula do avatar e `F2` para wireframe do terreno).
- [x] Testes unitários com GUT (AAA) cobrindo interpolação de terreno e regras de movimentação autoritativa (12 testes passando).

### [CONGELADO PARA O FUTURO] Backlog de Refinamento Visual e Recursos Avançados

- [ ] Investigar a causa raiz do padrão de repetição/alinhamento residual em máscaras específicas de terreno (investigar formatos DXT3/P8 no UE2).
- [ ] Implementar shader e malha de água reflexiva (`FluidSurfaceActor` / Ocean Plane) para cobrir chunks marítimos como `17_24`, eliminando a necessidade de textura de fundo exposta.
- [ ] Adicionar blended borders / stitching visual nos limites entre chunks vizinhos.
- [ ] Suporte CLI `--offline` no Cliente: permitir rodar e inspecionar o mundo 3D sem necessidade de conexão ou subida de servidor em segundo plano (PawnViewer integrado).
