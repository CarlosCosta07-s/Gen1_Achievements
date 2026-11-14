# Arquitetura inicial

## Mod portátil

O projeto usa a Portable Mod API 3 do Gen1Recomp: um manifesto e um entry point Lua para as três gerações. A declaração de jogos lista explicitamente as onze versões, em vez de usar somente `gen1`, `gen2` e `gen3`, para tornar a cobertura pretendida verificável.

## Identidade dos jogos

Cada versão possui uma chave própria em `data/achievements.json`:

- Red, Blue e Yellow não compartilham conquistas.
- Gold, Silver e Crystal não compartilham conquistas.
- FireRed e LeafGreen não compartilham conquistas.
- Ruby, Sapphire e Emerald não compartilham conquistas.

O progresso nunca será agregado entre versões diferentes. O launcher deverá apresentar os onze jogos separadamente.

## Localização

Os idiomas suportados são `en`, `pt-BR` e `es`. Toda conquista cadastrada deve conter:
- um título nos três idiomas;
- uma descrição nos três idiomas;
- um identificador estável e exclusivo;
- um gatilho validado no jogo correspondente;
- uma nota interna explicando a referência que inspirou o nome.

Os identificadores e as condições são independentes do idioma. Alterar o idioma muda somente os textos apresentados, nunca o desbloqueio ou o progresso.

A preferência é definida por `mod.options`, que fica fora dos saves e sobrevive a New Game. O valor padrão inicial é Português (Brasil).

## Eventos do jogo

A API 3 documenta eventos úteis, entre eles `pokemon.caught`, `pokemon.evolved`, `pokemon.level_up`, `pokemon.move_learned`, `battle.ended` e eventos de mundo. Antes de uma conquista usar um evento, é necessário verificar:
1. se o evento tem chamada nativa em cada versão alvo;
2. o payload e o momento exato em que é emitido;
3. se o evento representa a ação desejada (por exemplo, captura selvagem não equivale necessariamente a receber um Pokémon por presente).

Não usar nomes de eventos inferidos nem presumir que eventos exclusivos de uma geração existem nas outras.

## Persistência — decisão ainda em aberto

A documentação do motor distingue:
- `mod.options`: preferências do jogador, globais ao mod e persistentes entre New Game;
- `mod.save`: dados que acompanham o save normal;
- `mod.storage`: dados persistentes separados, associados à versão do jogo e à identidade de uma partida.

O projeto ainda não fixa se duas partidas diferentes do mesmo jogo compartilham o conjunto de conquistas. Essa decisão deve ser confirmada antes de escolher o backend definitivo. Em qualquer opção, os onze jogos permanecem separados.

## Integração visual

O catálogo e a localização são dados independentes do launcher. A página **Extras → Conquistas** deverá ler esses dados e exibir cartões separados por jogo, com total, desbloqueadas, percentual e histórico. O seletor de idioma deve aparecer nessa própria página e atualizar tanto títulos quanto descrições.
