# Changelog

Todas as mudancas notaveis para esta demo serao documentadas neste arquivo.

## [1.0.0] - Implementação de Registro Autoritativo

### Added

- Factory de perfis de rede, estipulando Qualidade de Serviço (QoS) arbitrária para Players (60Hz) e Props de Cenário (5Hz).
- Separação assíncrona entre o Gateway da Engine C++ e a renderização do mundo através de um Adapter.
- Abordagem Zero-RPC nos Clientes: Renderização estática local (Client-Side) otimista combinada à leitura visual crua dos avatares alheios, ignorando pacotes ecoados pelo Servidor.
