# Gen1 Achievements

Mod de conquistas para Pokémon Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire e Emerald no Gen1Recomp.

> **Estado:** fundação do projeto. A seleção de idioma e os onze catálogos independentes já estão definidos. As conquistas jogáveis serão adicionadas após validar seus gatilhos por versão e pesquisar referências adequadas na comunidade.

## Objetivos

- Um único mod Lua usando a Portable Mod API 3.
- Catálogos e desbloqueios independentes para cada um dos onze jogos.
- Nomes e descrições em **English**, **Português (Brasil)** e **Español**.
- Seleção de idioma persistente no launcher, sem depender do idioma do jogo.
- Referências reconhecíveis a cada jogo e a materiais relacionados: jogos, anime, Pokémon Adventures, personagens, locais, memes e cultura da comunidade.
- Progresso local, sem exigir conexão com a internet.
- Nenhuma ROM, save, firmware, arte extraída ou outro dado proprietário incluído no repositório.

## Idioma

A primeira implementação usa a opção oficial `mod.options` chamada `achievement_language`. O Gen1Recomp exibe opções de mod no gerenciador de mods do launcher e as mantém mesmo após iniciar um New Game.

Valores:
- `en` — English
- `pt-BR` — Português (Brasil), padrão inicial
- `es` — Español

O objetivo final é exibir também esse seletor diretamente em **Extras → Conquistas**. Isso requer uma integração complementar no código do launcher; a API pública de mods não documenta um mecanismo para adicionar uma nova aba ao launcher.

## Estrutura

- `manifest.json` — manifesto API 3 para os onze jogos.
- `main.lua` — definição da opção de idioma e evento de alteração.
- `data/games.json` — lista ordenada dos jogos.
- `data/achievements.json` — onze catálogos separados e esquema inicial.
- `data/ui_locales.json` — textos de interface nas três línguas.
- `docs/` — arquitetura, regras de nomes e integração do launcher.
- `tests/validate_catalog.py` — valida o contrato dos dados e das traduções.

## Validação

Execute:

```bash
python3 tests/validate_catalog.py
```

A validação confirma a presença dos onze jogos, a separação dos catálogos e os três idiomas obrigatórios em cada conquista cadastrada.

## Referências técnicas

- [Gen1Recomp — Native modding](https://github.com/bryanthaboi/gen1recomp/blob/dev/docs/modding.md)
- [Portable Mods — Gen 1, 2 and 3](https://github.com/bryanthaboi/gen1recomp/wiki/Guide-Portable-Mods)
- [Reference Events](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events)
- [Save Model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model)
