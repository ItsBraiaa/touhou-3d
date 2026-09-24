# Guardiã dos Ventos — roteiro de apresentação

**Duração:** 10 minutos, incluindo demonstração.  
**Formato:** um bloco `Slide` por página no Canva, PowerPoint ou PDF. Use o texto de **Na tela** como conteúdo visual e **Fala** como notas do apresentador.  
**Estado do projeto consultado:** 24/09/2026, branch `dev-01` em `f2c0fb3`. O título do projeto Godot e do executável ainda é **Touhou-3D**; *Guardiã dos Ventos* é o título de trabalho do jogo.

> **Ideia central:** explicar primeiro o jogo 2D que inspirou o projeto e suas regras. Depois mostrar o que foi preservado, o que mudou ao levar a ação para 3D e como o jogo foi produzido. O projeto cria mundo, fases e chefes próprios; não reproduz uma fase oficial de Touhou.

## Slide 1 — O projeto (0:20)

**Na tela**

- **Guardiã dos Ventos**
- Uma adaptação do bullet hell 2D para voo livre em 3D
- Projeto em Godot 4 · Bryan / equipe: **[preencher nomes reais]**

**Fala** — “Vou começar pelo jogo que inspirou a mecânica e depois mostrar nossa versão, as decisões de design, a construção no Godot e o resultado jogável.”

**Visual** — Captura própria da nave diante da Floresta das Lanternas; inserir nomes e curso reais. Material já registrado: [entrada da floresta](validation/stage-01-entrance.png) e [nave em voo](validation/player-flight-bank.png).

## Slide 2 — O jogo original e o gênero (0:55)

**Na tela**

- **Touhou Project**: referência de jogos de tiro com padrões densos de projéteis (*danmaku* ou *bullet hell*).
- **Touhou 10: Mountain of Faith** (2007): exemplo concreto da série usado nesta apresentação.
- Em 2D, a personagem se move na tela, atira, evita padrões e enfrenta chefes por fases.

**Fala** — “Escolhemos Touhou como referência pela leitura dos padrões de tiros: o jogador vê o desenho dos projéteis, identifica uma abertura e se posiciona nela. *Mountain of Faith* é um exemplo do jogo original para explicar isso. Nosso projeto usa essa linguagem de combate, com cenário e campanha próprios.”

**Visual** — Uma imagem autorizada/creditada do jogo original ao lado de uma captura própria do projeto. **Não usar** arte promocional do nosso menu como se fosse captura de uma fase. 

**Base:** [página oficial do jogo, ZUN](https://www16.big.or.jp/~zun/html/th10top.html); [manual oficial: regras básicas](https://www16.big.or.jp/~zun/html/th10man/html/rule.html); [página do jogo na Steam](https://store.steampowered.com/app/1100140/).

## Slide 3 — Como funciona o original (0:55)

**Na tela**

1. **Mover e desviar:** atravessar espaços entre projéteis.
2. **Atirar e focar:** disparo contínuo; foco reduz a velocidade para ajustes precisos.
3. **Coletar poder:** itens fortalecem o ataque.
4. **Usar o ataque especial:** uma saída para momentos de alto risco.
5. **Ler o chefe:** ataques organizados em padrões reconhecíveis.

**Fala** — “O desafio não é apenas reagir rápido. É aprender o padrão e escolher por onde passar. No *Mountain of Faith*, o ataque especial está ligado ao poder da personagem. No nosso jogo, a bomba usa cargas separadas. Essa é uma adaptação deliberada, não uma cópia exata das regras.”

**Visual** — Um frame do original com setas simples: personagem, abertura no padrão, projéteis e chefe. Fazer as anotações sobre uma captura com fonte identificada.

**Base:** [manual oficial: controles](https://www16.big.or.jp/~zun/html/th10man/html/controll.html), [ataque](https://www16.big.or.jp/~zun/html/th10man/html/rule2.html) e [itens](https://www16.big.or.jp/~zun/html/th10man/html/rule3.html).

## Slide 4 — A pergunta de design: como levar isso para 3D? (0:55)

**Na tela**

| No Touhou 2D | Em Guardiã dos Ventos |
| --- | --- |
| Desvio em uma tela plana | Desvio em largura, altura e profundidade |
| Visão fixa da ação | Câmera atrás da nave |
| Inimigos à frente | Alvos ao redor; trava de alvo e auxílio de mira |
| Padrões desenhados no plano | Anéis, leques e espirais em volumes 3D |

**Fala** — “A maior mudança foi dar liberdade de altitude e distância sem perder a leitura dos tiros. Por isso a câmera acompanha a nave, a mira ajuda a manter o combate legível e os chefes atacam em alturas diferentes. Voar simplesmente por cima não deve resolver a luta.”

**Visual** — Diagrama simples com eixos X/Y/Z ou duas capturas próprias do mesmo ataque em alturas diferentes.

**Base interna:** [planejamento, conceito e câmera](PLANEJAMENTO.md), [design de fases](STAGE_DESIGN.md), [validação dos padrões](validation/stage-02-pacing.md).

## Slide 5 — O nosso jogo: proposta e campanha (0:55)

**Na tela**

- Uma guardiã investiga uma névoa que alterou os espíritos da região.
- **Fase 1 — Floresta das Lanternas:** aprende a voar, lutar e abrir o portal; enfrenta o Guardião das Lanternas.
- **Fase 2 — Montanha da Tempestade:** desfaz três selos, enfrenta um miniboss e chega ao Guardião da Tempestade.
- Campanha em sequência ou seleção direta de fase.

**Fala** — “Criamos uma história e dois percursos próprios. A primeira fase apresenta os controles e mistura inimigos aos poucos. A segunda exige mais decisões de rota: os três selos podem ser concluídos em qualquer ordem antes do miniboss e do chefe final.”

**Visual** — Duas capturas próprias: [entrada da floresta](validation/stage-01-entrance.png) e [bacia da montanha](validation/stage-02-basin-player.png). Evitar usar somente as ilustrações do menu como prova das fases.

**Base interna:** [planejamento das fases](PLANEJAMENTO.md), [progressão da Fase 2](validation/stage-02-progression.md).

## Slide 6 — Mecânicas que o jogador usa (1:05)

**Na tela**

- Voo livre, foco para precisão, trava de alvo e disparo contínuo.
- **Escudo:** absorve um golpe; **bomba:** abre espaço e causa dano.
- Itens de poder melhoram o disparo e acrescentam familiares que atiram.
- **Graze:** passar perto de um projétil sem ser atingido rende pontos.
- Checkpoints permitem retomar o percurso; o HUD mostra o essencial.

**Fala** — “Em 3D, o jogador decide não só esquerda e direita, mas também altura e distância. O escudo dá uma chance extra; a bomba é um recurso limitado para sair de situações difíceis. Ao coletar poder, aparecem familiares de apoio. O graze recompensa a aproximação arriscada. Aqui ele faz parte da nossa adaptação do gênero; não estou dizendo que copiamos um contador específico de *Mountain of Faith*.”

**Visual** — [HUD em jogo](validation/hud-normal.png), [bomba em combate](validation/combat-bomb.png) e uma onda de projéteis. Se houver vídeo, mostrar uma bomba e uma subida para atravessar um anel.

**Base interna:** [regras de combate](PLANEJAMENTO.md), [validação de combate](validation/combat.md), [HUD](validation/combat-hud.md).

## Slide 7 — Como desenhamos as fases (0:55)

**Na tela**

**Floresta:** espíritos → sentinelas → portal → checkpoint → chefe.  
**Montanha:** subida → combate cruzado → três selos → miniboss → chefe.  
Portais abrem após objetivos; checkpoints preservam o progresso do trecho.

**Fala** — “Os cenários não são apenas decoração. Eles indicam o caminho, colocam inimigos em alturas diferentes e controlam a progressão. As barreiras impedem pular o combate voando por cima. Os checkpoints restauram recursos e evitam recomeçar tudo a cada derrota.”

**Visual** — Um mapa resumido em duas linhas com ícones de encontro, portal e checkpoint; usar [portal da floresta](validation/stage-01-portal.png) e [montanha](validation/stage-02-basin-player.png) como fundo discreto.

**Base interna:** [especificação de progressão](STAGE_DESIGN.md), [validação da Fase 1](validation/stage-01-progression.md), [validação da Fase 2](validation/stage-02-progression.md).

## Slide 8 — Como produzimos o jogo (1:10)

**Na tela**

1. **Pesquisa e escopo:** requisitos da atividade, referências e duas fases jogáveis.
2. **Protótipos e design:** nave, câmera, arenas, inimigos, chefes e interface.
3. **Implementação:** regras de combate, projéteis, progressão e salvamento temporário nos checkpoints.
4. **Integração e ajuste:** cenas, modelos, efeitos, áudio, padrões e dificuldade.
5. **Validação e entrega:** execução completa das fases, exportação e pacote.

**Fala** — “Começamos pelos requisitos e pelo desenho das duas fases. Construímos a nave, os cenários e os marcadores de encontros no Godot; a programação conectou voo, tiros, inimigos, checkpoints e menus. Um desafio foi mostrar muitos projéteis sem perder desempenho: usamos um campo de projéteis e renderização por MultiMesh. Outro foi tornar a altura importante, então distribuímos inimigos e ataques em níveis diferentes e ajustamos a câmera e a mira. Por fim, revisamos efeitos, dificuldade, progressão e créditos dos recursos antes de exportar.”

**Visual** — Linha do tempo com uma captura de protótipo/arena, uma do editor Godot e uma do build. **Não atribuir todo o trabalho a Bryan** antes de preencher a participação real de cada integrante.

**Base interna:** [roadmap](engineering/ROADMAP.md), [convenções e arquitetura](engineering/CONVENTIONS.md), [campo de projéteis](engineering/projectile-field.md), [renderização](engineering/weapon-rendering.md), [créditos dos recursos](ASSET_CREDITS.md), [exportação](validation/export.md).

## Slide 9 — Resultado e evidências (0:45)

**Na tela**

- Duas fases, chefes próprios, menus e interface em português.
- Build Windows executado fora do editor no computador de desenvolvimento.
- Campanha e seleção direta concluídas em verificações automatizadas.
- **Ainda medir:** uma partida real da Fase 2 para confirmar os 5 minutos exigidos.

**Fala** — “O fluxo completo chegou à vitória nos testes automatizados, e o executável abriu fora do editor. O registro técnico aponta cerca de 59 a 60 quadros por segundo nas lutas de chefe no computador de desenvolvimento. Há uma medida que eu não vou afirmar como concluída: a duração de cinco minutos da segunda fase depende de uma partida real, sem pausas ou tentativas descartadas. Também falta registrar a execução no computador da apresentação.”

**Visual** — Tela real de resultados e um pequeno quadro de evidências; substituir números somente depois de medi-los. A [captura de resultado existente](validation/run-flow-results.png) marca **0:03 em uma execução automatizada** e não serve como prova de duração jogada.

**Base interna:** [aceitação](validation/acceptance.md), [tempo de fase](validation/clear-time.md), [exportação e desempenho](validation/export.md).

## Slide 10 — Demonstração guiada (1:35)

**Na tela**

**Assistir a:** voo em três eixos → foco e tiro → padrão de projéteis → bomba → chefe/resultado.

**Fala durante o jogo** — “Aqui a nave sobe e desce, e a câmera acompanha. Vou travar o alvo, desviar pelo espaço entre os tiros e usar uma bomba para abrir uma passagem. Este ataque do chefe alterna alturas: a rota de fuga muda conforme a posição da nave.”

**Roteiro prático**

1. Abrir uma fase já escolhida ou uma gravação local de 60–75 segundos.
2. Mostrar subida/descida e travamento em um alvo.
3. Mostrar uma onda visível, foco e bomba.
4. Encerrar em chefe ou na tela de resultados, conforme o tempo.

**Plano de reserva** — Levar um vídeo próprio gravado do build. Se a demonstração ao vivo demorar, reproduzir o vídeo e manter a mesma explicação.

## Slide 11 — Encerramento (0:25)

**Na tela**

**Do desvio em 2D à navegação em 3D.**  
Padrões legíveis, liberdade de movimento e campanha original.

**Fala** — “O principal aprendizado foi preservar a sensação de ler e atravessar padrões enquanto criávamos combate, câmera e fases que realmente usam o espaço 3D. Obrigado.”

## Antes de transformar em slides

- [ ] Preencher nomes da equipe, curso, disciplina e participação real de cada pessoa.
- [ ] Capturar imagens **do jogo rodando**: Floresta, Montanha, chefe, HUD e Resultados. Colocar “Touhou 10: Mountain of Faith — ZUN / Team Shanghai Alice” junto à imagem do original.
- [ ] Fazer uma partida eficiente, sem morte, da Fase 2 e registrar o **Tempo** da tela de resultados. Só afirmar “cumpre 5 minutos” se essa partida chegar a **5:00 ou mais** de tempo ativo. [Protocolo de medição](validation/clear-time.md).
- [ ] Testar o build no computador da apresentação, o controle/teclado reais e os efeitos sonoros. [Pendências registradas](validation/acceptance.md).
- [ ] Gravar o vídeo reserva e cronometrar a fala. O roteiro soma **9:55**; reservar cinco segundos para troca de slides.

## Fontes principais

**Jogo original:** [site oficial de *Mountain of Faith*](https://www16.big.or.jp/~zun/html/th10top.html), [manual oficial — regras](https://www16.big.or.jp/~zun/html/th10man/html/rule.html), [controles](https://www16.big.or.jp/~zun/html/th10man/html/controll.html), [ataque](https://www16.big.or.jp/~zun/html/th10man/html/rule2.html), [itens](https://www16.big.or.jp/~zun/html/th10man/html/rule3.html).  
**Nosso projeto:** [planejamento](PLANEJAMENTO.md), [design de fases](STAGE_DESIGN.md), [roadmap](engineering/ROADMAP.md), [aceitação](validation/acceptance.md), [créditos de recursos](ASSET_CREDITS.md).
