class_name PlayClock
extends RefCounted
## Play clock da NFL: tempo para escolher a jogada entre uma jogada e outra. Independe da interface;
## avança só pelo delta que a partida informa (não depende da taxa de quadros).

const DURATION := 25.0
## Abaixo disto a contagem é sinalizada como "próxima do fim".
const WARNING_SECONDS := 5.0

var time := DURATION
var running := false


func start() -> void:
	time = DURATION
	running = true


func stop() -> void:
	running = false


## Avança o relógio. Retorna true uma única vez, quando o tempo acaba.
func tick(delta: float) -> bool:
	if not running:
		return false
	time = maxf(time - delta, 0.0)
	if time > 0.0:
		return false
	running = false
	return true


func is_warning() -> bool:
	return running and time <= WARNING_SECONDS


func seconds_left() -> int:
	return ceili(time)
