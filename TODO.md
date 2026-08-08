# TODO (Infraestrutura do Repositório)

Este documento controlou exclusivamente a criação da infraestrutura do "condomínio" (o monorepo das demos). **Ele não será mais utilizado daqui para frente**, pois as metas de mecânicas de cada demo serão isoladas ou guiadas apenas pela IA.

## Fundações (Concluído)

- [x] Configuração inicial do repositório Git.
- [x] Injeção do `quantic_net` via Git Submodule.
- [x] Redação do contrato arquitetural `GEMINI.md`.
- [x] Desenvolvimento do `setup_demos.ps1` (gerador de templates e Junctions no Windows).
- [x] Configuração da bridge do VSCode (`tasks.json` + `run_gut.ps1` + `toggle_active_demo.ps1`).
- [x] Teste de fogo concluído com sucesso (`01_handshake_state_machine`).

## Roadmap de Laboratórios (QuanticNet Demos)

As etapas a seguir mapeiam a evolução do aprendizado em rede, partindo do básico até um ecossistema completo. Cada etapa será sua própria demo limpa.

- [x] **01_handshake_state_machine:** Handshake & State Machine (Ciclo de vida e conexão básica isolada da Engine)
- [x] **02_network_metrics_clock_sync:** Network Metrics & Clock Sync (Domínio de telemetria, RTT, Jitter, Loss e 1% Low)
- [x] **03_entity_registry_authoritative_spawning:** Entity Registry & Profiles (Sincronização de peers, instanciamento autoritativo e perfis dinâmicos de Tick Rate / Prioridade via `QNEntityProfile`)
- [x] **04_client_side_prediction_kinematics:** Client-Side Prediction (CSP) & Kinematics (Responsividade instantânea e movimentação sem lag local)
- [x] **05_snapshot_interpolation:** Snapshot Interpolation (O fim do Jitter visual via Lerping fluido)
- [ ] **06_server_authority_snapback:** Server Authority & Snapback (Validação Anti-Speedhack, limites matemáticos de mundo e reconciliação forçada)
- [ ] **07_spatial_partitioning_culling:** Spatial Partitioning & Culling Rings (Grid Culling C++, otimização de banda e debug visual de AoI)
- [ ] **08_zero_rpc_event_broadcasting:** Zero-RPC Event Broadcasting (Input states customizados para ações rápidas: Hitscan lasers e instanciamento de projéteis físicos)
- [ ] **09_micro_mmo:** O Micro-MMO (Refatoração definitiva unindo todos os conceitos em uma arquitetura limpa)
