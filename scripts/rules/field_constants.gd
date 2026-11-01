class_name FieldConstants
extends RefCounted
## Medidas do campo. Coordenadas de jogo em jardas; X=0 é o início da endzone esquerda.

const ENDZONE_YARDS := 10.0
const PLAYING_YARDS := 100.0
const TOTAL_YARDS := PLAYING_YARDS + ENDZONE_YARDS * 2.0
const WIDTH_YARDS := 36.0

const PX_PER_YARD := 12.0


static func yards_to_px(yards: float) -> float:
	return yards * PX_PER_YARD


## Converte jarda da linha (0 = goal line esquerda, 100 = goal line direita) em X de pixels.
static func yard_line_to_x(yard_line: float) -> float:
	return yards_to_px(ENDZONE_YARDS + yard_line)
