# Changelog (Infraestrutura)

Este documento registra apenas a concepção arquitetural inicial deste repositório matriz. **Ele não será mais mantido para atualizações cotidianas.**

## [1.1.0] - Implementação de Demos Base & Script Avançado

### Added

- Demo `01_handshake_state_machine`: Protocolo de Handshake e ciclo de vida sob Clean Architecture.
- Demo `02_network_metrics_clock_sync`: Telemetria, RTT, Loss, e cálculos estatísticos (1% Low).
- Demo `03_entity_registry_authoritative_spawning`: Registro Autoritativo, Perfis de Rede (QoS) e Client-Side Rendering local.
- Demo `04_client_side_prediction_kinematics`: Client-Side Prediction (CSP) puro (Responsividade zero-lag).
- Demo `05_snapshot_interpolation`: Interpolação de malhas visuais para combater jitter remoto.
- Demo `06_server_authority_snapback`: Validação de autoridade e Snapback nativo do plugin.
- Demo `07_server_reconciliation`: Reconciliação do Servidor via Client Replay (Re-simulação da fila de predição).
- Demo `08_server_side_input_validation`: Validador Autoritativo de Inputs com Tolerância Elástica a Jitter (Jitter Buffer Simulado).
- O script `setup_demos.ps1` agora aceita argumentos com nomes específicos para instanciar demos baseados em template parametrizado.

- Inicialização do ambiente das demos com dependência estrita do plugin autoritativo.
- Submódulo git de infraestrutura (`addons/quantic_net`).
- Scripts mágicos de `.vscode/` para reconhecimento em tempo real da "aba ativa" (Active File) para injetar o contexto de comandos do Godot LSP e GUT.
- Script genérico em PowerShell (`setup_demos.ps1`) para automatização e vinculação (*Directory Junctions*) sem repetição de código.
