# Contrato de eventos do motor

Este documento registra os campos de eventos que o catálogo de conquistas consome. O snapshot automatizado está em `tests/engine_event_contract.json`; o verificador `tests/validate_engine_contract.py` compara todas as condições do TSV com esse contrato.

## Revisão de referência

O contrato foi conferido no repositório `bryanthaboi/gen1recomp`, branch `dev`, commit `825f1670aeecb4a72345fb473d287fd8ea502ad2`. A matriz considera os pontos de emissão e a adaptação da Portable Mod API 3, incluindo `src/mods/UnifiedCallbacks.lua` e `src/mods/UnifiedRecords.lua`.

O snapshot é intencionalmente fixado em um commit: uma alteração futura do motor não muda silenciosamente o que os testes acreditam sobre os payloads. Quando o contrato do motor mudar, a matriz deve ser reavaliada, o SHA de referência atualizado de propósito e os testes executados novamente.

## Condições verificadas

| Evento | Disponibilidade | Campos utilizados pelo catálogo |
| --- | --- | --- |
| `pokemon.caught` | Gen 1, 2 e 3 | `species` (texto) e `isNew` (booleano) |
| `pokemon.evolved` | Gen 1, 2 e 3 | Evento sem filtro de campo |
| `battle.ended` | Gen 1, 2 e 3 | `result` (texto; o catálogo só aceita `win`) |
| `pokemon.move_learned` | Gen 1, 2 e 3 | Evento sem filtro de campo |
| `pokemon.level_up` | Gen 1, 2 e 3 | `mon.species` (ID canônico em texto) |
| `flag.changed` | Gen 1, 2 e 3 | `name` e `value`; o nome é textual em Gen 1, numérico em Gen 2 e pode ser textual ou numérico em Gen 3 |
| `map.entered` | Gen 1, 2 e 3 | `mapId` (texto) |
| `egg.hatched` | Gen 2 e 3 | Evento sem filtro de campo |
| `bug_contest.scored` | Somente Gen 2 | `place` (número) |
| `unown.unlocked` | Somente Gen 2 | `count` (número de formas registradas) |
| `apricorn.converted` | Somente Gen 2 | Evento sem filtro de campo |
| `pokerus.infected` | Gen 2 e 3 | Evento sem filtro de campo |
| `happiness.changed` | Gen 2 e 3 | `to` (número) |

## Diferenças relevantes entre gerações

- `flag.changed` só é emitido em uma transição real. Gold, Silver e Crystal colocam o índice numérico da flag em `name`; o mod compara esses valores como números. Gen 1 usa identificadores textuais. Gen 3 pode resolver o nome para texto ou manter o ID quando não há nome associado.
- O evento de captura mantém `species` e `isNew` nas três gerações, e a camada unificada normaliza o registro para o contrato da API.
- `map.entered` entrega `mapId`; a comparação por sufixo evita depender dos prefixos usados pelos mapas de Gen 3.
- Os três eventos de Johto (`bug_contest.scored`, `unown.unlocked` e `apricorn.converted`) não são tratados como eventos globais: o catálogo os utiliza somente em Gold, Silver e Crystal.
- O evento `unown.unlocked` representa uma nova forma adicionada ao registro de Unown. O campo `count` mede formas registradas, não apenas puzzles resolvidos.

## Limites

O validador garante que nomes, disponibilidade por geração, caminhos de campos e tipos comparados pelo catálogo correspondam ao snapshot do motor. O harness de runtime continua usando payloads sintéticos para testar a lógica de desbloqueio e persistência. Nenhum dos dois substitui uma partida real em cada uma das onze versões executáveis.
