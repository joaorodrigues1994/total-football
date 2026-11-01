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
- Direcionais: movimento. **A**: inicia a jogada no ataque (Esquerda+A = passe; no 4º down Baixo+A = punt, Direita+A = field goal; após TD: A = extra point, Baixo+A = conversão de 2 pontos). Na defesa, A troca de jogador (esquerda→direita, linha, LBs, backs) e trava no snap.
- **S**: juke (corredor) / troca de recebedor (QB). **D**: pulo (corredor) / lançar (QB).
- Teclas temporárias de debug: **R** (reseta a formação), **T** (troca a posse antes do snap).
- Menu de jogadas (direção+A, 4 ofensivas + 4 defensivas) **ainda não existe** (etapa 11).

## Como rodar e testar
- Godot em `Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe` (pasta ignorada pelo git). Cena principal `scenes/main.tscn`, viewport 512x448, stretch inteiro.
- Depois de criar `class_name` novos: `... --headless --path . --import` (senão a classe não é reconhecida).
- Testes são scripts headless descartáveis (`extends SceneTree`): `... --headless --path . -s teste.gd`. Instancie `main.tscn`, pegue `Match`, use `m.rules.start_drive(0, 30.0)`, `m._setup()`, `m._start_play()`, `await physics_frame`. **Limitação conhecida:** `Input.action_press("ui_left")` + `btn_a` não faz o jogo ler "passe" no headless; chame `m._start_play()` com `ui_left` pressionado.
- Captura de quadro: `--write-movie`. Sprites: `python tools/gen_player_sprites.py` (gera os PNG em `assets/sprites/`) e depois `libresprite.exe -b in.png --save-as out.aseprite` (LibreSprite em `C:\Program Files\LibreSprite`).

## Arquitetura (scripts/)
- **Física plana, apresentação à parte:** a perspectiva inclinada do campo é só visual (`field/field_perspective.gd`, `project_x`); sprites são deslocados em `_process`. Regras e física não conhecem a perspectiva.
- `rules/game_rules.gd` (`GameRules`, RefCounted): posse, downs, jardas, placar, relógio NFL (4 quartos de 2 min), chutes (`roll_kick_yards`, `field_goal_chance`), conversões, `rng`. Sequência pós-jogada via `Next {SCRIMMAGE, KICKOFF, EXTRA_POINT, TWO_POINT}`; `end_play/end_return/end_kick_without_return/end_field_goal/end_extra_point/end_two_point`.
- `rules/field_constants.gd`: jardas↔pixels (`PX_PER_YARD` = 12), endzones, largura do campo.
- `match/match.gd` (`Match`, arquivo central): máquina de estados `State {PRE_SNAP, SNAP, HANDOFF, DROPBACK, PASSING, FLIGHT, KICK_FLIGHT, RUNNING, DEAD}`, `PlayKind {SCRIMMAGE, PUNT, FIELD_GOAL, KICKOFF, EXTRA_POINT}`, `Side`, `HUMAN_TEAM := 0`. `_setup()` monta formação/IA/câmera; `_start_play`; passe (`_throw`, `PassFlight`); chutes (`_launch_kick`, `_resolve_kick`, `_start_return`, que troca `offense`/`defense` e `attack_dir`); `defender_target(player)` diz para onde cada IA vai; tackles (`_check_tackles`, `TACKLE_RADIUS`); `run_scheme`/`pass_scheme` escolhem o esquema de bloqueio.
- `match/block_system.gd` + `match/block_link.gd` + `plays/block_schemes.gd`: **sistema de bloqueio** (ver abaixo).
- `plays/formation.gd` (formações em jardas relativas à bola; roles `LT LG C RG RT TE QB RB WR1-3`, defesa `LDE LDT RDT RDE LOLB MLB ROLB LCB RCB FS SS`; chutes: `K` chutador, `R` retornador, `C1..C10` cobertura, `B1..B10` time que recebe), `plays/routes.gd` (`PASS_TEST`, `TARGET_ORDER`).
- `entities/player.gd` (`CharacterBody2D`): `input_dir` (decidido por humano ou IA), `Action {NONE, JUKE, DIVE, DOWN}`, `speed_scale`, `shove` (empurrão externo somado ao movimento), `block_pose`, `tackle_cooldown`, `knock_down()`. `player_attributes.gd`: `speed, acceleration, strength, agility, receiving, pass_accuracy, hitting_power` (1–100) + `for_role(role)` com HP base por posição. `player_sprites.gd`: monta `SpriteFrames` do spritesheet 24x24. `break_effect.gd`: estouro curto ao romper bloqueio. `ball.gd`, `control_marker.gd` (o "P" do jogador controlado), `target_marker.gd` (triângulo do recebedor).
- `ai/defender_ai.gd` (vai ao alvo de `defender_target`), `ai/route_runner.gd` (recebedores seguem rotas). `input/human_controller.gd` + `input_setup.gd` (ações criadas por código). `camera/match_camera.gd`, `field/field.gd`, `ui/debug_hud.gd`.

## Sistema de bloqueio (estilo Tecmo)
- Cada jogada tem um **esquema** em `BlockSchemes.SCHEMES`: `run_middle`, `run_outside`, `pass_short`, `pass_long` (por posição: `target` preferido, `start`, `duration` = limite de segurança, `drive` = direção de empurrão no referencial do ataque) e `kick_return`/`punt_return` (`rank_match`: cada bloqueador marca um jogador da cobertura na mesma ordem lateral).
- `BlockSystem.begin(esquema, bloqueadores, defensores, dir)` cria um `BlockLink` por bloqueador. Estados: `MOVING_TO_TARGET, ENGAGING, BLOCKING, FIGHTING_BLOCK, LOSING_BLOCK, BLOCK_BROKEN, RECOVERING`.
- **Engaja por contato** (≤17 px) com qualquer defensor livre. Engajados, os dois ficam parados (defensor com `speed_scale = 0`) até o defensor romper; só então ele volta a perseguir. Defensor travado (ENGAGING/BLOCKING) não dá tackle.
- A cada 0,3 s há uma disputa: `grip += clamp(edge, ±40) * GRIP_PER_POINT − GRIP_DECAY`, com `edge = score(bloqueador) − score(defensor)` e `score = hitting_power + 0.25*strength ± sorte`. `grip ≤ 0` = rompe (defensor livre por 1,2 s, bloqueador cambaleia com a pose `beaten` e depois procura outro alvo). Constantes de ajuste no topo de `block_system.gd`.
- Nos esquemas com `drive`, o par engajado desliza junto na direção do esquema (abre corredores); os retornos e passes usam drive zero.
- O sistema é criado antes dos jogadores na árvore (atualiza `shove`/`speed_scale` antes de eles se moverem). `Match._block_protect_point()` diz o que proteger (portador, QB ou ponto de queda do chute).
- Retornos: `_begin_return_blocks()` é chamado em `_launch_kick` (kickoff/punt) com o time que recebe (menos o `R`) bloqueando a cobertura (menos o `K`).

## Estado atual (o que já está feito)
Etapas 1–10 concluídas e jogáveis: campo com perspectiva e textura, jogadores com sprites estilo Tecmo e poses (largada, stance, ready, juke, dive, caído, bloqueio, derrotado), snap, corrida com handoff (QB sai da frente), passe com troca de recebedor, tackles/sack, downs e placar, relógio NFL, kickoff, punt, field goal, extra point e conversão de 2 pontos, retornador automático do humano até o ponto de queda, câmera deslocada para o lado do ataque, HUD de debug, humano (Time A) vs CPU. Defesa de passe: rushers (DL) vão ao QB; LBs/DBs acompanham o recebedor mais próximo e correm ao ponto de queda com a bola no ar. Bloqueio estilo Tecmo implementado e validado só em headless (feeling na tela ainda não avaliado pelo usuário).

## Pendências / ideias abertas
- **Etapa 11:** menu de jogadas (direção+A) e interface de partida; 4 jogadas ofensivas e 4 defensivas, cada uma com seu esquema de bloqueio (hoje `run_scheme="run_middle"` e `pass_scheme="pass_short"` fixos).
- Ajustar o feeling da corrida pelo meio (safeties e LBs que rompem ainda tacklam perto da linha); força do empurrão, alvos dos esquemas e constantes de `block_system.gd`.
- Interceptações e IA de cobertura mais completa, safety (tackle atrás da própria goal line hoje conta como jarda 1), fumble/bola solta, animação do chutador, atualizar o teste antigo `t8.gd`.
- Fora do escopo da fase 1: penalidades, saída de campo, modos além de amistoso humano vs CPU, times/atributos reais (o `hitting_power` já prepara jogadores bons/ruins de linha), multiplayer.
