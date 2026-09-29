extends Node

## CookingGame：做饭小游戏（STAGE_03 后厨 · 味噌汤）
## 玩法（托盘顺序型）：把「碗 → 豆腐 → 葱」按正确顺序摆上托盘，按「完成」即可做出味噌汤。
##   - 顺序错 → 提示重来并清空托盘
##   - 成功 → 消耗三样食材、获得「味噌汤」、推进阶段 后厨(STAGE_03) → 餐桌B(STAGE_04)
##
## 设计要点（呼应背包界面 InventoryUI）：
##   - 用代码搭面板 + 显式坐标居中（避开此前对话/存档框“锚点失效跑到左上角”的坑）
##   - 面板打开时，Player 会读 is_open 锁住移动（见 player.gd）

var is_open: bool = false

# —— 配方：按这个“顺序”把食材摆上托盘。想改菜单只动这里 ——
const RECIPE: Array = [
	{"id": "BOWL",     "name": "碗"},
	{"id": "TOFU",     "name": "豆腐"},
	{"id": "SCALLION", "name": "葱"},
]

var _layer: CanvasLayer
var _panel: Panel
var _puzzle_box: VBoxContainer
var _success_box: VBoxContainer
var _tray_label: Label
var _hint_label: Label
var _success_label: Label
var _tray: Array = []          # 当前托盘上的食材 id 顺序

func _ready() -> void:
	_build()
	if get_viewport() != null:
		get_viewport().connect("size_changed", _resize)

## 用代码搭建面板（仅一次）
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 26                      # 比背包(25)更高，盖在最上层
	_layer.visible = false
	add_child(_layer)

	_panel = Panel.new()
	_panel.clip_contents = true            # 兜底：任何情况都不溢出窗口
	_layer.add_child(_panel)

	# —— 谜题视图 ——
	_puzzle_box = VBoxContainer.new()
	_puzzle_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_puzzle_box.add_theme_constant_override("margin_left", 16)
	_puzzle_box.add_theme_constant_override("margin_right", 16)
	_puzzle_box.add_theme_constant_override("margin_top", 14)
	_puzzle_box.add_theme_constant_override("margin_bottom", 14)
	_puzzle_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_puzzle_box)

	var title := Label.new()
	title.text = "料理台 · 味噌汤"
	title.add_theme_font_size_override("font_size", 18)
	_puzzle_box.add_child(title)

	var recipe_text := "配方：" + " → ".join(RECIPE.map(func(r): return r["name"])) + "\n（按顺序把食材摆上托盘）"
	var recipe_label := Label.new()
	recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recipe_label.text = recipe_text
	_puzzle_box.add_child(recipe_label)

	_tray_label = Label.new()
	_puzzle_box.add_child(_tray_label)

	# 食材按钮行
	var ing_row := HBoxContainer.new()
	ing_row.add_theme_constant_override("separation", 8)
	for r in RECIPE:
		var b := Button.new()
		b.text = "摆上：" + r["name"]
		b.pressed.connect(_on_ingredient_pressed.bind(r["id"]))
		ing_row.add_child(b)
	_puzzle_box.add_child(ing_row)

	# 操作按钮行
	var op_row := HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 8)
	var undo := Button.new(); undo.text = "撤销"; undo.pressed.connect(_on_undo)
	var done := Button.new(); done.text = "完成"; done.pressed.connect(_on_done)
	var close := Button.new(); close.text = "关闭"; close.pressed.connect(_close)
	op_row.add_child(undo); op_row.add_child(done); op_row.add_child(close)
	_puzzle_box.add_child(op_row)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	_puzzle_box.add_child(_hint_label)

	# —— 成功视图 ——
	_success_box = VBoxContainer.new()
	_success_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_success_box.add_theme_constant_override("margin_left", 16)
	_success_box.add_theme_constant_override("margin_right", 16)
	_success_box.add_theme_constant_override("margin_top", 14)
	_success_box.add_theme_constant_override("margin_bottom", 14)
	_success_box.add_theme_constant_override("separation", 8)
	_success_box.visible = false
	_panel.add_child(_success_box)

	_success_label = Label.new()
	_success_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_success_label.add_theme_font_size_override("font_size", 18)
	_success_box.add_child(_success_label)
	var finish := Button.new(); finish.text = "关闭"; finish.pressed.connect(_close)
	_success_box.add_child(finish)

## 按当前视口尺寸，把面板放到屏幕中央（显式坐标，不依赖锚点）
func _resize() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var w :float= min(vp.x - 40.0, 460.0)
	var h :float= min(vp.y - 40.0, 300.0)
	_panel.position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	_panel.size = Vector2(w, h)

## 对外接口：由交互物（烹饪台）调用。
func open() -> void:
	# 别盖在别的界面上
	if DialogueManager.is_active or SaveMenu.is_open or (InventoryUI != null and InventoryUI.is_open):
		return
	# 只在「后厨」阶段开放（用调试步进器切到 STAGE_03 即可试玩）
	if GameState.current_stage != "STAGE_03":
		DialogueManager.show_text("现在还不是下厨的时候。")
		return
	# 检查食材是否齐全
	var missing := []
	for r in RECIPE:
		if not InventoryManager.has(r["id"]):
			missing.append(r["name"])
	if not missing.is_empty():
		DialogueManager.show_text("还差食材：" + "、".join(missing) + "。去厨房各柜台拿。")
		return
	# 打开
	_tray = []
	_refresh_tray()
	_hint_label.text = ""
	_puzzle_box.visible = true
	_success_box.visible = false
	is_open = true
	_layer.visible = true
	_resize()

func _on_ingredient_pressed(id: String) -> void:
	_tray.append(id)
	_refresh_tray()
	_hint_label.text = ""

func _on_undo() -> void:
	if not _tray.is_empty():
		_tray.pop_back()
		_refresh_tray()

func _on_done() -> void:
	var expected := RECIPE.map(func(r): return r["id"])
	if _tray == expected:
		_succeed()
	else:
		_hint_label.text = "顺序不对，再试一次。（已清空托盘）"
		_tray = []
		_refresh_tray()

func _refresh_tray() -> void:
	if _tray.is_empty():
		_tray_label.text = "托盘：[ 空 ]"
	else:
		var names := _tray.map(func(id): return _item_name(id))
		_tray_label.text = "托盘：" + " → ".join(names)

func _item_name(id: String) -> String:
	var it = ItemDB.get_item(id)
	return it.display_name if it != null else id

func _succeed() -> void:
	# 消耗三样食材
	for r in RECIPE:
		InventoryManager.remove(r["id"])
	# 获得成品
	var soup := ItemDB.get_item("MISO_SOUP")
	if soup != null:
		InventoryManager.pick_up(soup)
	# 标记事件（防重复触发）
	GameState.mark_event_triggered("COOK_SOUP_DONE")
	# 推进阶段：后厨(STAGE_03) → 它的 next_stage（STAGE_04 餐桌B）
	var path := "res://data/stages/%s.tres" % GameState.current_stage
	if ResourceLoader.exists(path):
		var res := load(path) as QuestResource
		if res != null and res.next_stage != "":
			QuestManager.advance_to(res.next_stage)
	# 切到成功视图
	_success_label.text = "味噌汤完成！\n（获得「味噌汤」，可去餐桌B端给白川）"
	_puzzle_box.visible = false
	_success_box.visible = true

func _close() -> void:
	is_open = false
	_layer.visible = false
