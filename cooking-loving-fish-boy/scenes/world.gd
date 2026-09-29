extends Node2D

## World：表线大地图（单张大地图方案，P3 占位版）。
## 本脚本一次负责四件事，方便你立刻跑起来看效果：
##   1) 自动为 TileMapLayer 建好 TileSet（用 assets/tilemap/tilemap.png，16x16 + 间隔1）
##   2) 铺一个演示房间，让你立刻能看到“地图在跑”
##   3) 用 Area2D 划分 6 个区域（对应你策划案的表线 6 区）
##   4) 放一扇通往里世界的门（Area2D + 切换场景）
##
## 说明：这里用代码“自动建 TileSet/区域/门”，是为了省去你当下的手动配置。
##       等你熟悉编辑器后，这些节点都可以改成在场景里手动摆放，更直观可控。

const TILE_PNG := "res://assets/tilemap/tilemap.png"
const COLS := 20
const ROWS := 12
const TILE := 48            # 16 * 3（方案B：世界放大 3 倍，1 瓦片 = 48px）

# 表线 6 区：名字 + 像素矩形。之后你按策划案动线改坐标即可。
# Rect2(x, y, 宽, 高)，单位是“世界像素”（已含 3 倍放大）。
const REGIONS := [
	{"name": "厨房",   "rect": Rect2(0, 0, 6*48, 6*48)},
	{"name": "大厅",   "rect": Rect2(6*48, 0, 7*48, 6*48)},
	{"name": "仓库",   "rect": Rect2(13*48, 0, 7*48, 6*48)},
	{"name": "吧台",   "rect": Rect2(0, 6*48, 8*48, 6*48)},
	{"name": "走廊",   "rect": Rect2(8*48, 6*48, 6*48, 6*48)},
	{"name": "卫生间", "rect": Rect2(14*48, 6*48, 6*48, 6*48)},
]

# 门：走到门前按 X 进入目标场景
const DOORS := [
	{"name": "to_underworld", "target": "res://scenes/underworld.tscn", "rect": Rect2(18*48, 5*48, 2*48, 2*48)},
]

@onready var tile_layer: TileMapLayer = $TileMapLayer

# P5 阶段目标提示 UI（同时充当“防卡提示”）。P5 后期可改样式 / 挪位置。
var _obj_panel: PanelContainer
var _obj_title: Label
var _obj_desc: Label
var _obj_hint: Label
var _stuck_timer: Timer

# 调试阶段步进器（灰盒）：用于尚未建完 13 个房间前，手动步进验证整套阶段框架与目标 UI。
# 正式房间建好后，连同 _build_debug_stepper / _debug_step / _STAGE_ORDER 一起删除即可。
var _debug_layer: CanvasLayer
var _debug_label: Label
const _STAGE_ORDER := ["STAGE_00","STAGE_01","STAGE_02","STAGE_03","STAGE_04","STAGE_05","STAGE_06","STAGE_07","STAGE_08","STAGE_09","STAGE_10","STAGE_11","STAGE_12"]

func _ready() -> void:
	_ensure_tileset()
	_paint_demo_room()
	_setup_regions()
	_setup_doors()
	GameState.location_name = "厨房"   # 演示用：玩家出生在厨房
	# 灰盒：当前演示大地图实际扮演“餐桌区(STAGE_01)”。
	# 正式做“店门前”场景后，这行应移到店门前场景的 _ready；
	# 届时 STAGE_00→01 由“调查店门进店”触发，而不是在这里硬设。
	QuestManager.advance_to("STAGE_01")
	_build_stage_hud()
	_build_debug_stepper()
	print("World 就绪：6 区域 + 1 扇门。交互物请手动在编辑器里摆放 prop.tscn。方向键移动，按 X 调查/进门。")

# ---- 1. 自动建 TileSet（关键：16x16 切片 + 1px 间隔，对应 Kenney 那版瓦片） ----
func _ensure_tileset() -> void:
	if tile_layer.tile_set != null:
		return
	var ts := TileSet.new()
	var src_id := ts.add_source(load(TILE_PNG))
	var atlas: TileSetAtlasSource = ts.get_source(src_id)
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.margin = Vector2i(0, 0)
	atlas.separation = Vector2i(1, 1)
	atlas.spacing = Vector2i(1, 1)
	tile_layer.tile_set = ts

# ---- 2. 铺演示房间 ----
func _paint_demo_room() -> void:
	if not tile_layer.get_used_cells().is_empty():
		return   # 你已经手动铺过地图了，就不覆盖你的成果
	for x in range(COLS):
		for y in range(ROWS):
			tile_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

# ---- 3. 区域划分（Area2D：角色进入/离开会发信号） ----
func _setup_regions() -> void:
	for r in REGIONS:
		var area := Area2D.new()
		area.name = "Region_" + r["name"]
		area.add_to_group("region")
		var shape := RectangleShape2D.new()
		shape.size = r["rect"].size
		var col := CollisionShape2D.new()
		col.shape = shape
		area.add_child(col)
		area.position = r["rect"].position + r["rect"].size * 0.5
		area.body_entered.connect(_on_region_entered.bind(r["name"]))
		add_child(area)

func _on_region_entered(body: Node, region_name: String) -> void:
	if body is CharacterBody2D and GameState.location_name != region_name:
		GameState.location_name = region_name
		print("进入区域：", region_name)

# ---- 4. 门（Area2D + meta 存目标场景路径） ----
func _setup_doors() -> void:
	for d in DOORS:
		var area := Area2D.new()
		area.name = "Door_" + d["name"]
		area.add_to_group("door")
		var shape := RectangleShape2D.new()
		shape.size = d["rect"].size
		var col := CollisionShape2D.new()
		col.shape = shape
		area.add_child(col)
		area.position = d["rect"].position + d["rect"].size * 0.5
		area.set_meta("target", d["target"])
		area.set_meta("half_size", d["rect"].size * 0.5)   # 供"距离判定"用：门矩形的一半尺寸
		add_child(area)

# ---- 5. 交互物：不再用代码生成 ----
## 现在请在 Godot 编辑器里手动摆放：把 res://scenes/prop.tscn 拖进 world.tscn，
## 然后在检视面板里给每个实例填 resource（数据 .tres）和 sprite_texture（贴图）。
## 这样场景树里能看到明确引用，也方便你拖动位置、实时调试，无需改任何代码。

# ---- P5 阶段目标提示 UI（兼“防卡提示”） ----
## 屏幕左上角显示当前阶段标题 + 目标；同一阶段停留过久，自动多出一行醒目提示。
## 文案数据来自 data/stages/STAGE_xx.tres（QuestResource），你改文案不用碰代码。
func _build_stage_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30                       # 比对话框(10)/存档菜单(20)更高，纯角标层
	_obj_panel = PanelContainer.new()
	_obj_panel.position = Vector2(8, 8)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	_obj_title = Label.new()
	_obj_title.add_theme_font_size_override("font_size", 18)
	_obj_desc = Label.new()
	_obj_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_hint = Label.new()
	_obj_hint.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	vbox.add_child(_obj_title)
	vbox.add_child(_obj_desc)
	vbox.add_child(_obj_hint)
	_obj_panel.add_child(vbox)
	layer.add_child(_obj_panel)
	add_child(layer)
	_refresh_stage_hud()
	# 信号驱动刷新（之前讲过的“不用每帧去查”）：阶段或 flag 变化就重画
	GameState.stage_changed.connect(_refresh_stage_hud)
	GameState.flag_changed.connect(_refresh_stage_hud)
	# 防卡计时：进入新阶段重置；停留超过阈值才弹出提示
	_stuck_timer = Timer.new()
	_stuck_timer.wait_time = 20.0
	_stuck_timer.one_shot = true
	_stuck_timer.timeout.connect(_on_stuck_timeout)
	add_child(_stuck_timer)
	_stuck_timer.start()

## 取某阶段的“目标描述”，用作防卡提示文案。
func _stage_description(stage_id: String) -> String:
	var path := "res://data/stages/%s.tres" % stage_id
	if not ResourceLoader.exists(path):
		return ""
	var res := load(path) as QuestResource
	if res == null:
		return ""
	return res.description

func _refresh_stage_hud(_a = null, _b = null) -> void:
	if _obj_title == null:
		return
	var title := QuestManager.get_stage_title(GameState.current_stage)
	_obj_title.text = "阶段：%s" % (title if title != "" else GameState.current_stage)
	var desc := _stage_description(GameState.current_stage)
	_obj_desc.text = "目标：%s" % desc if desc != "" else ""
	_obj_hint.text = ""                   # 阶段变了就收起防卡提示
	if _stuck_timer != null:
		_stuck_timer.start()              # 重置计时

func _on_stuck_timeout() -> void:
	if _obj_hint == null:
		return
	var desc := _stage_description(GameState.current_stage)
	_obj_hint.text = "卡住了？试试：" + (desc if desc != "" else "回头看看有没有没调查过的东西。")

# ---- 调试阶段步进器（灰盒，正式化后删除） ----
## 屏幕右上角放“上一阶段 / 下一阶段”两个按钮，按 STAGE_00..12 顺序步进，
## 让你在不建完 13 个房间前，也能从头走到尾验证阶段框架 + 目标 UI。
func _build_debug_stepper() -> void:
	_debug_layer = CanvasLayer.new()
	_debug_layer.layer = 31                       # 比目标面板(30)更高，纯调试浮层
	var panel := PanelContainer.new()
	panel.position = Vector2(490, 8)              # 右上角（内部分辨率 720 宽，留 230 给面板）
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	var title := Label.new()
	title.text = "调试·阶段步进"
	title.add_theme_font_size_override("font_size", 14)
	_debug_label = Label.new()
	_debug_label.text = "当前：%s" % GameState.current_stage
	var btn_prev := Button.new()
	btn_prev.text = "上一阶段"
	btn_prev.pressed.connect(_debug_step.bind(-1))
	var btn_next := Button.new()
	btn_next.text = "下一阶段"
	btn_next.pressed.connect(_debug_step.bind(1))
	vbox.add_child(title)
	vbox.add_child(_debug_label)
	vbox.add_child(btn_prev)
	vbox.add_child(btn_next)
	panel.add_child(vbox)
	_debug_layer.add_child(panel)
	add_child(_debug_layer)
	GameState.stage_changed.connect(_refresh_debug_label)

func _refresh_debug_label(_a = null, _b = null) -> void:
	if _debug_label != null:
		_debug_label.text = "当前：%s" % GameState.current_stage

func _debug_step(delta: int) -> void:
	var idx := _STAGE_ORDER.find(GameState.current_stage)
	idx = clamp(idx + delta, 0, _STAGE_ORDER.size() - 1)
	QuestManager.advance_to(_STAGE_ORDER[idx])
