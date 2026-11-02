class_name TeamStyle
extends RefCounted
## Cores derivadas da cor primária de um time. As variações de tom seguem a regra de tools/gen_player_sprites.py
## (claro = +70 por canal, escuro = -40), assim o uniforme gerado reproduz exatamente a arte original.

const LIGHT_STEP := 70
const DARK_STEP := 40
const DARK_TEXT := Color("14141c")
const LIGHT_TEXT := Color("e8e8f0")
## Luminância acima da qual o texto sobre a cor do time fica escuro.
const TEXT_SWITCH := 0.6


static func light(c: Color) -> Color:
	return Color8(mini(255, c.r8 + LIGHT_STEP), mini(255, c.g8 + LIGHT_STEP), mini(255, c.b8 + LIGHT_STEP))


static func dark(c: Color) -> Color:
	return Color8(maxi(0, c.r8 - DARK_STEP), maxi(0, c.g8 - DARK_STEP), maxi(0, c.b8 - DARK_STEP))


## Cor do indicador "P" do jogador controlado.
static func marker_color(primary: Color) -> Color:
	return light(primary)


## Texto legível sobre um fundo da cor do time.
static func text_on(background: Color) -> Color:
	return DARK_TEXT if background.get_luminance() > TEXT_SWITCH else LIGHT_TEXT
