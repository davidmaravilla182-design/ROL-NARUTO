extends SceneTree
func _initialize():
	Datos.cargar(true)
	var s := ServidorJuego.new()
	s.auto_procesar = false
	s.iniciar()
	s.poblar_aldea()
	s.agregar_jugador(1)
	var j := s.entidad_de_peer(1)
	j.pos = Vector3(0, 0, 60)
	print("arena ", s.mapa.arena_lago, " radio_caminable ", s.mapa.radio_caminable, " centro ", s.mapa.centro_aldea)
	# Camina por el puente hasta la explanada
	for i in int(14.0 / s.dt_tick):
		s.recibir_comando(1, {"t": "entrada", "mov": Vector2(0, 1), "mira": 0.0})
		s.paso(s.dt_tick); s.eventos = []
		if i % 30 == 0:
			print("camino t=%.1f pos %s agua %d suelo %s" % [i * s.dt_tick, str(j.pos.snapped(Vector3.ONE * 0.1)), j.agua, j.en_suelo])
	j.personaje["misiones"] = {"capitulo": 5}
	s.misiones.empezar_capitulo(j, "cap6")
	var m := 0.0
	for i in int(40.0 / s.dt_tick):
		var a := i * s.dt_tick
		s.recibir_comando(1, {"t": "entrada", "mov": Vector2(sin(a * 0.7), cos(a * 0.5)), "mira": 0.0})
		s.paso(s.dt_tick); s.eventos = []
		if i % 45 == 0 or j.pos.y < -2.0:
			print("jefe t=%.1f pos %s agua %d en_lago %s arena %s estado %s vida %d" % [a, str(j.pos.snapped(Vector3.ONE * 0.1)), j.agua, s.mapa.en_lago(j.pos2()), str(s.mapa.arena_lago), j.estado, int(j.vida)])
			if j.pos.y < -2.0:
				break
	quit()
