# TODO

Roadmap e tarefas específicas para esta implementação.

- [x] Extração de `SnapshotInterpolator` para a camada de Domínio Pura.
- [x] Extração de `InterpolateRemoteEntitiesUseCase` isolado para desacoplar a engine da busca por dados da rede.
- [x] Conexão do `_process` destravado à interpolação visual do cliente/server (Eliminação do Snapping do _physics_process/sinais).
- [x] Testes robustos seguindo metodologia AAA focados no lerp dinâmico (7 passed).
