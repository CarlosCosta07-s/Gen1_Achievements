# Fullscreen Fit — Aspect Ratio

Um addon independente para Gen1Recomp (Portable Mod API 3).

## O que faz

- Aproveita a maior área possível da janela para a imagem do jogo.
- Mantém a proporção nativa: 10:9 em Pokémon Red/Blue/Yellow e Gold/Silver/Crystal; 3:2 em FireRed/LeafGreen/Ruby/Sapphire/Emerald.
- Centraliza a imagem e usa barras pretas nos espaços que sobram em janelas ou telas com proporções diferentes.
- Mantém o overlay de controles virtuais em tela cheia, pois o hook de viewport atua apenas na área do jogo.
- Considera as métricas de DPI físico para não introduzir proporções diferentes em monitores e aparelhos de alta densidade.

O addon apenas escolhe a área de renderização através do hook público `render.viewport`. O motor continua responsável por desenhar sprites, cenários, fontes, filtros e pixels. Não há escalonamento independente dos eixos nem deformação das sprites.

## Instalação

1. Baixe o pacote `fullscreen-fit-1.0.0.zip` na Release do Gen1 Achievements.
2. Extraia a pasta `fullscreen-fit-1.0.0`.
3. Coloque a pasta que contém `manifest.json` e `main.lua` na pasta de mods do Gen1Recomp.
4. Ative **Fullscreen Fit — Aspect Ratio** no gerenciador de mods e reinicie o jogo.

O addon está em uma pasta própria e não depende do mod de conquistas. Pode ser usado com ou sem ele.

## Importante sobre o modo de janela no PC

O addon maximiza a imagem dentro da janela disponível; ele não altera o modo de janela do sistema operacional. Para remover a moldura da janela no PC, use o modo **Fullscreen/Borderless** nas opções nativas de vídeo do Gen1Recomp. Em Android e iOS, o addon usa a área de jogo fornecida pela tela do aparelho.

## Limites

Preencher cada pixel de uma tela ultrawide ou muito alta sem barras exigiria esticar ou cortar a imagem. Este addon prefere preservar o enquadramento inteiro, com barras laterais ou superior/inferior quando necessário.

O addon não corrige sobreposições internas de menus ou telas específicas de mods; essas interfaces precisam ajustar seus próprios layouts ao tamanho lógico do jogo.
