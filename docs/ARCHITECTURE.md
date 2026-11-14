# Arquitetura do Gen1 Achievements

## Interface dentro do jogo

A implementação usa as superfícies oficiais da Portable Mod API 3:
- Hook `ui.start_menu.items` para inserir a opção logo depois de `SAVE`, mantendo-a antes de `OPTION`.
- `mod.content.screens:register` para registrar a tela própria.
- `mod.ui.push` para abrir a tela a partir da opção do menu.
- Tela com `update(dt)` e `draw()`, usando `game.input:wasPressed` para D-pad, A, B e START.

O mesmo contrato é usado nas três gerações. A opção do menu ajusta sua largura automaticamente com base no maior rótulo, permitindo nomes localizados mais longos.

## Comportamento de console

A tela implementa:
- resumo total/desbloqueadas;
- filtros geral, desbloqueadas e bloqueadas;
- navegação por lista e tela de detalhes;
- conquistas secretas;
- progresso numérico em objetivos incrementais;
- notificação curta na tela após o desbloqueio.

O desbloqueio é disparado por eventos oficiais. A linha de catálogo define o evento e sua condição. O sistema só se inscreve em eventos que a versão em execução declara suportar por `mod:supports("events", name)`. A primeira versão expandida usa eventos reais de captura, evolução, batalha, mudança de flag, entrada em mapa, reprodução, amizade, Pokérus e mecânicas exclusivas de Johto.

## Fonte de dados

`data/achievements.tsv` é a fonte de dados executada pelo mod. Colunas (15, separadas por TAB):

1. game
2. id
3. event
4. match_field
5. operator (`any`, `equals`, `at_least`, `truthy`, `one_of`, `one_of_true`, `ends_with`)
6. match_value
7. mode (`instant` ou `counter`)
8. target
9. secret (`true` / `false`)
10. title_en
11. description_en
12. title_pt-BR
13. description_pt-BR
14. title_es
15. description_es

Para `operator=any`, use `*` em `match_field`. Os campos também aceitam caminhos aninhados, como `mon.species`. `one_of` compara o campo com uma lista separada por `|`; `one_of_true` faz o mesmo e exige que `event.value == true`, para contar apenas a ativação real de uma flag; `ends_with` identifica mapas pelo sufixo estável de `mapId`, sem depender do prefixo específico de cada jogo. Em modo `counter`, cada ocorrência que satisfaz a condição incrementa o valor persistido até `target`.

Eventos usados incluem `pokemon.caught`, `pokemon.level_up`, `pokemon.evolved`, `pokemon.move_learned`, `battle.ended`, `map.entered`, `flag.changed`, `egg.hatched`, `happiness.changed`, `pokerus.infected` e eventos exclusivos de Johto. O validador mantém uma matriz de disponibilidade por geração.

## Persistência e identidade

O perfil de conquistas é por instalação e por título, não por save. O formato 2 verifica cada ID e progresso contra o catálogo atual e descarta perfis malformados ou IDs de outro jogo; perfis legados do formato 1 são lidos e regravados no formato 2 na próxima atualização persistida. Isso detecta corrupção e edições casuais, mas não é assinatura criptográfica contra alguém que modifique o código ou o próprio cache.

A proteção contra manipulação do save é baseada no fluxo de eventos: `save.loading` desativa os desbloqueios, `save.loaded` e `save.created` reativam a sessão, e o mod nunca concede conquistas lendo flags antigas do save. Uma edição de `.sav` que apenas marque uma insígnia ou capture um Pokémon não cria, por si só, o evento de ação ao vivo necessário para desbloquear a conquista. No Gen 1, `flag.changed.name` é textual; no Gen 2, é numérico; no Gen 3, o motor fornece o nome resolvido e também o ID numérico. O comparador aceita essas formas sem depender de um scan do save.

Armazenamento:
- `mod.cache:read/write("profiles/red.dat")`, por exemplo;
- cada uma das onze versões usa um caminho separado;
- começar um New Game não reinicia conquistas do mesmo título;
- Red não compartilha progresso com Blue ou Yellow, e assim por diante.

Esse comportamento é mais próximo de conquistas vinculadas ao título em consoles modernos do que de objetivos presos a um save. O limite atual é que `mod.cache` é local à instalação. Não é uma conta online e não sincroniza dados entre dispositivos ou usuários do mesmo aplicativo.

## Testes automatizados

O repositório possui duas camadas complementares de verificação:

1. `tests/validate_catalog.py` valida as 15 colunas do TSV, unicidade de IDs, idiomas, operadores, limites dos contadores e eventos autorizados para cada geração.
2. `tests/runtime_harness.lua` carrega o `main.lua` real e fornece uma implementação controlada das superfícies Portable Mod API 3 necessárias. O harness percorre cada linha dos onze catálogos e verifica correspondência de eventos, bloqueio antes de `save.loaded`, desbloqueio único, persistência no arquivo correto, separação entre títulos, migração do formato 1, rejeição de IDs estrangeiros e rollback quando a gravação falha.

Para executar:

```bash
python3 tests/validate_catalog.py
luajit -b main.lua /tmp/gen1-achievements.luac
luajit tests/runtime_harness.lua
```

O harness exercita as 205 definições atuais com payloads sintéticos. Isso comprova a lógica de interpretação e persistência do mod sob o contrato simulado; não comprova que cada call site do motor emita exatamente o payload esperado em uma partida real. A confirmação final exige testar as versões executáveis dos onze jogos.

## Idioma

`mod.options` persiste `achievement_language` fora do save do jogo e oferece English, Português (Brasil) e Español. A tela carrega os textos de `data/ui_locales.tsv`, espelhados em JSON para ferramentas. O mesmo valor é usado para nomes e descrições; IDs, condições e progresso independem do idioma.
