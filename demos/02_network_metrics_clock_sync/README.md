# Demo 02: Network Metrics & Clock Sync

## Visão Geral

Uma demo focada puramente em telemetria vital. Ela expõe o diagnóstico da rede em tempo real, fornecendo os dados e a precisão matemática necessários para que os futuros sistemas de predição do jogo consigam compensar o lag do jogador.

## Como Funciona

Através do `TelemetryAdapter`, a demo extrai constantemente do QuanticNet as métricas cruas da ENet (Ping/RTT, Jitter, Packet Loss). Na camada de Domínio, um algoritmo matemático de Janela Deslizante (Sliding Window) calcula os picos e quedas crônicas (1% Low) de performance da rede e dos quadros (FPS), exibindo-os no HUD.

## Desafios e Soluções (Clean Architecture)

- **Ruído de Rede (Jitter):** O fluxo de pacotes bruto era muito volátil e impossível de ler visualmente. O desafio foi vencido agrupando os dados via agregação matemática estritamente testada (TDD), permitindo diagnósticos confiáveis de gargalos mesmo sob Injeção de Latência Sintética severa (NETEM).

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
