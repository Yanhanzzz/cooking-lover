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

func _ready() -> void:
	_ensure_tileset()
	_paint_demo_room()
	_setup_regions()
	_setup_doors()
	GameState.location_name = "厨房"   # 演示用：玩家出生在厨房
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
