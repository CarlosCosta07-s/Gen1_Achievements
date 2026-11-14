# Arquitetura do Gen1 Achievements

## Interface dentro do jogo

A implementação usa as superfícies oficiais da Portable Mod API 3:
- Hook `ui.start_menu.items` para inserir a opção antes de `OPTION`.
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

O desbloqueio é disparado por eventos oficiais. A linha de catálogo define o evento e sua condição. O sistema só se inscreve em eventos que a versão em execução declara suportar por `mod:supports("events", name)`.

## Fonte de dados

`data/achievements.tsv` é a fonte de dados executada pelo mod. Colunas (15, separadas por TAB):

1. game
2. id
3. event
4. match_field
5. operator (`any`, `equals`, `at_least`, `truthy`)
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

Para `operator=any`, use `*` em `match_field`. Em modo `counter`, cada ocorrência que satisfaz a condição incrementa o valor persistido até `target`.

Eventos disponíveis na referência incluem `pokemon.caught`, `pokemon.level_up`, `pokemon.evolved`, `pokemon.move_learned`, `battle.ended`, `battle.started` e `map.entered`; o mod valida a disponibilidade do evento antes de assinar.

## Persistência e identidade

O perfil de conquistas é por instalação e por título, não por save:
- `mod.cache:read/write("profiles/red.dat")`, por exemplo;
- cada uma das onze versões usa um caminho separado;
- começar um New Game não reinicia conquistas do mesmo título;
- Red não compartilha progresso com Blue ou Yellow, e assim por diante.

Esse comportamento é mais próximo de conquistas vinculadas ao título em consoles modernos do que de objetivos presos a um save. O limite atual é que `mod.cache` é local à instalação. Não é uma conta online e não sincroniza dados entre dispositivos ou usuários do mesmo aplicativo.

## Idioma

`mod.options` persiste `achievement_language` fora do save do jogo e oferece English, Português (Brasil) e Español. A tela carrega os textos de `data/ui_locales.tsv`, espelhados em JSON para ferramentas. O mesmo valor é usado para nomes e descrições; IDs, condições e progresso independem do idioma.
