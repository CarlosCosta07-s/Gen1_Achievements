## 0.5.22 — Distribuição unificada do mod

- Removido o pacote independente Fullscreen Fit do fluxo de distribuição; o ajuste de viewport já faz parte de `main.lua` e do ZIP principal do Gen1 Achievements.
- O pacote público contém somente o mod completo e seu checksum, sem induzir a instalação de um segundo mod para ajustar a tela.
- A validação do viewport continua integrada ao runtime harness, incluindo proporções 10:9 e 3:2, desktop, Android retrato/paisagem, DPI e viewports compostos.
- Mantida a opção Fullscreen/Borderless nativa do Gen1Recomp para remover a moldura da janela do sistema no PC.

## 0.5.21 — Tipografia legível e ajuste de tela integrado

- Integrado ao Gen1 Achievements o ajuste de viewport antes fornecido apenas pelo addon separado; a instalação do mod principal agora basta para usar a maior área disponível.
- Preservadas as proporções nativas: 10:9 em Gen 1/2 e 3:2 em Gen 3, com centralização, respeito a DPI e sem esticar sprites ou cenários.
- Mantidos os controles virtuais em coordenadas da janela inteira, fora da área redimensionada.
- Substituída a tipografia decorativa do corpo da interface GBA por fontes sem serifa maiores, mantendo Plain Pixel apenas no título e no nome do jogo.
- Movido o progresso de conquistas incrementais para a faixa de status, limitado o texto de descrição a três linhas e reposicionado o rodapé para evitar cortes na borda inferior.
- Ampliado o runtime harness para validar viewport de desktop, Android retrato/paisagem, DPI, viewports compostos, tamanhos de fonte, quebra de linha, largura e limites verticais.

## 0.5.20 — Correção de sobreposições na interface de conquistas GBA

- Substituída a fonte única de 15 px por uma hierarquia Plain Pixel com tamanhos próprios para cabeçalho (15), nome do jogo (11), resumo/rodapé (8), filtro/status (9), lista/título de detalhe (10) e descrição (9).
- Reposicionados nome do jogo, progresso, barra, filtros e lista para manter separação vertical no canvas de 240×160.
- A lista mantém cinco entradas com linhas de 12 px e texto de 10 px, evitando que as conquistas se sobreponham.
- A tela de detalhes agora reserva quatro linhas para a descrição, com contador e comando de retorno em áreas separadas, todos dentro da moldura.
- Largura e quebra de linha são calculadas pela instância específica da fonte de cada área.
- Ampliado o runtime harness para verificar tamanhos de fonte, filtragem nearest, medidas, largura máxima e limites verticais nos cinco jogos de Gen 3 e nos três idiomas.

## 0.5.19 — Addon Fullscreen Fit com proporção preservada

- Adicionado o addon independente Fullscreen Fit — Aspect Ratio em `addons/fullscreen_fit`, usando exclusivamente o hook público `render.viewport` da Portable Mod API 3.
- O addon maximiza o retângulo de jogo disponível sem deformar a imagem: 10:9 para Gen 1/2 e 3:2 para Gen 3.
- O enquadramento fica centralizado, com barras laterais ou superior/inferior quando a proporção da janela não corresponde à do jogo, sem cortar a área de jogo.
- O cálculo considera DPI físico, orientação retrato/paisagem e retângulos de viewport fornecidos por outros mods; pedidos de composição `capture` são preservados.
- Os controles virtuais continuam em coordenadas da janela inteira e não são encolhidos com a imagem do jogo.
- Criados testes sem ROM para desktop, Android retrato/paisagem, alta densidade de pixels, viewport composto e fallback de gerações desconhecidas.
- A validação CI agora verifica a sintaxe LuaJIT e executa o harness do addon.
- A publicação passa a anexar um ZIP autônomo do Fullscreen Fit e seu checksum SHA-256, separado do pacote Gen1 Achievements.

**Limite:** o addon maximiza a área de jogo dentro da janela disponível. No PC, a troca da própria janela para Fullscreen/Borderless continua sendo controlada pelo modo de vídeo nativo do Gen1Recomp.

## 0.5.18 — Objetivos de assinatura por jogo e texto GBA com métricas reais

- Adicionadas onze conquistas de assinatura, uma para cada título: Electabuzz em Red, Magmar em Blue, progressão do Pikachu parceiro em Yellow, Mankey em Gold, Delibird em Silver, Battle Tower em Crystal, Wooper em FireRed, Slowpoke em LeafGreen, Zangoose em Ruby, Seviper em Sapphire e entrada na Battle Tower da Battle Frontier em Emerald.
- O catálogo passa a ter 216 conquistas, com 19–20 por jogo e condições exclusivas entre os onze objetivos de assinatura.
- A tela de conquistas de Gen 3 agora calcula quebra de linhas e truncamento usando a largura real da fonte Plain Pixel ativa, em vez das métricas herdadas da fonte de tiles de Game Boy.
- O truncamento respeita sequências UTF-8, preservando caracteres acentuados em Português e Espanhol.
- Reorganizada a lista GBA com espaçamento vertical adicional para manter cinco linhas e o rodapé separados dentro do canvas de 240×160.
- O validador agora exige a presença e a condição esperada de cada objetivo de assinatura e falha caso duas versões compartilhem a mesma condição de assinatura.
- O runtime harness verifica o orçamento de largura da tipografia GBA nos três idiomas e nos cinco jogos da terceira geração.

## 0.5.17 — Texto nítido na tela de conquistas da Gen 3

- Substituída a fonte padrão do LÖVE em 8 px pela fonte Plain Pixel incluída no motor, carregada no tamanho de projeto de 15 px.
- Aplicados hinting mono, escala DPI 1 e filtro nearest para preservar a grade de pixels no canvas GBA de 240×160 e evitar a suavização do texto.
- Restaurada a fonte gráfica anterior depois de desenhar a tela para não alterar a tipografia de outras telas.
- Ampliado o runtime harness para verificar a fonte, o tamanho, o hinting, a escala DPI e os filtros nos cinco jogos da terceira geração.

## 0.5.15 — Correções de interface móvel e tela de conquistas

- Corrigida a cor de texto da tela de conquistas: após desenhar o painel branco, o mod define texto preto e restaura o estado gráfico anterior; falhas de desenho são isoladas e registradas.
- Encurtado o item do menu START para rótulos localizados que cabem na coluna nativa: ACHV., CONQ. e LOGR.; a tela mantém o título completo.
- Reservada margem direita no menu de batalha para evitar sobreposição pelo controle virtual B em telas móveis.
- Ajustado o dimensionamento dos títulos, instruções, nomes dos golpes, tipos e PP pelas métricas reais da fonte disponível.
- Ampliado o runtime harness para verificar contraste, restauração da cor, rótulo compacto, margem segura e ajuste do texto em português.

## 0.5.14 — Destaque do alvo selecionado e release pública

- Adicionado um contorno claro e uma faixa interna ao cartão de alvo atualmente percorrido pelo cursor.
- Preservada a apresentação de HP, condições de estado e papéis dos battlers; o destaque acompanha o cursor sem alterar os IDs nativos enviados ao motor.
- Documentada a limitação da API pública: ela expõe battlers presentes, mas não uma lista completa de alvos permitidos por golpe; nenhum alvo é rotulado como indisponível por suposição.
- Adicionado fluxo de publicação que só cria a release pública após a validação da branch main concluir com sucesso.
- O pacote de release inclui manifest, código, dados, documentação, ZIP instalável e checksum SHA-256.

## 0.5.13 — Indicadores de condições de estado

- Adicionados indicadores compactos de estado aos cartões de alvo para SLP, PSN, BRN, FRZ, PAR e TOX, usando valores normalizados pela API pública.
- Diferenciadas as condições por cores; o nome do Pokémon e o marcador de papel continuam visíveis.
- Ignorados estados desconhecidos ou ausentes, sem inferir condições a partir do HP.
- Ampliado o runtime harness para validar os seis estados reconhecidos e a ausência de indicadores para valores desconhecidos.

## 0.5.12 — HP visual dos alvos em batalha

- Adicionadas barras compactas de HP aos cartões de alvo quando a API pública fornece HP atual e máximo válidos.
- Reservado espaço adicional somente quando existe ao menos um alvo com HP observável; os cartões preservam nome e marcador de papel sem comprimir o texto.
- Mantidos o cursor, os IDs nativos e a validação de seleção inalterados; HP dos alvos é apenas informação visual.
- Ampliado o runtime harness para testar alvos esparsos, proporções diferentes, HP zero, dados ausentes/inválidos e preservação do envio do ID nativo.

## 0.5.11 — Indicador de HP do combatente ativo

- Exibidos HP atual, HP máximo e uma barra compacta para o Pokémon que está comandando em batalhas duplas, usando somente os dados da API pública.
- Mantido o cabeçalho anterior quando os campos de HP estão ausentes ou inválidos; valores são limitados ao intervalo válido e nunca alteram o estado da batalha.
- Adicionados testes de renderização para os valores do HP, proporção da barra e fallback de dados inválidos.

## 0.5.10 — Feedback de alvos rejeitados

- Exibido no painel o motivo localizado quando a API nativa rejeita a seleção do próprio Pokémon como alvo.
- Adicionado aviso genérico localizado para outras rejeições da API, com expiração por atualização do jogo e descarte quando prompt/revisão mudam.
- Mantida a autoridade do motor sobre os alvos permitidos; o mod não cria regras ou listas próprias por golpe.
- Ampliado o runtime harness para testar os avisos em inglês, português brasileiro e espanhol, a expiração, a rejeição genérica e a recuperação da navegação após uma escolha recusada.

## 0.5.9 — Toque sincronizado com o estado da batalha

- Vinculado cada layout de toque ao prompt e à revisão exatos do snapshot usados para desenhá-lo.
- Descartado e consumido o toque dentro de um painel antigo quando a batalha muda de fase ou revisão antes do próximo frame, evitando que um cartão de alvo seja reinterpretado como golpe (ou vice-versa).
- Mantida a passagem de toques fora do painel para o jogo e preservada a captura do ponteiro até o evento de liberação/cancelamento.
- Ampliado o runtime harness para cobrir mudança de fase, mudança de revisão no mesmo prompt e aceitação de um novo toque após redesenhar o painel.

## 0.5.8 — Sincronização dinâmica dos alvos e fases

- Identificado no painel o Pokémon ativo que está escolhendo o comando, acompanhando a troca de slot entre as ações da batalha dupla.
- Diferenciados visualmente o combatente ativo, o parceiro e os adversários nos cartões de seleção de alvo.
- Preservados os IDs nativos dos alvos, inclusive quando a lista é esparsa; a fase de equipe e a troca de Pokémon continuam sob controle do jogo.
- Adicionadas traduções dos novos indicadores em inglês, português brasileiro e espanhol.
- Preservada a seleção pelo ID nativo quando a lista de alvos muda dentro do mesmo prompt; se o battler selecionado desaparece, o cursor recorre ao alvo nativo atual ou a um índice válido.
- Vinculada cada entrada ao prompt e à revisão capturados pelo hook; o comando é descartado se qualquer um mudar antes da submissão, inclusive quando o prompt permanece igual.
- Ampliado o harness para testar alvos que desaparecem, mudanças de revisão e descarte de intenções quando o motor avança de fase.

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
