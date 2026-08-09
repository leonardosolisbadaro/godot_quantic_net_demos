# Demo 01: Handshake & State Machine

## Visão Geral

Esta demo é o ponto de partida do ecossistema. Ela foca em gerenciar de forma robusta e previsível as transições do ciclo de vida da conexão (Conectando, Autenticando, Conectado, Desconectado) entre cliente e servidor, criando uma fundação sólida para qualquer jogo multiplayer.

## Como Funciona

O sistema orquestra o protocolo de handshake nativo do plugin utilizando uma Máquina de Estados (State Machine). O `QuanticNetAdapter` atua como uma ponte tradutora na camada de Interface, capturando os eventos da engine subjacente em C++ e atualizando a Interface de Usuário visual.

## Desafios e Soluções (Clean Architecture)

- **Isolamento da UI:** Havia um forte acoplamento entre a tela e a volatilidade da rede. A solução foi isolar a UI dos Sinais Assíncronos da Godot/ENet, garantindo que os botões e painéis reajam unicamente aos estados concretos ditados pelo Domínio.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
