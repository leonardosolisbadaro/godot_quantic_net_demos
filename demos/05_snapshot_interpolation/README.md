# Demo 05: Snapshot Interpolation

## Visão Geral

Esta demo aborda o problema clássico de travamentos (stuttering) ao observar outros jogadores. Ela implementa a técnica de Snapshot Interpolation para garantir que a renderização visual de entidades remotas seja perfeitamente fluida, mesmo sob condições de rede caóticas ou perda de pacotes.

## Como Funciona

Os pacotes posicionais chegando em rajadas via UDP não são mais aplicados diretamente na posição da malha. O `InterpolateRemoteEntitiesUseCase` delega as coordenadas mais recentes para o domínio (`SnapshotInterpolator`), que calcula uma curva de interpolação linear (Lerp) baseada no tempo delta, suavizando a transição de forma assíncrona dentro do loop de `_process`.

## Desafios e Soluções (Clean Architecture)

- **Snapping Agressivo:** A aplicação instantânea das coordenadas de rede causava teletransportes desagradáveis nos oponentes. Extrair a lógica de interpolação para uma classe pura no Domínio permitiu focar estritamente na matemática de aproximação, garantindo testes robustos independentes da Godot e resolvendo o stuttering visual de forma limpa.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
