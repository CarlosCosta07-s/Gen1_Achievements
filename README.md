# Gen1 Achievements

Mod de conquistas para Pokémon Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire e Emerald no Gen1Recomp.

> **Estado:** sistema-base do menu e da tela de conquistas implementado. O menu START recebe **Achievements / Conquistas / Logros**, com uma tela própria, filtros, detalhes, progresso incremental e notificações de desbloqueio. O catálogo ainda está vazio enquanto as primeiras conquistas são pesquisadas e validadas.

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

O progresso é armazenado pelo título do jogo, compartilhado entre os saves desse título na mesma instalação. A persistência usa `mod.cache`, que é local à instalação. Ainda não há sincronização de conta ou nuvem entre dispositivos.

## Idiomas

O idioma escolhido no gerenciador de mods do launcher controla os textos da tela, nomes e descrições:
- `en` — English
- `pt-BR` — Português (Brasil), padrão
- `es` — Español

## Catálogo

`data/achievements.tsv` é a fonte de dados executada pelo mod. Cada linha declara jogo, id, evento, condição, tipo de progresso, se é secreta, título e descrição nos três idiomas.

O arquivo está inicialmente sem conquistas publicadas. Não adicionamos nomes genéricos nem gatilhos inventados: cada entrada será criada após pesquisa das referências do jogo e da comunidade, seguida de validação do evento no Gen1Recomp.

## Arquivos principais

- `manifest.json` — Portable Mod API 3 e os onze jogos.
- `main.lua` — menu START, tela, persistência, eventos e notificações.
- `data/achievements.tsv` — catálogo localizado.
- `data/games.json` — títulos e ordem dos jogos.
- `data/ui_locales.tsv` — textos de interface carregados pelo mod.\n- `data/ui_locales.json` — espelho legível das mesmas traduções para ferramentas e futuras integrações.
- `docs/` — arquitetura, armazenamento e integração.
- `tests/validate_catalog.py` — validação automatizada do catálogo.

## Validação

```bash
python3 tests/validate_catalog.py
```

A validação verifica os onze jogos, ids únicos, eventos conhecidos, condições e traduções obrigatórias.

## Referências técnicas

- [Cookbook: UI and Infrastructure](https://github.com/bryanthaboi/gen1recomp/wiki/Cookbook-UI-And-Infrastructure)
- [Reference: Mod Object](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Mod-Object)
- [Reference: Events](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events)
- [Reference: Hooks](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks)
- [Concepts: Save Model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model)

Nenhuma ROM, save, firmware, imagem extraída ou outro dado proprietário é incluído no repositório.
