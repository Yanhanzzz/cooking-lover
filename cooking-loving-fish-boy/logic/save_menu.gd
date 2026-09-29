extends Node

## SaveMenu：存档菜单 UI 单例（P4）。
## 玩家走到收银机/打卡机按 X → Interactable(SAVEPOINT) → SaveMenu.open()
##
## 菜单列出 3 个槽位（时间 / 头像 / 地点），玩家操作：
##   ↑↓ 方向键  选槽
##   Z（确认）  读取该存档；若该槽为空则“存”进去
##   X（调查）  存档 / 覆盖到该槽（无论空还是已有都覆盖写）
##   Esc        关闭
##
## 这是“用代码现搭 UI”的又一个例子，方便你一眼看全节点结构。
## 注意：必须在项目设置 → 自动加载 里注册为 "SaveMenu"（与 interactable.gd 里的引用名一致）。

signal menu_opened
signal menu_closed

var is_open := false
var _lock := 0                 # 打开后的“忽略输入”帧数，避免开菜单那一下按键被菜单误吞

var _box: CanvasLayer
var _panel: Panel
var _title: Label
var _slots: Array[Label] = []
var _slot_texs: Array[TextureRect] = []
var _selected := 0
const SLOT_COUNT := 3

func _ready() -> void:
	_build()
	_box.visible = false

## 由收银机交互物调用。
func open() -> void:
	if is_open:
		return
	is_open = true
	_lock = 3
	_selected = 0
	_refresh()
	_box.visible = true
	menu_opened.emit()
	print("SaveMenu：打开存档菜单（Z=读取/存，X=覆盖存，↑↓选槽，Esc=关）")

func close() -> void:
	if not is_open:
		return
	is_open = false
	_box.visible = false
	menu_closed.emit()
	print("SaveMenu：关闭")

# ---- 输入处理（仅菜单打开时生效） ----
func _process(_delta: float) -> void:
	if not is_open:
		return
	if _lock > 0:
		_lock -= 1
		return
	if Input.is_action_just_pressed("ui_cancel"):
		close()
		return
	if Input.is_action_just_pressed("ui_up"):
		_selected = (_selected - 1 + SLOT_COUNT) % SLOT_COUNT
		_refresh()
	elif Input.is_action_just_pressed("ui_down"):
		_selected = (_selected + 1) % SLOT_COUNT
		_refresh()
	if Input.is_action_just_pressed("确认"):
		_do_confirm()
	elif Input.is_action_just_pressed("调查"):
		_do_overwrite()

## Z：空槽=存档；有档=读取。
func _do_confirm() -> void:
	if SaveManager.save_exists(_selected):
		var ok := SaveManager.load_game(_selected)
		if ok:
			print("SaveMenu：读取槽位 %d" % _selected)
	else:
		SaveManager.save_game(_selected)
		print("SaveMenu：存档到空槽位 %d" % _selected)
	_refresh()
	close()

## X：无论空/有，都覆盖写入。
func _do_overwrite() -> void:
	SaveManager.save_game(_selected)
	print("SaveMenu：覆盖存档到槽位 %d" % _selected)
	_refresh()
	close()

# ---- 用代码搭建 UI ----
func _build() -> void:
	_box = CanvasLayer.new()
	_box.layer = 20                      # 比对话框(layer 10)更高，盖在最上层
	_panel = Panel.new()
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.custom_minimum_size = Vector2(420, 280)
	_panel.offset_left = -210
	_panel.offset_right = 210
	_panel.offset_top = -140
	_panel.offset_bottom = 140
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 18)
	vbox.add_theme_constant_override("margin_right", 18)
	vbox.add_theme_constant_override("margin_top", 14)
	vbox.add_theme_constant_override("margin_bottom", 14)
	_title = Label.new()
	_title.text = "存档管理"
	vbox.add_child(_title)
	for i in SLOT_COUNT:
		var hb := HBoxContainer.new()
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hb.add_child(tex)
		hb.add_child(lbl)
		_slot_texs.append(tex)
		_slots.append(lbl)
		vbox.add_child(hb)
	var hint := Label.new()
	hint.text = "↑↓ 选择　Z 读取/存　X 覆盖存　Esc 关闭"
	vbox.add_child(hint)
	_panel.add_child(vbox)
	_box.add_child(_panel)
	add_child(_box)

## 刷新每个槽位的显示（头像 + 时间 + 地点）。
func _refresh() -> void:
	for i in SLOT_COUNT:
		var meta := SaveManager.read_meta(i)
		var prefix := ("▶ " if i == _selected else "   ")
		if meta.is_empty():
			_slot_texs[i].texture = null
			_slots[i].text = "%s槽位 %d：空" % [prefix, i]
		else:
			var p: String = meta.get("portrait", "")
			if p != "" and ResourceLoader.exists(p):
				_slot_texs[i].texture = load(p) as Texture2D
			else:
				_slot_texs[i].texture = null
			_slots[i].text = "%s槽位 %d：%s · %s" % [
				prefix, i, meta.get("timestamp", ""), meta.get("location_name", "")]
