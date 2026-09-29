extends Node

## 临时自测脚本（P2 验证用）。
## 用法：在 Godot 新建一个空场景 → 加一个 Node → 把本脚本挂上去 → 按 F5 运行。
## 看底部「输出」面板，应该打印出"读档后 stage = STAGE_03"等。验证通过后把脚本从 Node 上卸掉即可。
##
## 它做的事：写入一些状态 → 存到槽位0 → 故意改乱 → 读档 → 检查是否恢复。

func _ready() -> void:
	print("=== P2 自测开始 ===")

	# 1) 用 GameState 写入一些状态
	GameState.set_stage("STAGE_03")
	GameState.set_flag("met_xiaokui", true)
	GameState.set_error_state("CHAIR_BUG", "ACTIVE")
	GameState.add_item("CHAIR_EXTRA")
	GameState.location_name = "厨房"
	GameState.portrait_path = "res://assets/portraits/player.png"

	# 2) 存档到槽位 0
	SaveManager.save_game(0)

	# 3) 故意把状态改乱，模拟"换场景/重开"
	GameState.set_stage("STAGE_00")
	GameState.flags.clear()
	GameState.inventory.clear()
	print("改乱后 stage =", GameState.current_stage, "（应为 STAGE_00）")

	# 4) 读档，应该恢复
	SaveManager.load_game(0)
	print("读档后 stage =", GameState.current_stage)              # 期望 STAGE_03
	print("读档后 见过小葵 =", GameState.flags.get("met_xiaokui"))  # 期望 True
	print("读档后 背包 =", GameState.inventory)                    # 期望 ["CHAIR_EXTRA"]
	print("读档后 地点 =", GameState.location_name)                # 期望 厨房

	# 5) 看存档界面元数据
	print("槽位0 展示信息 =", SaveManager.read_meta(0))

	print("=== P2 自测结束 ===")
