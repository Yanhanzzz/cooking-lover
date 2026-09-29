extends Node

## DialogueManager：对话系统单例。
## 职责：把策划案里的 DialogueResource（线性台词）播放成“打字机效果”的对话框。
##
## 两种用法：
##   start("D01")        —— 按 id 播放一段对话（自动接 next_id 串成流程）
##   show_text("...")    —— 临时播一句调查文本（不读文件，比如椅子调查语）
##
## 实现说明（对新手）：对话框是“用代码现搭”的，不依赖 .tscn 文件，
##   这样你一眼能看全节点结构；等熟悉了可以改回在编辑器里摆场景。

signal dialogue_started
signal dialogue_ended(id: String)          # 整条对话链播完时发出，附带“根对话 id”（如 "D01"）

var is_active := false            # 是否有对话正在播放（Player 会据此锁住移动）

const CPS := 45.0                 # 打字速度：每秒 45 个字符

var _box: CanvasLayer
var _panel: Panel
var _label: Label
var _hint: Label

var _queue: Array[DialogueResource] = []   # 待播放的对话链（D01→D02→...）
var _lines: Array[String] = []
var _line_idx := 0
var _char_idx := 0
var _timer := 0.0
var _chain_root_id: String = ""            # 当前对话链的根 id（show_text 时为 ""，不触发完成效果）

func _ready() -> void:
	_build_box()
	_box.visible = false

# ---- 对外接口 ----
func start(id: String) -> void:
	if is_active:
		return
	var res := load("res://data/dialogues/%s.tres" % id) as DialogueResource
	if res == null:
		push_warning("DialogueManager：找不到对话 %s" % id)
		return
	_chain_root_id = id
	_start_chain([res])

func show_text(text: String) -> void:
	if is_active or text == "":
		return
	var res := DialogueResource.new()
	res.lines = [text]
	_chain_root_id = ""      # 临时调查文本没有 id，链结束时不会触发“对话完成效果”
	_start_chain([res])

# ---- 内部流程 ----
func _start_chain(chain: Array[DialogueResource]) -> void:
	_queue = chain
	is_active = true
	dialogue_started.emit()
	_box.visible = true
	_advance_chain()

func _advance_chain() -> void:
	if _queue.is_empty():
		_end()
		return
	var res: DialogueResource = _queue.pop_front()
	_lines.assign(res.lines)
	_line_idx = 0
	_char_idx = 0
	_timer = 0.0
	_label.text = ""
	# 若这段还有“下一段”，先排进队列，播放完自动续上
	if res.next_id != "":
		var nxt := load("res://data/dialogues/%s.tres" % res.next_id) as DialogueResource
		if nxt != null:
			_queue.push_back(nxt)

func _process(delta: float) -> void:
	if not is_active or _lines.is_empty():
		return
	var full := _lines[_line_idx]
	# 逐字显形（打字机）
	if _char_idx < full.length():
		_timer += delta
		while _timer >= 1.0 / CPS and _char_idx < full.length():
			_timer -= 1.0 / CPS
			_char_idx += 1
		_label.text = full.substr(0, _char_idx)
	# 按“确认(Z)”推进
	if Input.is_action_just_pressed("确认"):
		if _char_idx < full.length():
			_char_idx = full.length()      # 没打完 → 一次显示完整句
			_label.text = full
		else:
			_line_idx += 1
			if _line_idx >= _lines.size():
				_advance_chain()           # 本段播完 → 下一段或结束
			else:
				_char_idx = 0
				_timer = 0.0
				_label.text = ""

func _end() -> void:
	is_active = false
	_box.visible = false
	dialogue_ended.emit(_chain_root_id)

# ---- 用代码搭建对话框 UI ----
## 不用 anchors_preset 定位，改用“显式坐标 + 顶层对齐”，
## 无论 Godot 版本 / 是否代码构建，框都 100% 贴屏幕底部，不会再跑到左上角。
func _build_box() -> void:
	_box = CanvasLayer.new()
	_box.layer = 10                      # 保证画在最上层

	_panel = Panel.new()
	_panel.anchors_preset = Control.PRESET_TOP_LEFT   # 用绝对 position/size 定位
	_panel.clip_contents = true                      # 兜底：任何情况都不溢出到窗口外
	_resize_box()                                    # 按当前视口尺寸算好底部位置

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text = ""

	_hint = Label.new()
	_hint.text = "按 Z 继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	vbox.add_child(_label)
	vbox.add_child(_hint)
	_panel.add_child(vbox)
	_box.add_child(_panel)
	add_child(_box)                                  # 挂在单例节点下，始终在场景树里

	# 以后若改分辨率 / 窗口大小，框自动重新贴底
	if get_viewport() != null:
		get_viewport().connect("size_changed", _resize_box)

## 按当前视口尺寸，把对话框放到屏幕底部、左右留边距。
## 用绝对坐标，避开锚点失效的问题。
func _resize_box() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var margin_x := 6.0
	var box_h := 96.0          # 框高（便签这种短文本足够；更长文本靠 clip 兜底不溢出）
	_panel.position = Vector2(margin_x, vp.y - box_h - 12.0)
	_panel.size = Vector2(vp.x - margin_x * 2.0, box_h)
