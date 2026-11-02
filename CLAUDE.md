# Total Football — contexto do projeto

Jogo 2D de futebol americano arcade inspirado em **Tecmo Super Bowl III**. Godot 4.7.2, GDScript, arte no LibreSprite 1.3.
Repositório público: https://github.com/joaorodrigues1994/total-football (branch `main`). Idioma de trabalho: **português**.

## Regras de trabalho com o usuário (obrigatórias)
- **Pergunte antes de executar ações e não implemente nada sem autorização explícita.** Dúvidas e ajustes que precisem de decisão: informe e espere.
- **Não invente mecânicas** que o usuário não descreveu; se uma correção exigir comportamento novo, avise claramente (ex.: cobertura de passe da defesa foi adicionada a pedido, mas é simples).
- Priorizar **jogabilidade** (arcade, simples, responsivo). Código **modular**. Multiplayer só *preparado* (não implementado).
- Commits terminam com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Autor git: `jpaulo <jpaulo.rodrigues@hotmail.com>` (a máquina não tem identidade global: use `git -c user.name=jpaulo -c user.email=jpaulo.rodrigues@hotmail.com commit ...`). `gh` está em `C:\Program Files\GitHub CLI\gh.exe`.
- Imagens `referencia_*.jpg` e a pasta `reference/` são só referência visual do Tecmo: estão no `.gitignore`, **nunca commitar**.
- Para arquivos grandes use a ferramenta Write (heredocs bash com aspas quebram). Arquivos `.gd` usam **tabs**.

## Controles
- **Menu de jogadas** (entre jogadas de scrimmage e conversão de 2 pontos; kickoff e extra point não têm menu): **Direcional + A** = corrida / defesa contra corrida; **Direcional + S** = passe / defesa contra passe (Cima, Baixo, Esquerda, Direita = jogadas 1 a 4). No 4º down o ataque também tem **P** (punt) e **G** (field goal). **T** = timeout do humano (só no menu: consome 1 dos 3, reinicia o play clock).
- Depois do menu: no ataque **A** dá o snap; na defesa **A** troca de jogador (esquerda→direita, linha, LBs, backs) e trava no snap (a CPU dá o snap após 5 s). Extra point: A chuta, Baixo+A = conversão de 2 pontos.
- Durante a jogada: direcionais = movimento; **S** = juke (corredor) / troca de recebedor (QB); **D** = pulo (corredor) / lançar (QB).
- Teclas temporárias de debug: **R** (reseta a formação), **Y** (troca a posse; vale no menu e antes do snap).

## Como rodar e testar
- Godot em `Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe` (pasta ignorada pelo git). Cena principal `scenes/main.tscn`, viewport 512x448, stretch inteiro.
- Depois de criar `class_name` novos: `... --headless --path . --import` (senão a classe não é reconhecida).
- Testes são scripts headless descartáveis (`extends SceneTree`): `... --headless --path . -s teste.gd`. Instancie `main.tscn`, pegue `Match`, use `m.rules.start_drive(0, 30.0)`, `m._setup()`, `m._start_play()`, `await physics_frame`. **Limitação conhecida:** `Input.action_press("ui_left")` + `btn_a` não faz o jogo ler "passe" no headless; chame `m._start_play()` com `ui_left` pressionado.
- Captura de quadro: `--write-movie`. Sprites: `python tools/gen_player_sprites.py` (gera os PNG em `assets/sprites/`) e depois `libresprite.exe -b in.png --save-as out.aseprite` (LibreSprite em `C:\Program Files\LibreSprite`).

## Arquitetura (scripts/)
- **Física plana, apresentação à parte:** a perspectiva inclinada do campo é só visual (`field/field_perspective.gd`, `project_x`); sprites são deslocados em `_process`. Regras e física não conhecem a perspectiva.
- `rules/game_rules.gd` (`GameRules`, RefCounted): posse, downs, jardas, placar, relógio NFL (4 quartos de 2 min), chutes (`roll_kick_yards`, `field_goal_chance`), conversões, `rng`. Sequência pós-jogada via `Next {SCRIMMAGE, KICKOFF, EXTRA_POINT, TWO_POINT, FREE_KICK}`; `end_play/end_return/end_kick_without_return/end_field_goal/end_extra_point/end_two_point`.
- `rules/play_clock.gd` (`PlayClock`): play clock de 25 s independente da interface (`start/stop/tick`). `GameRules` também tem `delay_of_game()` (−5 jd, down repete, linha de first down não muda; perto da própria goal line perde só metade da distância), `use_timeout(team)` e `timeouts` (3 por time, renovados no 3º quarto).
- `rules/field_constants.gd`: jardas↔pixels (`PX_PER_YARD` = 12), endzones, largura do campo.
- `match/match.gd` (`Match`, arquivo central): máquina de estados `State {PLAY_SELECTION, PRE_SNAP, SNAP, HANDOFF, DROPBACK, PASSING, FLIGHT, KICK_FLIGHT, RUNNING, DEAD}`, `PlayKind {SCRIMMAGE, PUNT, FIELD_GOAL, KICKOFF, EXTRA_POINT}`, `Side`, `HUMAN_TEAM := 0`. `_setup()` monta formação/IA/câmera; `_start_play`; passe (`_throw`, `PassFlight`); chutes (`_launch_kick`, `_resolve_kick`, `_start_return`, que troca `offense`/`defense` e `attack_dir`); `defender_target(player)` diz para onde cada IA vai; tackles (`_check_tackles`, `TACKLE_RADIUS`); `offense_play`/`defense_play` guardam as jogadas escolhidas no menu (itens do `Playbook`). Fluxo: `_setup()` abre `PLAY_SELECTION` (menu + play clock) em jogadas de scrimmage/2 pontos; `_update_selection` lê Direcional+A/S, P/G e T; quando ataque e defesa têm escolha (a CPU escolhe na hora; o humano tem 25 s) `_confirm_selection()` vai para `PRE_SNAP` (ou direto para a formação de punt/FG). `_start_play` usa `offense_play["type"]` para decidir corrida/passe.
- `match/block_system.gd` + `match/block_link.gd` + `plays/block_schemes.gd`: **sistema de bloqueio** (ver abaixo).
- `plays/formation.gd` (formações em jardas relativas à bola; roles `LT LG C RG RT TE QB RB WR1-3`, defesa `LDE LDT RDT RDE LOLB MLB ROLB LCB RCB FS SS`; chutes: `K` chutador, `R` retornador, `C1..C10` cobertura, `B1..B10` time que recebe), `plays/routes.gd` (`PASS_TEST`, `TARGET_ORDER`).
- `plays/playbook.gd` (`Playbook`): 8 jogadas ofensivas e 8 defensivas (dados puros). Ataque: Corrida 1 MIDDLE, 2 SWEEP R, 3 SWEEP L (espelho), 4 RIGHT GAP; Passe 1 SHORT, 2 MEDIUM, 3 DEEP, 4 MIX (rotas antigas `PASS_TEST`); cada uma aponta um esquema de `BlockSchemes` (`mirror` espelha) e, nos passes, as rotas. Defesa: contra corrida BASE, FULL BOX, CONTAIN L/R (`hold` = quem espera o portador cruzar a linha); contra passe RUSH 4, LB BLITZ, RUSH 3, BIG BLITZ (`rush` = quem ataca o QB; o resto acompanha o recebedor mais próximo). `ai/cpu_play_caller.gd`: CPU ataque sorteia entre as 8 (4º down: lógica de chute de antes); CPU defesa sorteia contra passe, e contra corrida em 2º down com ≤2 jardas. A CPU no ataque lança após 1,8 s no bolso para o recebedor mais livre (`Match._cpu_pass`). `ui/play_menu.gd`: painel do menu.
- `entities/player.gd` (`CharacterBody2D`): `input_dir` (decidido por humano ou IA), `Action {NONE, JUKE, DIVE, DOWN}`, `speed_scale`, `shove` (empurrão externo somado ao movimento), `block_pose`, `tackle_cooldown`, `knock_down()`. `player_attributes.gd`: `speed, acceleration, strength, agility, receiving, pass_accuracy, hitting_power` (1–100) + `for_role(role)` com HP base por posição. `player_sprites.gd`: monta `SpriteFrames` do spritesheet 24x24. `break_effect.gd`: estouro curto ao romper bloqueio. `ball.gd`, `control_marker.gd` (o "P" do jogador controlado), `target_marker.gd` (triângulo do recebedor).
- `ai/defender_ai.gd` (vai ao alvo de `defender_target`), `ai/route_runner.gd` (recebedores seguem rotas). `input/human_controller.gd` + `input_setup.gd` (ações criadas por código). `camera/match_camera.gd`, `field/field.gd`, `ui/scoreboard.gd` (placar compacto no topo, banner e telas de fim de quarto/jogo; substituiu o `DebugHud`).

## Sistema de bloqueio (estilo Tecmo)
- Cada jogada tem um **esquema** em `BlockSchemes.SCHEMES`: `run_middle`, `run_outside`, `pass_short`, `pass_long` (por posição: `target` preferido, `start`, `duration` = limite de segurança, `drive` = direção de empurrão no referencial do ataque) e `kick_return`/`punt_return` (`rank_match`: cada bloqueador marca um jogador da cobertura na mesma ordem lateral).
- `BlockSystem.begin(esquema, bloqueadores, defensores, dir)` cria um `BlockLink` por bloqueador. Estados: `MOVING_TO_TARGET, ENGAGING, BLOCKING, FIGHTING_BLOCK, LOSING_BLOCK, BLOCK_BROKEN, RECOVERING`.
- **Engaja por contato** (≤17 px) com qualquer defensor livre. Engajados, os dois ficam parados (defensor com `speed_scale = 0`) até o defensor romper; só então ele volta a perseguir. Defensor travado (ENGAGING/BLOCKING) não dá tackle.
- A cada 0,3 s há uma disputa: `grip += clamp(edge, ±40) * GRIP_PER_POINT − GRIP_DECAY`, com `edge = score(bloqueador) − score(defensor)` e `score = hitting_power + 0.25*strength ± sorte`. `grip ≤ 0` = rompe (defensor livre por 1,2 s, bloqueador cambaleia com a pose `beaten` e depois procura outro alvo). Constantes de ajuste no topo de `block_system.gd`.
- Nos esquemas com `drive`, o par engajado desliza junto na direção do esquema (abre corredores); os retornos e passes usam drive zero.
- O sistema é criado antes dos jogadores na árvore (atualiza `shove`/`speed_scale` antes de eles se moverem). `Match._block_protect_point()` diz o que proteger (portador, QB ou ponto de queda do chute).
- Retornos: `_begin_return_blocks()` é chamado em `_launch_kick` (kickoff/punt) com o time que recebe (menos o `R`) bloqueando a cobertura (menos o `K`).

## Estado atual (o que já está feito)
Etapas 1–12 concluídas (11 = menu de jogadas; 12 = safety, interceptação, placar final e poses de chute; testadas em headless e por captura de tela, o humano validou o menu): campo com perspectiva e textura, jogadores com sprites estilo Tecmo e poses (largada, stance, ready, juke, dive, caído, bloqueio, derrotado), snap, corrida com handoff (QB sai da frente), passe com troca de recebedor, tackles/sack, downs e placar, relógio NFL, kickoff, punt, field goal, extra point e conversão de 2 pontos, retornador automático do humano até o ponto de queda, câmera deslocada para o lado do ataque, HUD de debug, humano (Time A) vs CPU. Defesa de passe: rushers (DL) vão ao QB; LBs/DBs acompanham o recebedor mais próximo e correm ao ponto de queda com a bola no ar. Bloqueio estilo Tecmo implementado e validado só em headless (feeling na tela ainda não avaliado pelo usuário).

## Pendências / ideias abertas
- Playbooks dinâmicos por time (CPU escolhendo conforme situação e habilidade: bons WRs → passe; bons pass rushers → defesa contra passe e mais pressão), em `CpuPlayCaller`.
- O menu usa fonte padrão e painel provisório (visual final na etapa de interface); a CPU passou a lançar (nova mecânica mínima).
- Ajustar o feeling da corrida pelo meio (safeties e LBs que rompem ainda tacklam perto da linha); força do empurrão, alvos dos esquemas e constantes de `block_system.gd`.
- IA de cobertura mais completa, fumble/bola solta (interceptação e safety já existem), ajustes finos do bloqueio na corrida conforme o feeling do usuário, testes antigos `t8.gd`/`t9.gd` usam controles antigos (Baixo+A = punt etc.) e estão desatualizados.
- Fora do escopo da fase 1: penalidades além do Delay of Game, saída de campo, modos além de amistoso humano vs CPU, times/atributos reais (o `hitting_power` já prepara jogadores bons/ruins de linha), multiplayer.


## Regras da etapa 12 (resumo)
- **Safety:** portador caído atrás da própria goal line (`new_spot <= 0` em `GameRules.end_play`) dá 2 pontos ao adversário; o time que sofreu faz um punt livre da própria jarda 20 (`Next.FREE_KICK`, tratado no `Match` como `PlayKind.PUNT`).
- **Interceptação:** com a bola chegando ao ponto de queda, recebedor e defensor a ≤ `CATCH_RADIUS` disputam por sorteio proporcional ao atributo `receiving` (`Match._defender_wins_ball`); só o defensor perto = intercepta. `Match._intercept` troca a posse reutilizando `_start_return` (+ bloqueadores com o esquema `punt_return`). Não existe fumble.
- **Poses de chute:** `kick` (2 quadros, one-shot, disparada em `_launch_kick`) e `hold` (holder `C1` no FG/extra point). Spritesheet agora tem as linhas block, beaten, kick, hold no fim.

## IA do QB da CPU (melhorias de IA, etapa 2 — aguardando teste manual do usuário)
- `scripts/ai/qb_brain.gd` (`QbBrain`): avalia os recebedores a cada 0,15 s (posição prevista na chegada da bola via `RouteRunner.position_after`, folga para defensores livres, distância, `receiving`), calcula pressão (defensor solto perto) e decide `WAIT / THROW / ESCAPE / SCRAMBLE`. Limiar de lançamento sobe com baixa `pass_accuracy` e cai com pressão; 1,8 s = paciência, 2,2 s = limite duro (menor com pressão). Mobilidade = (agility + speed)/2 para escapar/correr.
- `Match._cpu_pass` chama o cérebro; `_cpu_scramble` faz o QB virar portador (corre em `_scramble_dir`); sack só vale com o QB atrás da linha de scrimmage. Humano inalterado.
- Próximas etapas do pedido de IA: 3 (bloqueios de kickoff/punt), 4 (bloqueios na corrida), 5 (IA do RB/retornador + romper tackle por strength).

## Bloqueio de retorno (melhorias de IA, etapa 3 — aguardando teste manual do usuário)
- `kick_return`/`punt_return` ganharam `tactical` (ignora defensor que passou 24 px do retornador/ponto de queda; escolhe outro alvo), `grip_cap` 0,6 e `extra_decay` 0,03 (domínio limitado e desgastado) e duração 3,5 s. `BlockLink` tem `grip_cap`/`extra_decay`; `BlockSystem._is_relevant`.
- `BLOCKER_HITTING_POWER` (B#) = 50, igual à cobertura (C#); única mudança de valor de atributo autorizada. Esquemas de corrida/passe inalterados (etapa 4).
- O chutador (`K`) continua fora da cobertura bloqueada (último defensor livre).

## Correções pós-etapa 3
- Defesa humana mantém o controle durante o voo do passe e depois da recepção (`_throw` só desliga o `HumanController` quando o humano está no ataque). Antes o jogador controlado seguia com o último input.
- Interceptação: o antigo ataque (nova defesa) recebe `DefenderAI` em `_intercept` e persegue o portador; o time que interceptou bloqueia (`punt_return`).
- QB com a bola além da linha de scrimmage (`_qb_crossed_line`) vira corredor (`_qb_becomes_runner`): sem passe, estado RUNNING, recebedores param a rota e bloqueiam (`BlockSystem.add_blockers`), a defesa inteira o persegue. O scramble da CPU usa o mesmo caminho.
- Campo: linha de scrimmage vermelha e de first down amarela (`Field.scrimmage_x/first_down_x`, definidas por `Match._update_field_lines`; escondidas em chutes, retornos e goal-to-go no first down).

## Etapa 4 — atraso de leitura na defesa contra corrida (aguardando teste manual do usuário)
- `Match._is_reading` / `RUN_READ_DELAY` (0,35 s): em jogadas de corrida, linebackers e secundária da CPU não perseguem durante snap e handoff e por 0,35 s depois que o RB vira portador; a linha defensiva reage na hora. Não afeta passes, retornos, `hold` do playbook nem jogadores humanos.
- Medido com corredor que busca a faixa livre: média de ~0 jardas (tackle em ~1,6 s) → ~2,8 jardas (tackle em ~2,1 s). Tentativas de separação/faixa lateral dos defensores não mudaram as jardas e foram descartadas.

## Etapa 5 — IA do portador da CPU e romper tackle (aguardando teste manual do usuário)
- `scripts/ai/carrier_brain.gd` (`CarrierBrain`): a cada 0,1 s avalia 7 faixas (±65°) à frente, penaliza defensores no caminho (livres pesam mais que bloqueados, com previsão de 0,3 s), mantém a direção escolhida (evita zigue-zague), finta quando um defensor livre chega a 42 px (chance por `agility`) e corta de lado por 0,4 s depois da finta, mergulha a <26 px da goal line com defensor perto e prefere seguir reto para a endzone nos últimos 6 jardas. `strength` = aceita contato (menos peso no risco), `agility` = custo de desviar e chance de finta, `speed` = alcance da leitura. Usado por todo portador da CPU (RB, retornador, interceptador, QB em scramble) em `Match` (`State.RUNNING`).
- **Romper tackle (vale para humano também):** `Match._breaks_tackle` sorteia por força: `BREAK_TACKLE_BASE` (0,15) × 2 × forte/(forte+fraco), teto `BREAK_TACKLE_MAX` 0,4. Quem rompe faz o defensor esperar `MISS_COOLDOWN` e mostra o `BreakEffect`.
- Medido (CPU ataca, defesa BASE): média ~5 jardas por corrida, mediana ~1–5 conforme a jogada (MIDDLE é a mais generosa), com 1 TD de 60 jd a cada ~20–40 corridas.
- Pedido de IA (etapas 1–5) concluído; falta apenas o teste manual do usuário e commit/push.

## IA defensiva — Etapa 2: cobertura de passes (aguardando teste manual do usuário)
- `scripts/ai/pass_coverage.gd` (`PassCoverage`): no snap de passe (`Match._start_play`) cada defensor fora do `rush` recebe um recebedor (pares mais próximos primeiro, um defensor por recebedor); sobras viram ajuda em profundidade (36 px atrás do recebedor mais profundo). A cada 0,4 s dois defensores trocam de marcação se isso encurta a soma das distâncias (`tick`).
- O defensor mira onde o recebedor estará: `posição + velocity * lead` (lead 0,15–0,45 s conforme `agility`) com colchão de 8 px para o fundo do campo. Com a bola no ar só vai ao ponto de queda quem é o marcador do alvo ou chega a tempo (`max_speed_yards`); os demais mantêm a marcação. Rushers continuam indo ao ponto de queda. `Match._coverage` (`clear()` a cada jogada).
- Medido (14 passes vs RUSH 4): no máximo 1 defensor por recebedor (antes até 3), 12 completos, 1 sack, 1 incompleto; folga mínima ao recebedor ~12–14 px. Não há desvio de passe (exigiria autorização).

## IA defensiva — Etapa 3: defesa contra corrida (aguardando teste manual do usuário)
- `scripts/ai/run_pursuit.gd` (`RunPursuit.target`), usado em `Match.defender_target` no estado `RUNNING` (defesa): o defensor mira o ponto de interceptação `carrier + velocity * lead` (lead = tempo de chegada limitado a 0,7 s × leitura 0,6–1,0 por `agility`), não a posição atual. FS/SS (`deep_guard`, desligado em retornos) ficam 48 px à frente do portador, seguindo seu y (70 %), até ele chegar a 72 px; depois perseguem. `hold` e `_is_reading` do playbook continuam valendo.
- Medido (CPU corre vs BASE, 24 corridas): antes média 8,4 jd / mediana 1,4 / máx 60,7 / tackle em 3,5 s; depois média 2,7 / mediana 1,8 / máx 13,9 / 2,6 s.

## Revisão do bloqueio, RB e perseguição (aguardando teste manual do usuário)
Autorizadas e feitas: suíte de testes (6), saída por relevância (1), perseguição coordenada (4), RB desvia de aliados (3a), rebalanceio da disputa de passe (2a) e swim (2b). **Não autorizadas/feitas:** 3b (exceção de colisão do portador), mudança de HP base, formações, playbook.
- `tests/block_suite.gd` (headless): `-- duel <n> [hp] [extra_decay]` (duelo 1x1 LT x LDE, 20 pares por lote), `-- pass <n> [up|down|left|right] [semente]`, `-- run <n> [up] [semente]`. Sementes fixas por jogada para comparação pareada. Tempo de jogo = soma do delta físico (frames não equivalem a 1/60 s com `Engine.time_scale`).
- **1 — release_behind** (`BlockSchemes` run_*; `BlockSystem._release_behind`): em corridas o par engajado se solta (defensor ganha `FREE_TIME`) quando o portador passa do defensor por mais de `RELEVANCE_BEHIND`; o bloqueador então só escolhe alvos à frente do portador. Retornos (`tactical`) não mudaram.
- **2a — extra_decay 0.06** nos esquemas `pass_short/pass_long`, lido por `BlockSystem.begin` também no caminho não-rank. Duelo 1x1 (200 por caso): DL HP 65 rompe em 5 s: 3 % → 56 % (tempo médio ~3,1 s); HP 80: 76 → 78,5 % (1,75 s); HP 50: 0 %.
- **2b — swim** (`"swim": true` só nos passes): depois de `SWIM_MIN_HOLD` (0,9 s), a cada disputa o defensor tem chance `SWIM_BASE + 0,005·ΔHP + 0,004·Δagility` (0–0,35) de se livrar com deslize lateral de `SWIM_TIME`. Vale também para o defensor humano (automático, sem controle novo). Contador `BlockSystem.swims`.
- **3a — `CarrierBrain.think(..., allies, ...)`**: aliados parados/em `block` são paredes (risco 0,9), em movimento 0,3, na faixa de 18 px.
- **4 — `RunPursuit.target(..., teammates)`**: por proximidade ao portador, o mais perto vai direto; à frente fecha o ângulo (`CUTOFF_LEAD` 1,6); lateral >24 px mantém contenção por fora (`CONTAIN_OUT`); alvos de quem está mais longe são afastados dos de quem está mais perto (`_separate`).
- Medido (2 sementes × ~27 jogadas): corridas CPU vs BASE: jardas 4,2 → 6,3 (ruído grande; 3a sozinho 5,2, 4 sozinho 4,2, 1 sozinho 4,3), defensores agrupados 3,7 → 3,7 (4 sozinho 2,9). Passes RUSH 4: rompimentos/jogada 0,56 → 2,5, jogadas com rompimento 21 % → 93 %, QB lança em 2,9 s (antes 3,0), sacks 0 % → ~1,5 %. BIG BLITZ: com rompimento 7 % → 42 %, sacks 2,5 % → 11 %.
- **Defesa contra corrida vs passe do ataque (correção):** antes, com jogada de defesa contra corrida e o ataque passando, os 11 defensores iam ao QB e deixavam os recebedores livres. `Match._pass_rushers()` devolve os `rush` da jogada de defesa contra passe, ou só a linha defensiva (`Playbook.DEFENSE_LINE`) quando a defesa escolhida é contra corrida; o resto cobre os recebedores (`PassCoverage`) e disputa a bola no voo. Medido: 4 vão ao QB e 7 cobrem. Corridas e defesa contra passe vs corrida não mudaram.
- **Defesa contra corrida — FULL BOX agora pesa:** o playbook (`DEFENSE["down_a"]`) mudou de `hold: SECONDARY` para `hold: []` + `commit: true`. Com `commit`, `Match._is_reading` não impõe o atraso de leitura (LB/secundária) e o `RunPursuit` não deixa os safeties em profundidade (`deep_guard` desligado). Medido (CPU corre, 3 sementes): média de jardas BASE ~5,3 / mediana ~5; FULL BOX ~3,3 / mediana 2–4, corridas de 10+ jd 15 % → ~5 %, defensores agrupados 2,7 → 5,2 (todos se amontoam na linha). CONTAIN L ~5,1 e R ~4,5 (pouco diferentes da BASE; não alteradas).

## IA defensiva — Etapas 5 e 6 (concluídas, aguardando teste manual do usuário)
- Etapa 5: só avaliação. Com velocidades iguais ninguém alcança o portador por trás (simulação RB x MLB: nem em 6 s com 3 % a favor da defesa); mantido sem modificadores de velocidade por decisão do usuário. Opções propostas e não autorizadas: bônus de perseguição por trás (~5 %), penalidade do portador, tackle de mergulho.
- Etapa 6 (regressão, headless): todos os 32 scripts carregam; 3 jogos completos automáticos (bot que escolhe jogadas no menu) com ~63 jogadas cada, sem travas, sem erros de script, 0 jogadores engajados após o fim da jogada, todos os tipos de jogada exercitados (scrimmage, punt, FG, kickoff, extra point, touchback, safety/down). Passes, corridas e duelos de bloqueio medidos com `tests/block_suite.gd` (números nas seções anteriores). Não coberto: controles do humano em partida real, feeling na tela.

## Interceptações em disputa (ajuste; aguardando teste manual do usuário)
- Regra anterior (50/50 por `receiving` em toda disputa, com a cobertura colada da etapa 2 gerando disputa em ~90 % dos passes) dava ~44 % de interceptações. Agora, em `Match._update_flight`: defensor sozinho perto da bola = intercepta; disputa = o recebedor-alvo pesa `RECEIVER_EDGE` (2×) no sorteio `_defender_wins_ball`; se o defensor vence, só intercepta com `INTERCEPT_AFTER_WIN` (25 %), senão `_end_play("incomplete")` (passe quebrado, sem mensagem nova).
- Medido (64 passes da CPU, 3 sementes): interceptações ~9 % dos passes (antes 44 %), completos ~62 %, incompletos ~28 %. Valores 2× e 25 % são sugestão, não vêm do TSB3.
