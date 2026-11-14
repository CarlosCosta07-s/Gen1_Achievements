# Integração de conquistas

## Menu START — implementado no mod

O mod agora usa a API oficial do Gen1Recomp para inserir **Achievements / Conquistas / Logros** antes de OPTIONS no menu START. A tela é registrada por `mod.content.screens` e aberta por `mod.ui.push`. Não é necessária alteração do código-base para esse fluxo.

## Launcher

A preferência de idioma continua em MODS → Gen1 Achievements → Achievement language. Valores:
- English (`en`)
- Português (Brasil) (`pt-BR`)
- Español (`es`)

O idioma controla a tela dentro do jogo, inclusive nomes e descrições. A tradução da interface é carregada de `data/ui_locales.tsv` e espelhada em `data/ui_locales.json`.

Uma futura página de visão global no launcher, como Extras → Conquistas, é uma integração separada. Não é necessária para que o menu START e a tela do jogo funcionem.
