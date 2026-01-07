extends Control

# Configuración del Minimapa
export var zoom_level = 5.0 # Tiles por unidad de mapa
export var map_size_tiles = 64 # Radio de visualización en tiles (ej. 128x128 tiles)

onready var player = get_tree().root.get_node_or_null("Main3D/Player")
onready var world = get_tree().root.get_node_or_null("Main3D/WorldManager")

# Colors
const COL_WATER = Color(0.2, 0.4, 0.8)
const COL_SAND = Color(0.9, 0.8, 0.5)
const COL_GRASS = Color(0.3, 0.6, 0.2)
const COL_FOREST = Color(0.1, 0.4, 0.1)
const COL_SNOW = Color(0.95, 0.95, 1.0)
const COL_ROAD = Color(0.6, 0.5, 0.4)
const COL_SETTLEMENT = Color(0.8, 0.4, 0.1)
const COL_PLAYER = Color(1.0, 0.0, 0.0)

func _process(_delta):
	# Solo actualizar si es visible
	if visible:
		# OPTIMIZACIÓN: No redibujar 4000 tiles cada frame (60 FPS -> 240,000 operaciones/s)
		# Solo actualizar si el jugador se ha movido lo suficiente o ha pasado tiempo.
		
		var current_time = OS.get_ticks_msec() / 1000.0
		var p_pos = player.global_transform.origin
		var needs_update = false
		
		# 1. Chequeo de distancia (5 metros)
		if p_pos.distance_squared_to(last_update_pos) > 25.0:
			needs_update = true
		
		# 2. Chequeo de tiempo (0.2s = 5 FPS máximo para el mapa)
		if current_time - last_update_time > 0.2:
			# Forzar update si ha pasado tiempo (updates de background, agua, etc)
			# Pero si no se mueve, quizás podemos hacerlo más lento (1.0s)
			needs_update = true
			
		if needs_update:
			last_update_pos = p_pos
			last_update_time = current_time
			update() # Redraw overlay (player, POIs)
	
var last_update_pos = Vector3.ZERO
var last_update_time = 0.0


func _draw():
	if not world or not player: return
	
	var center = rect_size / 2.0
	var scale_factor = rect_size.x / (map_size_tiles * 2.0 * world.tile_size) # Pixels per world unit
	
	var p_pos = player.global_transform.origin
	
	# 1. Dibujar Fondo (Biomas) - Muestreo optimizado
	# En lugar de pixel a pixel, dibujamos círculos/rects grandes o usamos un shader?
	# Mejor: Iterar tiles visibles (son ~64x64 tiles)
	
	var start_x = int(world.get_tile_coords(p_pos).x) - map_size_tiles
	var end_x = int(world.get_tile_coords(p_pos).x) + map_size_tiles
	var start_z = int(world.get_tile_coords(p_pos).y) - map_size_tiles
	var end_z = int(world.get_tile_coords(p_pos).y) + map_size_tiles
	
	# STEP optimizado para no dibujar 128*128 rects (16k llamadas)
	# Dibujamos grupos de 4x4 tiles si el zoom es lejano
	# OPTIMIZACIÓN QUIRÚRGICA: Step 4 reduce el loop 4 veces más (x16 factor de área)
	# Mantiene calidad suficiente para móviles pero vuela en rendimiento
	var step = 4
	
	for x in range(start_x, end_x, step):
		for z in range(start_z, end_z, step):
			# Muestrear bioma en el centro de este bloque
			var gx = x * world.tile_size
			var gz = z * world.tile_size
			
			var noise_val = world.shared_res["biome_noise"].get_noise_2d(gx, gz)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 120.0)
			
			# Normalizar ángulo
			while deg > 180: deg -= 360
			while deg <= -180: deg += 360
			
			var col = COL_GRASS
			if deg > -135 and deg <= -45: col = COL_SNOW
			elif deg > 45 and deg <= 135: col = COL_FOREST # Jungle
			elif deg > -45 and deg <= 45: col = COL_SAND # Desert
			
			# Altura precisa usando los multiplicadores de bioma (Copiado de GroundTile.gd)
			var hn = world.shared_res["H_SNOW"]
			var hs = world.shared_res["H_JUNGLE"]
			var he = world.shared_res["H_DESERT"]
			var hw = world.shared_res["H_PRAIRIE"]
			
			var h_mult = 0.0
			
			if deg >= -90 and deg <= 0:
				var t = (deg + 90) / 90.0
				h_mult = lerp(hn, he, t) # Snow -> Desert
			elif deg > 0 and deg <= 90:
				var t = deg / 90.0
				h_mult = lerp(he, hs, t) # Desert -> Jungle
			elif deg > 90 and deg <= 180:
				var t = (deg - 90) / 90.0
				h_mult = lerp(hs, hw, t) # Jungle -> Prairie
			else:
				var t = (deg + 180) / 90.0
				h_mult = lerp(hw, hn, t) # Prairie -> Snow
			
			var y_h = world.shared_res["height_noise"].get_noise_2d(gx, gz) * h_mult
			if y_h < -7.0: col = COL_WATER
			
			# Coordenadas en pantalla
			var rel_pos = Vector3(gx, 0, gz) - p_pos
			# Rotar si quisiéramos mapa rotativo, pero fijo Norte es mejor para cartografía
			
			var screen_pos = center + Vector2(rel_pos.x, rel_pos.z) * scale_factor
			var size_px = world.tile_size * step * scale_factor
			
			# Dibujar Rectangulo del terreno
			draw_rect(Rect2(screen_pos, Vector2(size_px, size_px)), col, true)
			
			# Detalles de vegetación (Puntos) si no es agua
			if col == COL_FOREST and step <= 2:
				if (x+z) % 3 == 0: # Patrón pseudo-aleatorio simple
					draw_circle(screen_pos + Vector2(size_px/2, size_px/2), size_px/3, COL_FOREST.darkened(0.2))
	
	# 2. Dibujar Vías (Curvas de Bezier reales)
	# Buscar asentamientos visibles en este rango
	var sc_start_x = floor(start_x / float(world.SUPER_CHUNK_SIZE))
	var sc_end_x = floor(end_x / float(world.SUPER_CHUNK_SIZE))
	var sc_start_z = floor(start_z / float(world.SUPER_CHUNK_SIZE))
	var sc_end_z = floor(end_z / float(world.SUPER_CHUNK_SIZE))
	
	for sc_x in range(sc_start_x - 1, sc_end_x + 1):
		for sc_z in range(sc_start_z - 1, sc_end_z + 1):
			# Obtener asentamiento
			var sett_tile = world.get_settlement_coords(sc_x, sc_z)
			var sett_pos = Vector3(sett_tile.x * world.tile_size, 0, sett_tile.y * world.tile_size)
			
			# --- DRAW HORIZONTAL ROAD (East) ---
			var next_sett_tile = world.get_settlement_coords(sc_x + 1, sc_z)
			_draw_road_curve(sett_tile, next_sett_tile, center, scale_factor, p_pos, true)
			
			# --- DRAW VERTICAL ROAD (South) ---
			if world._has_vertical_road(sc_x, sc_z):
				var south_sett_tile = world.get_settlement_coords(sc_x, sc_z + 1)
				_draw_road_curve(sett_tile, south_sett_tile, center, scale_factor, p_pos, false)
			
			# Dibujar Asentamiento (Rectángulo + Icono)
			var rel_s = sett_pos - p_pos
			var s_screen = center + Vector2(rel_s.x, rel_s.z) * scale_factor
			var s_size = 66.0 * scale_factor # Tamaño real del asentamiento (66m)
			draw_rect(Rect2(s_screen - Vector2(s_size/2, s_size/2), Vector2(s_size, s_size)), COL_SETTLEMENT, false, 2.0)
			draw_circle(s_screen, s_size/2, COL_SETTLEMENT.lightened(0.2))

func _draw_road_curve(t_start, t_end, center, scale_factor, p_pos, is_horizontal):
	var tile_size = world.tile_size
	
	var start_p = Vector3.ZERO
	var end_p = Vector3.ZERO
	var cp1 = Vector3.ZERO
	var cp2 = Vector3.ZERO
	var settlement_seed = world.settlement_seed
	
	if is_horizontal:
		start_p = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		end_p = Vector3(t_end.x * tile_size - 33.0, 0, t_end.y * tile_size)
		
		var dist = start_p.distance_to(end_p)
		var handle_len = dist * 0.4
		
		var seed_x = int(t_start.x) + int(t_end.x)
		var seed_z = int(t_start.y) + int(t_end.y)
		var curv_rng = RandomNumberGenerator.new()
		curv_rng.seed = (seed_x * 49297) ^ (seed_z * 91823) ^ settlement_seed
		var curve_z = curv_rng.randf_range(-40.0, 40.0)
		
		cp1 = start_p + Vector3(handle_len, 0, curve_z)
		cp2 = end_p - Vector3(handle_len, 0, -curve_z)
	else:
		# Copy Logic from WorldManager
		var sc_x = floor(t_start.x / world.SUPER_CHUNK_SIZE)
		var sc_z = floor(t_start.y / world.SUPER_CHUNK_SIZE)
		
		# Assuming t_start passed here is the "upper" settlement tile
		var s_east = world.get_settlement_coords(sc_x + 1, sc_z)
		
		var h_start = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		var h_end = Vector3(s_east.x * tile_size - 33.0, 0, s_east.y * tile_size)
		var h_mid = (h_start + h_end) * 0.5
		
		start_p = h_mid
		end_p = Vector3(t_end.x * tile_size, 0, t_end.y * tile_size - 33.0)
		
		var dist = start_p.distance_to(end_p)
		var handle_len = dist * 0.4
		
		var seed_x_v = int(t_start.x)
		var seed_z_v = int(t_start.y)
		var curv_rng_v = RandomNumberGenerator.new()
		curv_rng_v.seed = (seed_x_v * 73821) ^ (seed_z_v * 19283) ^ settlement_seed
		var curve_x = curv_rng_v.randf_range(-40.0, 40.0)
		
		cp1 = start_p + Vector3(curve_x, 0, handle_len)
		cp2 = end_p - Vector3(-curve_x, 0, handle_len)
	
	var curve_points = PoolVector2Array()
	var segments = 15
	for i in range(segments + 1):
		var t = float(i) / segments
		var p3 = _cubic_bezier_v3(start_p, cp1, cp2, end_p, t)
		var rel_p = p3 - p_pos
		curve_points.append(center + Vector2(rel_p.x, rel_p.z) * scale_factor)
	
	draw_polyline(curve_points, COL_ROAD, 4.0, true)

	
	# 3. Dibujar Jugador
	var p_screen = center # El jugador siempre está en el centro relativo de la proyección
	
	# Obtener rotación visual real (MeshInstance)
	# El cuerpo físico (KinematicBody) no rota, solo la malla.
	var mesh_inst = player.get_node_or_null("MeshInstance")
	var rot = 0.0
	
	if mesh_inst:
		# Usamos vector forward global para ser robustos
		var fwd_3d = -mesh_inst.global_transform.basis.z 
		var fwd_2d = Vector2(fwd_3d.x, fwd_3d.z)
		# Ajustar ángulo: Vector2.angle() es 0 al Este (+X).
		# Nuestro dibujo apunta al Norte/-Y (Up). 
		# Para apuntar al Este (+X), necesitamos rotar +90 (+PI/2).
		# FIX: El usuario reportó que estaba invertido, así que sumamos 180 grados (+PI).
		rot = fwd_2d.angle() + PI/2 + PI
	else:
		rot = player.rotation.y
		
	# Triangulo
	var p_size = 10.0
	var p_points = PoolVector2Array([
		p_screen + Vector2(0, -p_size * 1.2), # Punta más larga
		p_screen + Vector2(-p_size*0.7, p_size * 0.8),
		p_screen + Vector2(p_size*0.7, p_size * 0.8)
	])
	
	# Rotar triangulo según rotación del jugador
	for i in range(p_points.size()):
		p_points[i] = rotate_point(p_points[i], p_screen, rot)
		
	draw_colored_polygon(p_points, COL_PLAYER)

func rotate_point(point, pivot, angle):
	var rel = point - pivot
	var rot_rel = rel.rotated(angle)
	return pivot + rot_rel

func _cubic_bezier_v3(p0, p1, p2, p3, t):
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1.0 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt
	return p0 * mt3 + p1 * (3.0 * mt2 * t) + p2 * (3.0 * mt * t2) + p3 * t3
