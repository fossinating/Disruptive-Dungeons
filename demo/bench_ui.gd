extends Control
## Workbench screen: move parts between your four slots and the stash.

const Parts := preload("res://demo/parts.gd")

var game
var pending := -1 # stash index waiting for a slot to swap into


func open() -> void:
	pending = -1
	visible = true
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var run: Dictionary = game.run

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_top = 32
	scroll.offset_right = -40
	scroll.offset_bottom = -32
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	box.add_child(_label("Workbench", 36, Color("f0e6d8")))
	box.add_child(_label("Four slots, and any part fits any slot. Each other active part of the same color makes a part 15% stronger. A field of that color shuts all of them off at once.", 18, Color(0.8, 0.76, 0.72), true))

	box.add_child(_label("Installed", 24, Color("f0e6d8")))
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override("h_separation", 12)
	slots.add_theme_constant_override("v_separation", 12)
	box.add_child(slots)
	for i in run.slots.size():
		var s = run.slots[i]
		var key: String = Parts.SLOT_KEYS[i]
		if s == null:
			slots.add_child(_empty_card(key, i))
		else:
			slots.add_child(_card(s.id, s, key, _on_slot.bind(i), pending >= 0))

	box.add_child(_label(_synergy_text(run), 18, Color(0.85, 0.8, 0.7)))
	if pending >= 0:
		box.add_child(_label("Slots are full. Click an installed part to swap %s in, or click it again to cancel." % Parts.PARTS[run.stash[pending]].name, 18, Color("ffcf6a"), true))

	box.add_child(_label("Stash (%d)" % run.stash.size(), 24, Color("f0e6d8")))
	if run.stash.is_empty():
		box.add_child(_label("Nothing in the stash. Destroyed rooms drop salvage crates.", 18, Color(0.6, 0.58, 0.56)))
	var stash := HFlowContainer.new()
	stash.add_theme_constant_override("h_separation", 12)
	stash.add_theme_constant_override("v_separation", 12)
	box.add_child(stash)
	for j in run.stash.size():
		stash.add_child(_card(run.stash[j], null, "", _on_stash.bind(j), j == pending))

	var done := Button.new()
	done.text = "Back to the dungeon  (Esc)"
	done.custom_minimum_size = Vector2(320, 52)
	done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	done.pressed.connect(func(): game.close_bench())
	box.add_child(done)


func _on_slot(i: int) -> void:
	var run: Dictionary = game.run
	if pending >= 0:
		var old = run.slots[i]
		run.slots[i] = _new_slot(run.stash[pending])
		run.stash.remove_at(pending)
		if old != null:
			run.stash.append(old.id)
		pending = -1
	elif run.slots[i] != null:
		run.stash.append(run.slots[i].id)
		run.slots[i] = null
	game.sfx.play("pickup", -10.0)
	rebuild()


func _on_stash(j: int) -> void:
	var run: Dictionary = game.run
	if pending == j:
		pending = -1
		rebuild()
		return
	var empty: int = run.slots.find(null)
	if empty >= 0:
		run.slots[empty] = _new_slot(run.stash[j])
		run.stash.remove_at(j)
		pending = -1
		game.sfx.play("pickup", -10.0)
	else:
		pending = j
	rebuild()


func _new_slot(id: String) -> Dictionary:
	return {"id": id, "cd": 0.0, "color": "red"}


func _synergy_text(run: Dictionary) -> String:
	var parts := []
	for c in Parts.COLORS:
		var n := 0
		for s in run.slots:
			if s != null and Parts.PARTS[s.id].colors.has(c):
				n += 1
		parts.append("%s %d" % [Parts.COLOR_NAME[c], n])
	return "Parts per color:  " + "   ".join(parts)


func _card(id: String, slot, key: String, on_click: Callable, highlight: bool) -> Control:
	var p: Dictionary = Parts.PARTS[id]
	var panel := _panel(Parts.part_color(id), highlight)
	_clickable(panel, on_click)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title: String = p.name
	if key != "" and p.active:
		title = "[%s]  %s" % [key, p.name]
	v.add_child(_label(title, 22, Parts.part_color(id)))
	v.add_child(_label(Parts.color_line(id), 15, Color(0.7, 0.66, 0.62)))
	v.add_child(_label(p.desc, 16, Color(0.9, 0.86, 0.82), true))
	if p.get("shield", false) and slot != null:
		v.add_child(_label("Protects:", 15, Color(0.7, 0.66, 0.62)))
		var row := HBoxContainer.new()
		v.add_child(row)
		for c in Parts.COLORS:
			var b := Button.new()
			b.text = Parts.COLOR_NAME[c]
			b.toggle_mode = true
			b.button_pressed = slot.color == c
			b.add_theme_color_override("font_color", Parts.ui_color(c))
			b.pressed.connect(func():
				slot.color = c
				rebuild()
			)
			row.add_child(b)
	return panel


func _empty_card(key: String, i: int) -> Control:
	var panel := _panel(Color(0.4, 0.38, 0.42), pending >= 0)
	_clickable(panel, _on_slot.bind(i))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(v)
	v.add_child(_label("[%s]  Empty slot" % key, 22, Color(0.6, 0.58, 0.6)))
	v.add_child(_label("Click a stash part to install it.", 16, Color(0.6, 0.58, 0.6), true))
	return panel


func _clickable(panel: Control, on_click: Callable) -> void:
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)


func _panel(border: Color, highlight: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(236, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.13) if not highlight else Color(0.2, 0.16, 0.1)
	sb.border_color = border if not highlight else Color("ffcf6a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 206
	return l
