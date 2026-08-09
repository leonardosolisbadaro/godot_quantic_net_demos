# Demo 06: Server Authority & Snapback

## Visão Geral

Nesta demo, o Servidor deixa de ser apenas um roteador e passa a agir como Juiz (Autoridade Absoluta). O foco é validar a movimentação preditiva recebida dos clientes, punindo ativamente violações de cinemática (cheats e speedhacks) e forçando uma correção agressiva na tela do infrator.

## Como Funciona

O servidor C++ é alimentado com um limite rígido de movimentação permitida (`max_speed`). Caso a distância percorrida pelo avatar supere a realidade da física configurada, o QuanticNet bloqueia o processamento e dispara um pacote `TYPE_SNAPBACK` forçando a coordenada verdadeira na garganta do cliente infrator. O cliente absorve o impacto e reseta sua própria simulação.

## Desafios e Soluções (Clean Architecture)

- **Cassação de Confiança:** Em arquiteturas de predição, o cliente "mente" sua posição temporariamente. O desafio foi injetar tolerância suficiente para que usuários lagados não fossem banidos injustamente, mantendo uma abordagem anti-cheat implacável, configurando o Domínio para aceitar silenciosamente as punições sem quebrar o loop do jogo.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
