# TODO

Roadmap e tarefas especificas para esta implementacao.

## Roadmap

- [x] **Domínio:** Criar `EntityProfileFactory` isolando regras arbitrárias de QoS da rede (TDD-AAA).
- [x] **Use Cases:** Criar `SpawnAuthoritativeEntityUseCase` e `DespawnAuthoritativeEntityUseCase` repassando registros ao Gateway C++ (TDD-AAA).
- [x] **Adapter:** Implementar o `EntityRegistryAdapter` recebendo eventos assíncronos e os decodificando para UI limpa (TDD-AAA).
- [x] **Presentation:** Construir malhas e topologia (Mundo 3D) delegando visualização para os eventos limpos e previsão visual seca (Zero-RPC) nos clientes e servidor.
