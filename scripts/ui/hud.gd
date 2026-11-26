extends CanvasLayer
## All on-screen UI, built in code: crosshair, interaction prompt, toasts and
## barks, the quest tracker, the journal, the dialogue box, and full-screen
## fades / title cards used by the story sequences.

const GOLD := Color(0.93, 0.78, 0.45)
const TYPE_SPEED := 55.0

var _prompt: Label
var _toast: Label
var _toast_time := 0.0
var _quest_panel: PanelContainer
var _quest_title: Label
var _quest_objective: Label
var _journal: PanelContainer
var _journal_text: Label
var _dialogue: PanelContainer
var _speaker: Label
var _action: Label
var _line: Label
var _choices: VBoxContainer
var _hint: Label
var _fade: ColorRect
var _caption: Label
var _title: Label
var _subtitle: Label
var _card: ColorRect
var _card_text: Label

var _typing := false
var _chars := 0.0
var _choice_texts: Array = []


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Crosshair.
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	_anchor(dot, 0.5, 0.5, 0.5, 0.5, -2, -2, 2, 2)

	_prompt = _label(20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_prompt)
	_anchor(_prompt, 0, 0.5, 1, 0.5, 0, 26, 0, 60)

	_toast = _label(20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_toast)
	_anchor(_toast, 0.15, 1, 0.85, 1, 0, -320, 0, -260)

	# Quest tracker (top right).
	_quest_panel = _panel(Color(0, 0, 0, 0.45))
	root.add_child(_quest_panel)
	_anchor(_quest_panel, 1, 0, 1, 0, -400, 20, -20, 20)
	var qbox := VBoxContainer.new()
	_quest_panel.add_child(qbox)
	_quest_title = _label(18, GOLD)
	_quest_objective = _label(16)
	qbox.add_child(_quest_title)
	qbox.add_child(_quest_objective)
	_quest_panel.visible = false

	# Journal (centre).
	_journal = _panel(Color(0.08, 0.07, 0.06, 0.92))
	root.add_child(_journal)
	_anchor(_journal, 0.5, 0.5, 0.5, 0.5, -340, -240, 340, 240)
	var jbox := VBoxContainer.new()
	_journal.add_child(jbox)
	jbox.add_child(_label(26, GOLD, HORIZONTAL_ALIGNMENT_CENTER, "Journal"))
	_journal_text = _label(17)
	jbox.add_child(_journal_text)
	jbox.add_child(_label(14, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, "[J / Tab] close"))
	_journal.visible = false

	# Dialogue box (bottom).
	_dialogue = _panel(Color(0.05, 0.05, 0.07, 0.85))
	root.add_child(_dialogue)
	_anchor(_dialogue, 0, 1, 1, 1, 80, -250, -80, -24)
	_dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 6)
	_dialogue.add_child(dbox)
	_speaker = _label(22, GOLD)
	_action = _label(16, Color(0.72, 0.72, 0.76))
	_line = _label(20)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	_hint = _label(14, Color(0.65, 0.65, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
	for c in [_speaker, _action, _line, _choices, _hint]:
		dbox.add_child(c)
	_dialogue.visible = false

	# Full-screen fade, captions, title and the bright "time passes" card.
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_caption = _label(24, Color(0.9, 0.88, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_caption)
	_anchor(_caption, 0.15, 0, 0.85, 1)
	_caption.visible = false

	_title = _label(72, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(_title)
	_anchor(_title, 0, 0, 1, 0.5, 0, 0, 0, -10)
	_title.visible = false

	_subtitle = _label(30, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(_subtitle)
	_anchor(_subtitle, 0, 0.5, 1, 1, 0, 10, 0, 0)
	_subtitle.visible = false

	_card = ColorRect.new()
	_card.color = Color(1.0, 0.96, 0.84)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sun := Panel.new()
	var sun_style := StyleBoxFlat.new()
	sun_style.bg_color = Color(1.0, 0.82, 0.3)
	sun_style.set_corner_radius_all(200)
	sun_style.shadow_color = Color(1.0, 0.75, 0.2, 0.5)
	sun_style.shadow_size = 40
	sun.add_theme_stylebox_override("panel", sun_style)
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(sun)
	_anchor(sun, 0.5, 0.5, 0.5, 0.5, -110, -280, 110, -60)
	_card_text = _label(44, Color(0.3, 0.24, 0.15), HORIZONTAL_ALIGNMENT_CENTER)
	_card.add_child(_card_text)
	_anchor(_card_text, 0, 0.5, 1, 0.5, 0, 0, 0, 80)
	_card.visible = false

	Dialogue.line_shown.connect(show_line)
	Dialogue.dialogue_ended.connect(func(_id: String) -> void: hide_dialogue())
	Quests.quest_updated.connect(func(_id: String) -> void: refresh_quests())
	Quests.quest_completed.connect(func(id: String) -> void: toast("Quest complete: " + Quests.title_of(id)))
	GameState.toast_requested.connect(toast)
	GameState.bark_requested.connect(bark)


func _process(delta: float) -> void:
	if _typing:
		_chars += delta * TYPE_SPEED
		_line.visible_characters = int(_chars)
		if _chars >= _line.text.length():
			_finish_typing()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue.visible:
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if event.is_action_pressed("advance") or event.is_action_pressed("interact") or click:
			get_viewport().set_input_as_handled()
			if _typing:
				_finish_typing()
			elif _choice_texts.is_empty():
				Dialogue.advance()
			return
		if event is InputEventKey and event.pressed and not event.echo and not _typing:
			var idx := int(event.keycode) - KEY_1
			if idx >= 0 and idx < _choice_texts.size():
				get_viewport().set_input_as_handled()
				Dialogue.choose(idx)
		return
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		toggle_journal()


# --- Prompts, toasts, quests -------------------------------------------------

func set_prompt(text: String) -> void:
	_prompt.text = text


func toast(text: String, duration := 3.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = duration


func bark(speaker: String, text: String) -> void:
	toast("%s:  \"%s\"" % [speaker, text], 3.0)


func refresh_quests() -> void:
	var q: Dictionary = Quests.get_tracked()
	_quest_panel.visible = not q.is_empty()
	if q.is_empty():
		return
	_quest_title.text = q["title"]
	_quest_objective.text = "- " + str(q["objective"])
	if _journal.visible:
		_journal_text.text = Quests.journal_text()


func toggle_journal() -> void:
	_journal.visible = not _journal.visible
	if _journal.visible:
		_journal_text.text = Quests.journal_text()


# --- Dialogue ----------------------------------------------------------------

func show_line(line: Dictionary) -> void:
	_journal.visible = false
	_dialogue.visible = true
	var speaker := str(line.get("speaker", ""))
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	var action := str(line.get("action", ""))
	_action.text = "(" + action + ")" if action != "" else ""
	_action.visible = action != ""
	_line.text = str(line.get("text", ""))
	_line.visible_characters = 0
	_chars = 0.0
	_typing = true
	_choice_texts = line.get("choices", [])
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = false
	_hint.text = ""


func hide_dialogue() -> void:
	_dialogue.visible = false
	_typing = false


func _finish_typing() -> void:
	_typing = false
	_line.visible_characters = -1
	if _choice_texts.is_empty():
		_hint.text = "[Space / E / Click]  continue"
		return
	for i in _choice_texts.size():
		var l := _label(19, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, "%d.  %s" % [i + 1, _choice_texts[i]])
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		l.gui_input.connect(_on_choice_input.bind(i))
		l.mouse_entered.connect(func() -> void: l.add_theme_color_override("font_color", GOLD))
		l.mouse_exited.connect(func() -> void: l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0)))
		_choices.add_child(l)
	_choices.visible = true
	_hint.text = "[1-%d / Click]  choose" % _choice_texts.size()


func _on_choice_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		Dialogue.choose(index)


# --- Fades and cards (await these from story scripts) ------------------------

func set_black(alpha: float) -> void:
	_fade.color.a = alpha


func fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


func caption(text: String, hold: float) -> void:
	_caption.text = text
	_caption.modulate.a = 0.0
	_caption.visible = true
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.8)
	await tw.finished
	_caption.visible = false


## Shows a title and subtitle over the current screen. hold <= 0 leaves them up.
func show_title(title: String, subtitle: String, hold: float) -> void:
	_title.text = title
	_subtitle.text = subtitle
	for c in [_title, _subtitle]:
		c.modulate.a = 0.0
		c.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 1.5)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 1.5).set_delay(0.8)
	await tw.finished
	if hold <= 0.0:
		return
	await get_tree().create_timer(hold).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(_title, "modulate:a", 0.0, 1.0)
	out.tween_property(_subtitle, "modulate:a", 0.0, 1.0)
	await out.finished
	_title.visible = false
	_subtitle.visible = false


func card_in(text: String, hold: float) -> void:
	_card_text.text = text
	_card.modulate.a = 0.0
	_card.visible = true
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	await tw.finished


func card_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, duration)
	await tw.finished
	_card.visible = false


# --- Helpers -------------------------------------------------------------------

func _anchor(c: Control, l: float, t: float, r: float, b: float, ol := 0.0, ot := 0.0, orr := 0.0, ob := 0.0) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _label(size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(GOLD, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
