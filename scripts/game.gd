extends Node2D

const WIDTH := 1280.0
const HEIGHT := 720.0
const BALL_HOME := Vector2(396.0, 438.0)
const GRAVITY := 900.0
const ROUND_SECONDS := 20.0
const ROUND_GOALS := [4, 6, 8]
const HOOP_BASE := Vector2(946.0, 290.0)

const INK := Color("#10243d")
const DEEP := Color("#091a2b")
const BLUE := Color("#397bc1")
const BRIGHT := Color("#5fb7ec")
const GOLD := Color("#ffd16e")
const PAPER := Color("#fff9ed")
const CORAL := Color("#f06f59")
const WOOD := Color("#c9915e")
const WOOD_LIGHT := Color("#dfae79")
const MINT := Color("#8fdfc5")

const UI_FONT: Font = preload("res://assets/fonts/NotoSansTC-VF.ttf")
const SFX_SHOT: AudioStream = preload("res://assets/audio/shot.wav")
const SFX_SCORE: AudioStream = preload("res://assets/audio/swish.wav")
const SFX_MISS: AudioStream = preload("res://assets/audio/miss.wav")
const SFX_HORN: AudioStream = preload("res://assets/audio/horn.wav")

enum Screen { TITLE, GAME, RESULT }

var screen: int = Screen.TITLE
var audio_player: AudioStreamPlayer
var canvas_scale: float = 1.0
var canvas_offset := Vector2.ZERO
var animation_time := 0.0

var round_index := 0
var round_time := ROUND_SECONDS
var round_score := 0
var total_score := 0
var made_shots := 0
var missed_shots := 0
var shot_streak := 0
var best_streak := 0
var shot_active := false
var shot_scored := false
var shot_clock := 0.0
var ball_position := BALL_HOME
var ball_velocity := Vector2.ZERO
var previous_ball_position := BALL_HOME
var dragging := false
var drag_position := BALL_HOME
var trail: Array[Vector2] = []
var transition_time := 0.0
var message := ""
var message_time := 0.0
var result_won := false


func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	add_child(audio_player)
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	var frame_delta := minf(delta, 0.05)
	animation_time += frame_delta
	if message_time > 0.0:
		message_time = maxf(0.0, message_time - delta)

	if screen == Screen.GAME:
		if transition_time > 0.0:
			transition_time -= frame_delta
			if transition_time <= 0.0:
				_advance_round()
		else:
			round_time = maxf(0.0, round_time - frame_delta)
			if shot_active:
				_step_ball(frame_delta)
			if round_time <= 0.0 and round_score < ROUND_GOALS[round_index]:
				_finish_game(false)

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _to_game_coordinates(event.position)
		if event.pressed:
			_pointer_down(point)
		else:
			_pointer_up(point)
	elif event is InputEventMouseMotion and dragging:
		drag_position = _to_game_coordinates(event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		var touch_point := _to_game_coordinates(event.position)
		if event.pressed:
			_pointer_down(touch_point)
		else:
			_pointer_up(touch_point)
	elif event is InputEventScreenDrag and dragging:
		drag_position = _to_game_coordinates(event.position)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if screen == Screen.TITLE:
				_start_game()
			elif screen == Screen.RESULT:
				_start_game()
		elif event.keycode == KEY_ESCAPE and screen == Screen.GAME:
			message = "最後一分鐘，繼續加油！"
			message_time = 1.0


func _to_game_coordinates(position: Vector2) -> Vector2:
	var view_size := get_viewport_rect().size
	var scale_value := minf(view_size.x / WIDTH, view_size.y / HEIGHT)
	var offset := (view_size - Vector2(WIDTH, HEIGHT) * scale_value) * 0.5
	return (position - offset) / scale_value


func _pointer_down(point: Vector2) -> void:
	if screen == Screen.TITLE:
		if Rect2(463.0, 604.0, 354.0, 52.0).has_point(point):
			_start_game()
	elif screen == Screen.RESULT:
		if Rect2(335.0, 535.0, 270.0, 76.0).has_point(point):
			_start_game()
		elif Rect2(675.0, 535.0, 270.0, 76.0).has_point(point):
			screen = Screen.TITLE
			message = ""
	elif screen == Screen.GAME and transition_time <= 0.0 and not shot_active:
		if point.distance_to(BALL_HOME) <= 88.0:
			dragging = true
			drag_position = point
			message = "往左下拉，蓄力瞄準！"
			message_time = 1.3
			queue_redraw()


func _pointer_up(point: Vector2) -> void:
	if dragging:
		drag_position = point
		dragging = false
		_release_shot()
		queue_redraw()


func _start_game() -> void:
	screen = Screen.GAME
	round_index = 0
	round_time = ROUND_SECONDS
	round_score = 0
	total_score = 0
	made_shots = 0
	missed_shots = 0
	shot_streak = 0
	best_streak = 0
	transition_time = 0.0
	message = "決賽開始！抓住籃球，往左下拉再放開。"
	message_time = 2.8
	_reset_ball()


func _reset_ball() -> void:
	shot_active = false
	shot_scored = false
	shot_clock = 0.0
	ball_position = BALL_HOME
	previous_ball_position = BALL_HOME
	ball_velocity = Vector2.ZERO
	trail.clear()


func _release_shot() -> void:
	var pull := drag_position - BALL_HOME
	if pull.length() < 84.0:
		message = "再拉遠一點，增加出手力量。"
		message_time = 1.1
		return
	if pull.x > -18.0 or pull.y < 12.0:
		message = "往左下拉，讓球朝右上飛！"
		message_time = 1.4
		return

	var aim := -pull.normalized()
	if aim.x < 0.48 or aim.y > -0.20:
		message = "調高弧線，對準遠方的籃框。"
		message_time = 1.3
		return

	var power := clampf(650.0 + pull.length() * 1.62, 820.0, 1040.0)
	ball_position = BALL_HOME
	previous_ball_position = BALL_HOME
	ball_velocity = aim * power
	shot_active = true
	shot_scored = false
	shot_clock = 0.0
	trail.clear()
	message = "出手！"
	message_time = 0.75
	_play_sound(SFX_SHOT)


func _step_ball(delta: float) -> void:
	shot_clock += delta
	previous_ball_position = ball_position
	var previous_hoop := _hoop_position_at(maxf(0.0, ROUND_SECONDS - round_time - delta))
	var current_hoop := _hoop_position_at(ROUND_SECONDS - round_time)
	if round_index >= 2:
		ball_velocity.x += sin(animation_time * 2.1) * 38.0 * delta
	ball_velocity.y += GRAVITY * delta
	ball_position += ball_velocity * delta
	trail.append(ball_position)
	if trail.size() > 11:
		trail.pop_front()

	var before_plane := previous_ball_position.x - previous_hoop.x
	var after_plane := ball_position.x - current_hoop.x
	if before_plane < 0.0 and after_plane >= 0.0 and ball_velocity.y > 0.0:
		var denom := absf(before_plane) + absf(after_plane)
		var mix := 0.5 if is_zero_approx(denom) else absf(before_plane) / denom
		var crossing_y := lerpf(previous_ball_position.y, ball_position.y, mix)
		var crossing_rim_y := lerpf(previous_hoop.y, current_hoop.y, mix)
		if absf(crossing_y - crossing_rim_y) <= 34.0:
			_score_basket(crossing_y, crossing_rim_y)
			return

	if ball_position.y > HEIGHT + 40.0 or ball_position.x > WIDTH + 60.0 or shot_clock > 2.1:
		missed_shots += 1
		shot_streak = 0
		message = "籃板球！調整角度再試一次。"
		message_time = 1.1
		_play_sound(SFX_MISS)
		_reset_ball()


func _score_basket(crossing_y: float, rim_y: float) -> void:
	shot_active = false
	shot_scored = true
	made_shots += 1
	shot_streak += 1
	best_streak = maxi(best_streak, shot_streak)
	var points := 2
	if absf(crossing_y - rim_y) < 11.0:
		points += 1
		message = "空心！漂亮的三分球！ +3"
	else:
		message = "進球！資通系拿下 2 分！"
	round_score += points
	total_score += points
	message_time = 1.15
	_play_sound(SFX_SCORE)
	if round_score >= ROUND_GOALS[round_index]:
		transition_time = 1.25
		message = "本節達標，晉級下一節！"
		message_time = transition_time


func _advance_round() -> void:
	if round_index >= 2:
		_finish_game(true)
		return
	round_index += 1
	round_time = ROUND_SECONDS
	round_score = 0
	message = "第 %d 節開始！籃框更難掌握了。" % (round_index + 1)
	message_time = 1.8
	_reset_ball()


func _finish_game(won: bool) -> void:
	result_won = won
	screen = Screen.RESULT
	transition_time = 0.0
	dragging = false
	message = ""
	_play_sound(SFX_SCORE if won else SFX_HORN)


func _play_sound(stream: AudioStream) -> void:
	if audio_player.playing:
		audio_player.stop()
	audio_player.stream = stream
	audio_player.play()


func _hoop_position_at(time_value: float) -> Vector2:
	if round_index == 0:
		return HOOP_BASE
	if round_index == 1:
		return HOOP_BASE + Vector2(sin(time_value * 1.8) * 30.0, sin(time_value * 2.1) * 5.0)
	return HOOP_BASE + Vector2(sin(time_value * 2.8) * 78.0, sin(time_value * 2.3) * 13.0)


func _draw() -> void:
	var view_size := get_viewport_rect().size
	canvas_scale = minf(view_size.x / WIDTH, view_size.y / HEIGHT)
	canvas_offset = (view_size - Vector2(WIDTH, HEIGHT) * canvas_scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, view_size), DEEP)
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))
	_draw_court()
	if screen == Screen.TITLE:
		_draw_title()
	elif screen == Screen.GAME:
		_draw_game()
	else:
		_draw_result()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if view_size.x < view_size.y:
		_draw_rotate_prompt(view_size)


func _draw_court() -> void:
	draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), DEEP)
	draw_rect(Rect2(0.0, 0.0, WIDTH, 257.0), Color("#122941"))
	draw_rect(Rect2(0.0, 215.0, WIDTH, 43.0), Color("#203f5d"))
	for row in range(8):
		var y := 20.0 + float(row) * 26.0
		for col in range(37):
			var x := 24.0 + float(col) * 34.0 + (17.0 if row % 2 == 0 else 0.0)
			var shade := float((row * 5 + col * 3) % 9) / 8.0
			var crowd_color := Color(0.25 + shade * 0.22, 0.43 + shade * 0.28, 0.62 + shade * 0.30, 0.95)
			draw_circle(Vector2(x, y), 5.0, crowd_color)
			draw_rect(Rect2(x - 4.0, y + 5.0, 8.0, 8.0), Color("#d4dce6"))
	for beam_x in [142.0, 490.0, 825.0, 1130.0]:
		draw_rect(Rect2(beam_x, 0.0, 12.0, 256.0), Color("#284461"))
	draw_rect(Rect2(0.0, 252.0, WIDTH, HEIGHT - 252.0), WOOD)
	for row in range(1, 10):
		var y := 252.0 + float(row) * 51.0
		draw_line(Vector2(0.0, y), Vector2(WIDTH, y), Color("#b67d4d"), 2.0)
	for col in range(1, 14):
		var x := float(col) * 92.0 + (46.0 if col % 2 == 0 else 0.0)
		draw_line(Vector2(x, 258.0), Vector2(x - 100.0, HEIGHT), Color("#ba8353"), 1.5)
	draw_line(Vector2(0.0, 259.0), Vector2(WIDTH, 259.0), PAPER, 5.0)
	draw_line(Vector2(0.0, 690.0), Vector2(WIDTH, 690.0), PAPER, 5.0)
	draw_line(Vector2(74.0, 260.0), Vector2(74.0, 690.0), PAPER, 5.0)
	draw_line(Vector2(1210.0, 260.0), Vector2(1210.0, 690.0), PAPER, 5.0)
	draw_arc(Vector2(915.0, 485.0), 207.0, PI * 0.54, PI * 1.48, 58, Color("#fff5e0"), 4.0, true)
	draw_rect(Rect2(785.0, 359.0, 205.0, 235.0), Color(1.0, 1.0, 1.0, 0.06))
	draw_arc(Vector2(785.0, 476.0), 118.0, -PI * 0.5, PI * 0.5, 36, PAPER, 4.0, true)
	draw_line(Vector2(785.0, 359.0), Vector2(785.0, 594.0), PAPER, 4.0)
	draw_circle(Vector2(785.0, 476.0), 6.5, PAPER)
	draw_circle(Vector2(452.0, 503.0), 122.0, Color(0.0, 0.0, 0.0, 0.10))
	var hoop := _hoop_position_at(ROUND_SECONDS - round_time if screen == Screen.GAME else animation_time)
	_draw_hoop(hoop)
	draw_rect(Rect2(0.0, 255.0, WIDTH, 4.0), Color("#ffdfa8"))


func _draw_hoop(hoop: Vector2) -> void:
	draw_line(hoop + Vector2(41.0, -39.0), hoop + Vector2(93.0, -69.0), Color("#6e8092"), 9.0)
	draw_rect(Rect2(hoop.x + 89.0, hoop.y - 105.0, 14.0, 122.0), Color("#f8f5ed"))
	draw_rect(Rect2(hoop.x + 93.0, hoop.y - 90.0, 7.0, 38.0), Color("#82c9e8"))
	draw_arc(hoop + Vector2(0.0, 2.0), 43.0, PI, TAU, 28, CORAL, 7.0, true)
	draw_line(hoop + Vector2(-39.0, 15.0), hoop + Vector2(-22.0, 70.0), PAPER, 2.5)
	draw_line(hoop + Vector2(-18.0, 18.0), hoop + Vector2(-10.0, 72.0), PAPER, 2.5)
	draw_line(hoop + Vector2(6.0, 18.0), hoop + Vector2(8.0, 72.0), PAPER, 2.5)
	draw_line(hoop + Vector2(27.0, 15.0), hoop + Vector2(20.0, 68.0), PAPER, 2.5)
	draw_line(hoop + Vector2(-22.0, 70.0), hoop + Vector2(20.0, 68.0), PAPER, 2.5)
	if screen == Screen.GAME and round_index == 2:
		var pulse := 0.5 + 0.5 * sin(animation_time * 5.0)
		_draw_text("風", hoop.x - 2.0, hoop.y - 119.0, 19, Color(0.58, 0.88, 0.96, pulse + 0.2))


func _draw_game() -> void:
	_draw_scoreboard()
	_draw_hero(Vector2(286.0, 602.0), 1.0, animation_time)
	if shot_active:
		if trail.size() > 1:
			draw_polyline(PackedVector2Array(trail), Color(1.0, 0.88, 0.53, 0.72), 5.0, true)
		_draw_basketball(ball_position, 22.0)
	else:
		_draw_basketball(BALL_HOME, 23.0)
	if dragging:
		_draw_aim_preview()
	_draw_instruction_bar()
	if transition_time > 0.0:
		_draw_banner("晉級成功！", "休息一下，下一節籃框會更難。", GOLD)
	elif message_time > 0.0:
		_draw_message(message)


func _draw_scoreboard() -> void:
	_draw_panel(Rect2(34.0, 24.0, 1212.0, 112.0), Color("#fbf7ed"), 0.97)
	_draw_text("系際盃決賽", 168.0, 61.0, 24, BLUE)
	_draw_text("第 %d 節 / 3" % (round_index + 1), 168.0, 98.0, 25, INK)
	draw_rect(Rect2(285.0, 43.0, 2.0, 72.0), Color("#d9e1e8"))
	_draw_text("資通系", 406.0, 70.0, 24, INK)
	_draw_text("%02d" % total_score, 544.0, 99.0, 43, BLUE)
	_draw_text("總分", 544.0, 119.0, 14, Color("#65778a"))
	draw_circle(Vector2(630.0, 79.0), 4.0, Color("#aeb9c3"))
	_draw_text("本節目標  %d / %d" % [round_score, ROUND_GOALS[round_index]], 803.0, 70.0, 21, INK)
	_draw_text("命中 %d   籃板 %d   連中 %d" % [made_shots, missed_shots, shot_streak], 803.0, 105.0, 18, Color("#5b6d7e"))
	_draw_panel(Rect2(1022.0, 36.0, 199.0, 88.0), INK, 1.0)
	_draw_text("剩餘時間", 1121.0, 63.0, 17, Color("#d3dfeb"))
	var seconds := ceili(round_time)
	var timer_color := CORAL if seconds <= 5 else GOLD
	_draw_text("00:%02d" % seconds, 1121.0, 106.0, 37, timer_color)
	var progress_width := 1150.0 * clampf(round_time / ROUND_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(65.0, 142.0, 1150.0, 6.0), Color(1.0, 1.0, 1.0, 0.18))
	draw_rect(Rect2(65.0, 142.0, progress_width, 6.0), timer_color)


func _draw_instruction_bar() -> void:
	_draw_panel(Rect2(43.0, 630.0, 1194.0, 68.0), Color("#10243d"), 0.94)
	_draw_text("按住籃球，往左下拖曳蓄力；放開後讓球越過籃框。", 640.0, 660.0, 22, PAPER)
	_draw_text("進球 +2 分｜空心 +3 分｜達成每節目標才能晉級", 640.0, 686.0, 17, Color("#d5e1ed"))


func _draw_aim_preview() -> void:
	var pull := drag_position - BALL_HOME
	var aim := -pull.normalized()
	var power := clampf(650.0 + pull.length() * 1.62, 820.0, 1040.0)
	var preview: Array[Vector2] = []
	for point_index in range(22):
		var t := float(point_index) * 0.065
		var point := BALL_HOME + aim * power * t + Vector2(0.0, 0.5 * GRAVITY * t * t)
		if point.x > WIDTH or point.y > HEIGHT:
			break
		preview.append(point)
	if preview.size() > 1:
		draw_polyline(PackedVector2Array(preview), Color(0.88, 0.97, 1.0, 0.56), 3.0, true)
	var pull_line := PackedVector2Array([BALL_HOME, drag_position])
	draw_polyline(pull_line, GOLD, 5.0, true)
	draw_circle(drag_position, 10.0, PAPER)
	_draw_panel(Rect2(415.0, 562.0, 450.0, 42.0), INK, 0.93)
	_draw_text("力量", 469.0, 589.0, 17, PAPER)
	draw_rect(Rect2(512.0, 577.0, 275.0, 13.0), Color(1.0, 1.0, 1.0, 0.22))
	draw_rect(Rect2(512.0, 577.0, 275.0 * clampf((pull.length() - 70.0) / 170.0, 0.0, 1.0), 13.0), GOLD)


func _draw_title() -> void:
	draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), Color(0.02, 0.06, 0.12, 0.52))
	_draw_panel(Rect2(69.0, 54.0, 1142.0, 614.0), Color("#fff9ed"), 0.98)
	_draw_pill(Rect2(115.0, 87.0, 118.0, 38.0), "#23  決賽", BLUE)
	_draw_text("系際盃：最後一分鐘", 653.0, 175.0, 55, INK)
	_draw_text("終場前 60 秒，全系的希望都在阿籃手上。", 653.0, 216.0, 22, Color("#5a6b7b"))
	draw_rect(Rect2(108.0, 248.0, 1064.0, 2.0), Color("#d8e1e8"))
	_draw_hero(Vector2(305.0, 532.0), 1.17, animation_time)
	_draw_basketball(Vector2(424.0, 343.0 + sin(animation_time * 2.0) * 4.0), 27.0)
	_draw_pill(Rect2(126.0, 545.0, 180.0, 34.0), "主角｜資通系 #23", INK)
	_draw_panel(Rect2(515.0, 272.0, 625.0, 242.0), Color("#edf2f5"), 1.0)
	_draw_text("投籃小抄", 827.0, 312.0, 25, BLUE)
	_draw_rule_row(1, "抓住左側的籃球", 354.0)
	_draw_rule_row(2, "按住球，往左下拉蓄力", 408.0)
	_draw_rule_row(3, "放開投籃；空心球多 1 分", 462.0)
	_draw_text("3 節 × 20 秒，每節達標才能晉級。後段籃框會移動並受風干擾。", 827.0, 553.0, 17, Color("#516476"))
	_draw_text("署名：資通系 李振偉老師", 827.0, 586.0, 19, INK)
	_draw_button(Rect2(463.0, 604.0, 354.0, 52.0), "上場投出致勝球", BLUE, PAPER)
	_draw_text("美術、音效：原創｜Noto Sans TC：Google Fonts（SIL OFL）", 990.0, 650.0, 13, Color("#586c7e"))


func _draw_rule_row(number: int, text: String, baseline: float) -> void:
	draw_circle(Vector2(572.0, baseline - 8.0), 15.0, BLUE)
	_draw_text(str(number), 572.0, baseline - 1.0, 16, PAPER)
	_draw_text(text, 822.0, baseline, 20, INK)


func _draw_result() -> void:
	draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), Color(0.02, 0.06, 0.12, 0.69))
	_draw_panel(Rect2(217.0, 84.0, 846.0, 560.0), PAPER, 1.0)
	_draw_text("冠軍賽結束", 640.0, 144.0, 25, BLUE)
	var title := "資通系，奪下冠軍！" if result_won else "終場哨響，再來一球！"
	var title_color := INK if result_won else CORAL
	_draw_text(title, 640.0, 213.0, 43, title_color)
	_draw_text("阿籃的決賽紀錄", 640.0, 257.0, 21, Color("#65778a"))
	_draw_panel(Rect2(314.0, 288.0, 652.0, 142.0), Color("#edf2f5"), 1.0)
	_draw_text("%d" % total_score, 640.0, 374.0, 68, BLUE)
	_draw_text("總得分", 640.0, 411.0, 18, Color("#65778a"))
	_draw_text("命中 %d 球     籃板 %d 次     最長連中 %d 球" % [made_shots, missed_shots, best_streak], 640.0, 475.0, 22, INK)
	if result_won:
		_draw_text("全系一起歡呼！決賽冠軍就是資通系！", 640.0, 510.0, 19, Color("#687b8e"))
	else:
		_draw_text("每節都有自己的目標，抓準弧線再挑戰一次。", 640.0, 510.0, 19, Color("#687b8e"))
	_draw_button(Rect2(335.0, 535.0, 270.0, 76.0), "再打一場", BLUE, PAPER)
	_draw_button(Rect2(675.0, 535.0, 270.0, 76.0), "回到首頁", INK, PAPER)
	_draw_text("資通系 李振偉老師", 640.0, 631.0, 18, Color("#65778a"))


func _draw_banner(title: String, subtitle: String, accent: Color) -> void:
	_draw_panel(Rect2(365.0, 273.0, 550.0, 142.0), INK, 0.95)
	_draw_text(title, 640.0, 332.0, 38, accent)
	_draw_text(subtitle, 640.0, 381.0, 20, PAPER)


func _draw_message(text: String) -> void:
	if text.is_empty():
		return
	var color := GOLD if text.contains("空心") or text.contains("晉級") else PAPER
	_draw_panel(Rect2(389.0, 164.0, 502.0, 47.0), INK, 0.90)
	_draw_text(text, 640.0, 194.0, 20, color)


func _draw_hero(origin: Vector2, size: float, time_value: float) -> void:
	var bob := sin(time_value * 2.2) * 2.0
	var position := origin + Vector2(0.0, bob)
	draw_set_transform(canvas_offset + position * canvas_scale, 0.0, Vector2(canvas_scale * size, canvas_scale * size))
	var shadow_points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		shadow_points.append(Vector2(cos(angle) * 70.0, sin(angle) * 16.0 - 1.0))
	draw_colored_polygon(shadow_points, Color(0.02, 0.07, 0.11, 0.20))
	_draw_local_line(Vector2(-22.0, -104.0), Vector2(-35.0, -36.0), INK, 27.0)
	_draw_local_line(Vector2(18.0, -104.0), Vector2(35.0, -37.0), INK, 27.0)
	_draw_local_line(Vector2(-35.0, -36.0), Vector2(-61.0, -19.0), Color("#f5f2e9"), 20.0)
	_draw_local_line(Vector2(35.0, -37.0), Vector2(60.0, -20.0), Color("#f5f2e9"), 20.0)
	var shorts := PackedVector2Array([Vector2(-47.0, -160.0), Vector2(47.0, -160.0), Vector2(38.0, -96.0), Vector2(0.0, -91.0), Vector2(-38.0, -96.0)])
	draw_colored_polygon(shorts, Color("#193d67"))
	var torso := PackedVector2Array([Vector2(-42.0, -224.0), Vector2(38.0, -224.0), Vector2(54.0, -158.0), Vector2(41.0, -112.0), Vector2(-45.0, -112.0), Vector2(-56.0, -159.0)])
	draw_colored_polygon(torso, BLUE)
	draw_line(Vector2(-42.0, -215.0), Vector2(-51.0, -160.0), PAPER, 8.0)
	draw_line(Vector2(37.0, -215.0), Vector2(49.0, -160.0), GOLD, 8.0)
	draw_line(Vector2(-28.0, -158.0), Vector2(29.0, -158.0), Color("#8fc5e9"), 3.0)
	draw_string(UI_FONT, Vector2(-27.0, -158.0), "23", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 31, PAPER)
	_draw_local_line(Vector2(-46.0, -207.0), Vector2(-83.0, -165.0), Color("#e8b28d"), 21.0)
	_draw_local_line(Vector2(39.0, -206.0), Vector2(79.0, -192.0), Color("#e8b28d"), 21.0)
	_draw_local_line(Vector2(79.0, -192.0), Vector2(91.0, -175.0), Color("#e8b28d"), 17.0)
	draw_rect(Rect2(-18.0, -252.0, 38.0, 36.0), Color("#d89d79"))
	draw_circle(Vector2(0.0, -278.0), 43.0, Color("#e8b28d"))
	var hair := PackedVector2Array([Vector2(-43.0, -287.0), Vector2(-40.0, -310.0), Vector2(-19.0, -328.0), Vector2(12.0, -330.0), Vector2(39.0, -314.0), Vector2(45.0, -288.0), Vector2(27.0, -298.0), Vector2(10.0, -289.0), Vector2(-7.0, -301.0), Vector2(-22.0, -290.0)])
	draw_colored_polygon(hair, Color("#182335"))
	draw_circle(Vector2(14.0, -278.0), 3.0, INK)
	draw_line(Vector2(20.0, -265.0), Vector2(31.0, -265.0), Color("#a95851"), 2.0)
	_draw_local_line(Vector2(-4.0, -220.0), Vector2(13.0, -219.0), Color("#b7d7ef"), 4.0)
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))


func _draw_local_line(a: Vector2, b: Vector2, color: Color, thickness: float) -> void:
	draw_line(a, b, color, thickness, true)


func _draw_basketball(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0.0, radius * 0.13), radius + 2.0, Color(0.0, 0.0, 0.0, 0.16))
	draw_circle(center, radius, Color("#ef8c39"))
	draw_arc(center, radius, 0.0, TAU, 32, Color("#673923"), 2.5, true)
	draw_arc(center, radius * 0.98, PI * 0.28, PI * 1.27, 20, Color("#773d24"), 2.3, true)
	draw_arc(center, radius * 0.98, -PI * 0.72, PI * 0.27, 20, Color("#773d24"), 2.3, true)
	draw_line(center + Vector2(-radius * 0.82, -radius * 0.18), center + Vector2(radius * 0.82, radius * 0.18), Color("#773d24"), 2.2, true)
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.31), radius * 0.13, Color(1.0, 0.82, 0.53, 0.65))


func _draw_panel(rect: Rect2, color: Color, alpha: float) -> void:
	var panel_color := color
	panel_color.a *= alpha
	draw_rect(rect, panel_color)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 3.0), Color(1.0, 1.0, 1.0, minf(0.36, alpha * 0.36)))


func _draw_pill(rect: Rect2, text: String, fill: Color) -> void:
	draw_rect(rect, fill)
	draw_circle(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5), rect.size.y * 0.5, fill)
	draw_circle(Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), rect.size.y * 0.5, fill)
	_draw_text(text, rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + 7.0, 17, PAPER)


func _draw_button(rect: Rect2, text: String, fill: Color, text_color: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 4.0), Color(1.0, 1.0, 1.0, 0.30))
	_draw_text(text, rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5 + 9.0, 23, text_color)


func _draw_text(value: String, center_x: float, baseline: float, size: int, color: Color) -> void:
	var width := UI_FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(UI_FONT, Vector2(center_x - width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_rotate_prompt(view_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#081827"))
	draw_circle(view_size * 0.5, minf(view_size.x, view_size.y) * 0.26, Color("#183752"))
	draw_string(UI_FONT, Vector2(view_size.x * 0.5 - 58.0, view_size.y * 0.5 - 5.0), "↻", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 72, GOLD)
	var text := "請將手機橫向，開始決賽！"
	var width := UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x
	draw_string(UI_FONT, Vector2((view_size.x - width) * 0.5, view_size.y * 0.5 + 76.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, PAPER)
