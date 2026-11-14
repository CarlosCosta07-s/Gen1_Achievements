## 0.5.7 — Contexto de batalhas duplas

- Identificado no painel o Pokémon ativo que está escolhendo o comando, acompanhando a troca de slot entre as ações da batalha dupla.
- Diferenciados visualmente o combatente ativo, o parceiro e os adversários nos cartões de seleção de alvo.
- Preservados os IDs nativos dos alvos, inclusive quando a lista é esparsa; a fase de equipe e a troca de Pokémon continuam sob controle do jogo.
- Adicionadas traduções dos novos indicadores em inglês, português brasileiro e espanhol.
- Ampliado o harness para verificar papéis dos battlers, mudança do slot ativo, envio do ID nativo do parceiro e passagem da fase `party` ao jogo.

## 0.5.6 — Menus especiais e transições nativas

- Integrado o seletor Mimic de Gen 1 pela intenção pública `mimic`, preservando o índice da lista nativa de golpes copiáveis.
- Integrado o menu da Safari Zone de Gen 1 pela intenção `safari`, com Ball, Bait, Rock, Run e contador de bolas restantes; todas as ações ficam bloqueadas em zero.
- Adicionadas traduções de Mimic e Safari nos três idiomas.
- Seleção forçada de equipe, avanço de mensagens, fases bloqueadas, tutoriais e batalhas Link permanecem nativos; a ponte de toque é restaurada ao sair de uma fase substituída.
- Alinhado o indicador de PP ao contrato da fachada pública: PP ausente é normalizada como zero e exibida como `PP 0/0`, não como estado desconhecido.
- Ampliado o harness para testar Mimic, Safari, PP normalizada e transições de volta aos menus nativos.

## 0.5.5 — Compatibilidade dos snapshots entre gerações

- PP tratada conforme a fachada pública do motor: valores ausentes chegam ao mod normalizados como zero; o campo `disabled` também é respeitado.
- Preservado o slot original dos golpes quando a lista compactada da terceira geração não corresponde à posição visual.
- Reforçada a seleção de alvos da terceira geração para manter IDs nativos esparsos, sem confundi-los com índices da grade.
- Ampliado o harness com casos de PP normalizada, PP zero, slot 3 e alvos nativos 0/3; documentadas as diferenças dos contratos Gen 1, Gen 2 e Gen 3.

## 0.5.4 — Legibilidade dos cartões de golpe

- Separado o nome do golpe da faixa inferior de tipo e PP, evitando colisões na resolução lógica padrão.
- Aplicada escala proporcional aos textos de nomes, tipos e PP para preservar a leitura em cartões estreitos.
- Corrigido o truncamento de tipos com oito caracteres, como Electric e Fighting; o harness agora verifica nome, tipo completo e PP na renderização.

## 0.5.3 — Coordenadas de toque em viewport ampliado

- Convertidas as coordenadas do ponteiro de janela para o espaço lógico do jogo antes de testar cartões e a área B: VOLTAR.
- Adicionado teste de clique com viewport deslocado e renderização em escala 2×.

## 0.5.2 — Captura de toques curtos

- Registradas as bordas do overlay virtual diretamente em Input.overlayPressed, incluindo toques liberados antes do próximo passo de lógica.
- Mantido o bloqueio nativo apenas até o passo que consome o toque, sem interferir em teclado, gamepad ou outras fontes.
- Adicionados testes para press/release no mesmo intervalo e para a restauração exata dos métodos nativos.

## 0.5.1 — Ponte de controles virtuais para o menu de batalha

- Encaminhadas as bordas do D-pad e dos botões A/B do overlay Android/iOS pelo mesmo seletor de batalha.
- Mascarada apenas a origem do overlay durante fases substituídas, preservando entradas físicas e ferramentas de acessibilidade.
- Adicionado suporte a direção + A no mesmo quadro e toque direto na indicação de retorno.
- Ampliados os testes do harness para toque simultâneo, prevenção de entrada duplicada e restauração dos métodos nativos.

## 0.5.0 — Menu de batalha redesenhado

- Criado pelo mod um novo menu de batalha com referência de composição em Pokémon Black/White: bandeja escura, cartões claros, cores de tipo e indicadores de PP.
- Adicionadas onze variações de acento cromático e acabamento, uma para cada jogo, sem copiar assets, fontes ou sprites.
- Implementados comandos validados de Fight, Bag, Pokémon, Run, seleção de golpes, alvos em batalhas duplas e retorno com B via `mod.battle:snapshot()`/`submit()`.
- Adicionados controles por teclado, gamepad e toque, capturados somente nas fases controláveis do menu substituto.
- Mantidos nativos os turnos, regras, golpes, itens, trocas, mensagens, mochila e equipe.
- Reorganizadas as ações comuns dos submenus da equipe sem deslocar movimentos de campo ou entradas de outros mods.
- Ampliados os testes do harness para desenho, cores, comandos, PP, alvos, retorno, toque e submenus.

## 0.4.5 — Organização das opções dentro do jogo

- Mantidas as configurações do Gen1 Achievements no gerenciador MODS dentro do jogo; a opção de idioma não é duplicada nas opções gerais.
- Adicionado o hook `ui.options.rows` para ordenar opções nativas dentro das categorias existentes nos onze jogos.
- Organizadas as opções de áudio, vídeo, gráficos, batalha, velocidade e extras sem alterar aparência, renderização ou controles.
- Preservadas posições e referências de opções desconhecidas e de outros mods.
- Removida a especificação da página global Extras → Conquistas, descartada como escopo do projeto.
- Adicionados testes do hook de opções, da preservação de outras linhas e da configuração do mod no gerenciador interno.

## 0.4.4 — Localização e visibilidade das conquistas

- Exibida a orientação de navegação dos filtros no rodapé da lista, nos três idiomas, sem ocupar as linhas dos objetivos.
- Ampliados os testes de UI para todos os onze jogos e os três idiomas, conferindo rótulo do menu, título, total e filtro.
- Verificada a composição com itens de menu inseridos por outros mods.
- Adicionado teste de que conquistas secretas permanecem ocultas ao abrir a tela e só revelam título/descrição depois do evento real de desbloqueio.

## 0.4.3 — Testes da interface e limite do launcher

- Ampliado o ambiente de teste para simular os hooks e a navegação real da tela registrada pelo mod.
- Adicionados testes para inserção da opção imediatamente após SAVE e antes de OPTION, preservação das demais entradas do menu e abertura da tela.
- Adicionados testes para filtros, estado vazio, rolagem, detalhes e saída com B/START.
- Documentado que a Portable Mod API 3 pública não fornece atualmente um ponto de registro de páginas para o painel global Extras do launcher; a tela do menu START continua sendo a integração funcional do mod.
- Mantidas todas as alterações no repositório Gen1 Achievements, sem editar o repositório Gen1Recomp.

## 0.4.2 — Validação reforçada dos perfis

- Ampliado o harness para rejeitar perfis com desbloqueios duplicados, IDs inexistentes, registros malformados, versões desconhecidas, contadores inválidos ou incompatíveis com conquistas instantâneas.
- Verificada a rejeição integral de um perfil corrompido, sem aceitar seu prefixo aparentemente válido.
- Verificada a preservação de desbloqueios e progresso parcial quando um perfil válido é regravado.
- Adicionado teste explícito de início de sessão por `save.created`, mantendo o bloqueio até a criação real do save.

## 0.4.1 — Contrato de eventos e validação de payloads

- Adicionado um snapshot do contrato de eventos da Portable Mod API 3, fixado a uma revisão identificável do Gen1Recomp.
- Adicionado verificador para checar disponibilidade por geração, campos usados, tipos comparados e guardas de flags.
- O CI agora falha quando uma conquista depende de um evento, campo ou tipo incompatível com a revisão documentada do motor.
- Documentadas diferenças de payload entre Gen 1, Gen 2 e Gen 3, sem misturar eventos exclusivos de Johto com outras gerações.

## 0.4.0 — Catálogo ampliado e proteção de sessão

- Expandido o catálogo para 17–20 conquistas por jogo, mantendo os onze títulos independentes.
- Adicionados objetivos de Pokédex, evolução, batalhas, insígnias, Campeão e exploração.
- Incluídos os dois circuitos de ginásios em Gold, Silver e Crystal.
- Incluídos Bug-Catching Contest, Unown, Apricorns, ovos, amizade e Pokérus nos jogos que possuem essas mecânicas.
- Incluídos os Regis, Pokémon errantes, fitas, puzzles de braille, Sky Pillar e Seafloor Cavern em Ruby, Sapphire e Emerald.
- Incluído o pós-jogo normal das Ilhas Sevii, sem exigir tickets ou distribuição limitada.
- Adicionados os operadores `one_of`, `one_of_true` e `ends_with` para espécies, transições de flags e identificadores de mapas.
- O processamento pausa durante `save.loading` e só recomeça após `save.loaded` ou `save.created`.
- Perfis locais agora validam IDs e contadores contra o catálogo e regravam perfis legados no formato 2 após a próxima atualização persistida.
- Documentado o modelo de integridade e seus limites: não é uma assinatura criptográfica contra quem modifica o próprio mod/cache.
- Adicionado validador de eventos por geração e limites de 17–20 conquistas por título.
- Adicionado harness de runtime que percorre as 205 definições do catálogo através do `main.lua` e verifica sessão, correspondência, deduplicação, isolamento de perfis, migração legada e falhas de gravação.
- GitHub Actions passou a executar o validador, a verificação de sintaxe LuaJIT e o harness de runtime em cada push para `main`.

## 0.3.0 — Primeira rodada de conquistas

- Inserida a opção Achievements / Conquistas / Logros no menu START antes de OPTIONS.
- Registrada uma tela própria compatível com a Portable Mod API 3 nas três gerações.
- Adicionados filtros All / Unlocked / Locked e visualização de detalhes.
- Implementados objetivos instantâneos e contadores incrementais a partir de eventos.
- Adicionada persistência local por título, independente dos saves, por meio de `mod.cache`.
- Adicionada notificação visual após desbloqueios persistidos.
- Mantida a seleção de idioma English / Português (Brasil) / Español.
- Adicionadas 11 conquistas iniciais, uma por jogo, com traduções nos três idiomas.
- Adicionado suporte a campos de evento aninhados, como `mon.species`.
- Corrigida a composição do hook do menu START para preservar entradas inseridas por outros mods.
- Adicionado CI para validar o catálogo e a sintaxe LuaJIT.

## 0.1.0–0.2.0 — Fundação e console

- Criado manifesto Portable Mod API 3 com os onze jogos.
- Implementada a seleção de idioma no launcher.
- Criada a tela de conquistas, filtros, detalhes, progresso e notificações.
- Definido o armazenamento local por título.

- Corrigidos os filtros de entrada em mapa para comparar sufixos estáveis, evitando depender do prefixo de Gen 3.
- Removida uma conquista duplicada de Marowak em cada título de Kanto e adicionada a captura de Snorlax como objetivo separado.
