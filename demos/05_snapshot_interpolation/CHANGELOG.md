# Changelog

Todas as mudanças notáveis para esta demo serão documentadas neste arquivo.

## [1.0.0] - Implementação de Snapshot Interpolation

### Added
- `SnapshotInterpolator`: Lógica pura de lerping (0.0 a 1.0) isolada no domínio.
- `InterpolateRemoteEntitiesUseCase`: Orquestra chamadas diretas ao C++ (`remote_state`) via Gateway (QuanticNet) delegando o lerping ao Domínio.
- Suavização assíncrona no `_process` em `main.gd` substituindo as interrupções duras (snapping) provenientes de sinais de rede.

### Removed
- Todos os testes unitários genéricos de demos anteriores foram removidos. Foram mantidos unicamente novos testes estritamente focados na arquitetura de Interpolação para coesão absoluta.