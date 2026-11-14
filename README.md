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

`data/achievements.tsv` é a fonte de dados executada pelo mod. Cada linha declara jogo, id, evento, condição (inclusive caminhos aninhados como mon.species), tipo de progresso, se é secreta, título e descrição nos três idiomas.

Cada jogo contém entre 17 e 20 conquistas de Pokédex, evolução, batalhas, insígnias, história, exploração e recursos próprios da geração. Johto inclui os dois circuitos de ginásios, além de Unown, Bug-Catching Contest, Apricorns, ovos e Pokérus; Hoenn inclui os Regis, os Pokémon errantes, fitas e ovos; FireRed/LeafGreen incluem o conteúdo normal das Ilhas Sevii. Nenhuma conquista depende de Mystery Gift, tickets de distribuição, ilhas temporárias, trocas online ou link play.

## Arquivos principais

- `manifest.json` — Portable Mod API 3 e os onze jogos.
- `main.lua` — menu START, tela, persistência, eventos e notificações.
- `data/achievements.tsv` — catálogo localizado.
- `data/games.json` — títulos e ordem dos jogos.
- `data/ui_locales.tsv` — textos de interface carregados pelo mod.
- `data/ui_locales.json` — espelho legível das mesmas traduções para ferramentas e futuras integrações.
- `docs/` — arquitetura, armazenamento e integração.
- `tests/validate_catalog.py` — validação automatizada do catálogo.

## Validação

```bash
python3 tests/validate_catalog.py
```

A validação verifica eventos disponíveis por geração, condições, traduções e um limite equilibrado de 17–20 conquistas por jogo. O GitHub Actions também compila a sintaxe do LuaJIT.

## Referências técnicas

- [Cookbook: UI and Infrastructure](https://github.com/bryanthaboi/gen1recomp/wiki/Cookbook-UI-And-Infrastructure)
- [Reference: Mod Object](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Mod-Object)
- [Reference: Events](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events)
- [Reference: Hooks](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks)
- [Concepts: Save Model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model)

Nenhuma ROM, save, firmware, imagem extraída ou outro dado proprietário é incluído no repositório.
