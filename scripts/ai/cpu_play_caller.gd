class_name CpuPlayCaller
extends RefCounted
## Escolha de jogadas da CPU. Por enquanto simples; os playbooks por time (situação do jogo e habilidade
## dos jogadores) entram depois, trocando só este arquivo.

## Defesa contra corrida em 2º down com esta distância ou menos; senão, contra passe.
const SHORT_YARDAGE := 2


## Ataque: no 4º down segue a lógica de chute de antes; senão sorteia uma das 8 jogadas.
## Retorna {"kick": Match.PlayKind} para punt/field goal, ou a jogada do playbook.
static func offense(rules: GameRules) -> Dictionary:
	if rules.next_play == GameRules.Next.SCRIMMAGE and rules.down == 4:
		if rules.kick_distance() <= 47.0:
			return {"kick": Match.PlayKind.FIELD_GOAL}
		if rules.ball_on < 55.0:
			return {"kick": Match.PlayKind.PUNT}
	return Playbook.random_offense(rules.rng)


## Defesa: prioriza passe; em 2º down curto, corrida. A jogada exata sai por sorteio dentro do tipo.
static func defense(rules: GameRules) -> Dictionary:
	var short_run := rules.down == 2 and rules.yards_to_go() <= SHORT_YARDAGE
	return Playbook.random_defense_of_type(rules.rng, "run" if short_run else "pass")
