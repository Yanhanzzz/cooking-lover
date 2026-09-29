extends Node

## QuestManager：任务 / 阶段推进单例。
## 第一关 13 个阶段 = 13 个 QuestResource（id 为 STAGE_00..STAGE_12）。
## 本作阶段推进是“事件驱动”的（如触发椅子复制 → 进入椅子重复阶段），
## 所以这里只负责：记录当前阶段、推进到下一阶段、对外广播变化。
##
## 真正的“阶段目标提示 UI”放在 P5；本期先把推进逻辑打通。

signal stage_advanced(old_stage: String, new_stage: String)

func current_stage() -> String:
	return GameState.current_stage

## 推进到指定阶段（会经过 GameState，自动广播 stage_changed 信号）。
func advance_to(stage_id: String) -> void:
	var old := GameState.current_stage
	GameState.set_stage(stage_id)
	stage_advanced.emit(old, stage_id)
	print("QuestManager：阶段推进 -> ", stage_id)

## 取某阶段的标题/描述（用于 P5 目标提示）。找不到则返回空串。
func get_stage_title(stage_id: String) -> String:
	var path := "res://data/stages/%s.tres" % stage_id
	if ResourceLoader.exists(path):
		var res := load(path) as QuestResource
		if res != null:
			return res.title
	return ""
