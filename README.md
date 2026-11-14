# Gen1 Achievements

Mod de conquistas para Pokémon Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire e Emerald no Gen1Recomp.

> **Estado:** catálogo expandido para 17–20 conquistas por jogo, com progressão por eventos reais, três idiomas e proteção contra desbloqueios retroativos obtidos por edição do save.

## Experiência dentro do jogo

- Nova opção no menu START, posicionada antes de OPTIONS.
- Tela de conquistas controlada pelo D-pad e pelos botões A/B/START.
- Filtros All / Unlocked / Locked.
- Detalhes e descrições das conquistas.
- Contadores de progresso para conquistas incrementais.
- Notificação na tela quando uma conquista é desbloqueada.
- Conquistas secretas podem esconder título e descrição até o desbloqueio.

A interface usa os widgets e hooks oficiais da Portable Mod API 3. O item do menu e a tela são registrados pelo próprio mod; não é necessário modificar o código-base do Gen1Recomp para adicionar a entrada ao menu START.

## Jogos e perfis

Os onze jogos têm catálogos e arquivos de progresso independentes:
- Red, Blue e Yellow;
- Gold, Silver e Crystal;
- FireRed e LeafGreen;
- Ruby, Sapphire e Emerald.

O progresso é armazenado por título, compartilhado entre os saves daquele jogo na mesma instalação. A persistência usa `mod.cache`, fora do arquivo de save. O mod só desbloqueia conquistas quando recebe eventos reais durante uma sessão pronta; flags que já estavam gravadas no save ao carregá-lo não são varridas para conceder conquistas retroativas. Ainda não há sincronização de conta ou nuvem.

## Idiomas

O idioma escolhido no gerenciador de mods do launcher controla os textos da tela, nomes e descrições:
- `en` — English
- `pt-BR` — Português (Brasil), padrão
- `es` — Español

## Catálogo

`data/achievements.tsv` é a fonte de dados executada pelo mod. Cada linha declara jogo, id, evento, condição (inclusive caminhos aninhados como `mon.species`), tipo de progresso, se é secreta, título e descrição nos três idiomas.

Cada jogo contém entre 17 e 20 conquistas de Pokédex, evolução, batalhas, insígnias, história, exploração e recursos próprios da geração. Johto inclui os dois circuitos de ginásios, além de Unown, Bug-Catching Contest, Apricorns, ovos e Pokérus; Hoenn inclui os Regis, os Pokémon errantes, fitas e ovos; FireRed/LeafGreen incluem o conteúdo normal das Ilhas Sevii. Nenhuma conquista depende de Mystery Gift, tickets de distribuição, ilhas temporárias, trocas online ou link play.

## Arquivos principais

- `manifest.json` — Portable Mod API 3 e os onze jogos.
- `main.lua` — menu START, tela, persistência, eventos e notificações.
- `data/achievements.tsv` — catálogo localizado.
- `data/games.json` — títulos e ordem dos jogos.
- `data/ui_locales.tsv` — textos de interface carregados pelo mod.
- `data/ui_locales.json` — espelho legível das mesmas traduções para ferramentas e futuras integrações.
- `docs/` — arquitetura, armazenamento, integridade e contrato dos eventos.
- `tests/validate_catalog.py` — validação estrutural e de traduções.
- `tests/validate_engine_contract.py` — verificação de eventos, campos e tipos contra a revisão fixada do motor.
- `tests/runtime_harness.lua` — execução controlada do `main.lua` com uma API de teste.

## Validação e testes

Execute localmente a validação estrutural e a verificação do contrato de eventos, além da sintaxe LuaJIT e do harness:

```bash
python3 tests/validate_catalog.py
python3 tests/validate_engine_contract.py
luajit -b main.lua /tmp/gen1-achievements.luac
luajit tests/runtime_harness.lua
```

O validador do catálogo verifica as 15 colunas do TSV, IDs únicos, três idiomas, operadores e limites equilibrados de 17–20 conquistas por jogo. O contrato de eventos confere disponibilidade por geração, caminho de campo, tipo do valor comparado e as diferenças de payload entre Gen 1, Gen 2 e Gen 3. A referência do motor fica fixada em `tests/engine_event_contract.json`, para que a validação não mude silenciosamente quando o upstream evoluir.

O harness carrega o `main.lua` real com uma implementação controlada da Portable Mod API 3 e exercita todas as 205 linhas do catálogo, além dos bloqueios de sessão, isolamento entre jogos, migração do perfil legado, rejeição de perfis malformados, preservação de progresso válido, criação de save novo e falhas de gravação. O GitHub Actions executa as quatro verificações em cada atualização de `main`.

Esses testes automatizados não substituem testes dentro das versões executáveis dos onze jogos. Até aqui, não foi feita uma partida real de validação com ROMs.

## Referências técnicas

- [Cookbook: UI and Infrastructure](https://github.com/bryanthaboi/gen1recomp/wiki/Cookbook-UI-And-Infrastructure)
- [Reference: Mod Object](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Mod-Object)
- [Reference: Events](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events)
- [Reference: Hooks](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks)
- [Concepts: Save Model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model)
- [Event contract revision](https://github.com/bryanthaboi/gen1recomp/commit/825f1670aeecb4a72345fb473d287fd8ea502ad2)

Nenhuma ROM, save, firmware, imagem extraída ou outro dado proprietário é incluído no repositório.
