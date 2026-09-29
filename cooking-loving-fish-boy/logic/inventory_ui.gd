extends Node

## InventoryUI：背包界面（自动加载单例）。
## 按“打开背包”键开关；从 InventoryManager 读取玩家持有的物品，列出名称与说明。
## 面板用“显式坐标”搭建，避开此前对话/存档框“锚点失效跑到左上角”的坑。
##
## 设计要点（呼应之前讲过的“信号驱动 UI”）：
##   背包内容变化时，InventoryManager 会广播 inventory_changed，
##   本界面接到信号后只刷新列表，不需要每帧去查。

var is_open: bool = false           # 供 Player 判断是否锁住移动
var _layer: CanvasLayer
var _panel: Panel
var _list: VBoxContainer
var _open_sfx: AudioStream = null

func _ready() -> void:
	_build()
	if InventoryManager != null:
		InventoryManager.inventory_changed.connect(_refresh)
	_open_sfx = load("res://sound/打开背包.wav")
	if get_viewport() != null:
		get_viewport().connect("size_changed", _resize)

## 用代码搭建背包面板（仅一次）
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 25                      # 比对话(10)/存档(20)更高，盖在最上层
	_layer.visible = false
	add_child(_layer)

	_panel = Panel.new()
	_panel.clip_contents = true            # 兜底：任何情况都不溢出到窗口外
	_layer.add_child(_panel)

	_list = VBoxContainer.new()
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.add_theme_constant_override("margin_left", 16)
	_list.add_theme_constant_override("margin_right", 16)
	_list.add_theme_constant_override("margin_top", 14)
	_list.add_theme_constant_override("margin_bottom", 14)
	_list.add_theme_constant_override("separation", 8)
	_panel.add_child(_list)

## 按当前视口尺寸，把面板放到屏幕中央（显式坐标，不依赖锚点）
func _resize() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = min(vp.x - 40.0, 400.0)
	var h: float = min(vp.y - 40.0, 280.0)
	_panel.position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	_panel.size = Vector2(w, h)

## 根据背包内容重建列表（标题 → 物品 → 提示，顺序由子节点顺序决定）
func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "—— 背包 ——"
	_list.add_child(title)

	var items := InventoryManager.get_all()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "（背包是空的）"
		_list.add_child(empty)
	else:
		for it in items:
			var row := Label.new()
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.text = "[%s]\n%s" % [it.display_name, it.description]
			_list.add_child(row)

	var hint := Label.new()
	hint.text = "再次按「打开背包」关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_list.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("打开背包"):
		_toggle()

## 开关背包
func _toggle() -> void:
	is_open = not is_open
	_layer.visible = is_open
	if is_open:
		_resize()
		_refresh()
		_play_open_sfx()

func _play_open_sfx() -> void:
	if _open_sfx == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _open_sfx
	p.bus = "Master"
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
