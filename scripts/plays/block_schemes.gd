class_name BlockSchemes
extends RefCounted
## Esquemas de bloqueio por jogada. Referencial do ataque que bloqueia: drive.x = para a frente,
## drive.y = lateral (negativo = esquerda do ataque).
##
## Esquema fixo ("blockers"): cada bloqueador (por posição) tem
##   target   - defensores preferidos, em ordem; o primeiro ainda sem bloqueador é o alvo
##              (se nenhum, o defensor livre mais próximo)
##   start    - atraso (s) antes de sair
##   duration - tempo máximo (s) segurando o bloqueio depois do contato
##   drive    - para onde empurra o defensor enquanto domina o bloqueio (ZERO = só segura)
## "release_behind" (corridas): o par engajado se solta quando o portador já passou do defensor, e o bloqueador
## procura outro alvo à frente do portador.
## "extra_decay" (passes): desgaste extra do domínio, para que bons rushers cheguem ao QB; "swim": o defensor pode
## se livrar do bloqueador com uma ultrapassagem lateral (ver BlockSystem).
## Esquema de retorno ("rank_match"): cada bloqueador pega o jogador da cobertura na mesma
## ordem lateral. "tactical" ignora quem já ficou atrás do retornador; "grip_cap"/"extra_decay" limitam
## e desgastam o domínio do bloqueio (o jogador da cobertura acaba se soltando).

const SCHEMES := {
	# Corrida pelo meio: guards abrem o buraco, C e TE avançam sobre os linebackers.
	"run_middle": {"release_behind": true, "blockers": {
		"LT": {"target": ["LDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"LG": {"target": ["LDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"C": {"target": ["MLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(1, 0)},
		"RG": {"target": ["RDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"RT": {"target": ["RDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"TE": {"target": ["ROLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"WR1": {"target": ["LCB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"WR2": {"target": ["RCB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"WR3": {"target": ["LOLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
	}},
	# Corrida pelo buraco à direita do centro: o par C x MLB desliza para a esquerda.
	"run_right_gap": {"release_behind": true, "blockers": {
		"LT": {"target": ["LDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"LG": {"target": ["LDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"C": {"target": ["MLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"RG": {"target": ["RDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"RT": {"target": ["RDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"TE": {"target": ["ROLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, 1)},
		"WR1": {"target": ["LCB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"WR2": {"target": ["RCB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"WR3": {"target": ["LOLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
	}},
	# Corrida lateral (pela direita do ataque): lado forte fecha por dentro, guard esquerdo corre à frente.
	"run_outside": {"release_behind": true, "blockers": {
		"LT": {"target": ["LDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"LG": {"target": ["ROLB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"C": {"target": ["LDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"RG": {"target": ["MLB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0.3, -0.5)},
		"RT": {"target": ["RDT"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"TE": {"target": ["RDE"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"WR1": {"target": ["LCB"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
		"WR2": {"target": ["RCB"], "start": 0.0, "duration": 6.0, "drive": Vector2(0, -1)},
		"WR3": {"target": ["SS"], "start": 0.0, "duration": 6.0, "drive": Vector2.ZERO},
	}},
	# Passes: só a linha protege; a duração é o tempo de bolso antes dos rushers chegarem ao QB.
	"pass_short": {"extra_decay": 0.06, "swim": true, "blockers": {
		"LT": {"target": ["LDE"], "start": 0.0, "duration": 5.0, "drive": Vector2.ZERO},
		"LG": {"target": ["LDT"], "start": 0.0, "duration": 5.0, "drive": Vector2.ZERO},
		"C": {"target": ["MLB", "LDT"], "start": 0.0, "duration": 5.0, "drive": Vector2.ZERO},
		"RG": {"target": ["RDT"], "start": 0.0, "duration": 5.0, "drive": Vector2.ZERO},
		"RT": {"target": ["RDE"], "start": 0.0, "duration": 5.0, "drive": Vector2.ZERO},
	}},
	"pass_long": {"extra_decay": 0.06, "swim": true, "blockers": {
		"LT": {"target": ["LDE"], "start": 0.0, "duration": 7.0, "drive": Vector2.ZERO},
		"LG": {"target": ["LDT"], "start": 0.0, "duration": 7.0, "drive": Vector2.ZERO},
		"C": {"target": ["MLB", "LDT"], "start": 0.0, "duration": 7.0, "drive": Vector2.ZERO},
		"RG": {"target": ["RDT"], "start": 0.0, "duration": 7.0, "drive": Vector2.ZERO},
		"RT": {"target": ["RDE"], "start": 0.0, "duration": 7.0, "drive": Vector2.ZERO},
	}},
	# Retornos: barreira à frente do retornador; cada bloqueador marca um jogador da cobertura.
	"kick_return": {"rank_match": true, "tactical": true, "grip_cap": 0.6, "extra_decay": 0.03, "start": 0.0, "duration": 3.5, "drive": Vector2.ZERO},
	"punt_return": {"rank_match": true, "tactical": true, "grip_cap": 0.6, "extra_decay": 0.03, "start": 0.0, "duration": 3.5, "drive": Vector2.ZERO},
}
