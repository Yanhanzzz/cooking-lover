# P3 交付说明：地图 / 区域 / 场景切换

## 这一期做了什么

| 文件 | 作用 |
|---|---|
| `scenes/player.gd` + `player.tscn` | 玩家角色：`CharacterBody2D` 物理移动 + `Camera2D` 跟随 + 按 X 交互/进门 |
| `scenes/world.gd` + `world.tscn` | 表线大地图：自动建 TileSet、铺演示房间、用 `Area2D` 划 6 区域、放 1 扇门 |
| `scenes/underworld.gd` + `underworld.tscn` | 里世界场景骨架：暗色背景 + 1 扇“返回饭店”的门 |
| `assets/character/placeholder_player.png` | 48×48 占位角色贴图（真立绘到位后替换 Sprite2D 的 texture 即可） |

## 怎么跑起来

1. 打开 Godot 工程。
2. 设主场景：项目 → 项目设置 → 应用 → 运行 → **主场景** 选 `res://scenes/world.tscn`。
3. 按 **F5** 运行。
4. 操作：方向键移动，`X` 调查 / 进门。右下角输出面板会打印“进入区域：厨房/大厅…”和“进入场景：…”。

你应看到：一个铺满瓦片的大房间，绿色方块角色能走动、相机跟随；走到右下角门附近按 X 进入里世界（暗紫色），走到中央按 X 返回。

## 三个核心机制（你第一次用到，记牢）

### 1. CharacterBody2D vs 自己写移动
角色用 `CharacterBody2D` 而不是 `Node2D`+手写坐标——它内置了 `move_and_slide()`，会自动处理碰撞、推挤、斜坡等物理。你只管给 `velocity`，剩下的它做。`_physics_process` 是“物理帧”回调（和 `_process` 每帧渲染不同，物理用固定步长，更稳）。

### 2. Area2D = “感应区”
`Area2D` 不会挡住角色（没有碰撞阻挡），只在“有东西进/出”时发信号（`body_entered` / `body_exited`）。我们用它做两件事：
- **区域划分**：6 个透明大框，玩家走进去就更新 `GameState.location_name`（存档地点就是这么来的）。
- **门**：走到框里按 X，把目标场景路径存进 `meta`，再 `get_tree().change_scene_to_file()` 切换。

### 3. 场景切换 + 单例不丢
`change_scene_to_file` 会**整体替换当前场景**。但 `GameState` / `SaveManager` 是 AutoLoad 单例，挂在场景树之外，**切换场景时不会被销毁**——所以你的阶段、背包、flags 在“进里世界→返回”后依然在。这正是把它们做成单例的原因。

## 之后你要怎么改（都是数据，不动核心代码）

- **改区域布局**：编辑 `world.gd` 里的 `REGIONS` 数组（名字 + `Rect2` 像素矩形）。1 瓦片 = 48px（方案 B）。
- **加/改门**：编辑 `DOORS` 数组，`target` 填目标场景路径。
- **铺真正的地图**：在编辑器里选中 `TileMapLayer`，用笔刷画（TileSet 已自动建好，16×16+间隔1）。一旦你手动画过，`world.gd` 就不会再覆盖（代码里有 `get_used_cells().is_empty()` 判断）。
- **换角色贴图**：把 `player.tscn` 里 `Sprite2D` 的 `texture` 指向你的立绘；做四向行走时把 `Sprite2D` 换成 `AnimatedSprite2D`。

## 已知占位项（P4/P5 再补）

- 角色目前是绿块、无行走动画、无碰撞墙（能穿出地图边界）。
- 交互物件（椅子、收银机等）还没接 `interact()` 逻辑——`player.gd` 已经留好调用口，P4 背包/物件系统会往 `interactable` 组里填节点。
- 场景切换是瞬间跳转，没有黑屏过渡；之后可做淡入淡出。
