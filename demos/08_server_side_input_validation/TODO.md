# TODO

Roadmap e tarefas concluídas para esta implementação (Validação de Input Server-Side):

## Funcionalidades Concluídas

- [x] Injeção de `qn_input_validator.gd` sobrescrevendo o validador padrão da engine QuanticNet.
- [x] Implementação de Tolerância Elástica (Jitter Tolerance) mitigando falsos-positivos causados por flutuação de rede (NETEM).
- [x] Implementação de Step Capping, barrando cheaters e teletransportes injetados (Spacebar speedhack).
- [x] Restauração da *Snapshot Interpolation* (Lerp) para remover stuttering visual de entidades remotas sob conexões caóticas.
