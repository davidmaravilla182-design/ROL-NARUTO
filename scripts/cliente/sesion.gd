class_name Sesion
extends RefCounted
## Cómo se juega la próxima partida (lo decide el menú de inicio y lo lee la escena de juego):
##   offline   -> servidor y cliente en el mismo proceso (TransporteLocal)
##   anfitrion -> listen server: este celular es el servidor con autoridad y además juega
##   cliente   -> se une a la partida de otro celular por su IP

static var modo := "offline"
static var direccion := ""
static var tras_personaje := ""   # escena a la que ir después de crear el personaje
