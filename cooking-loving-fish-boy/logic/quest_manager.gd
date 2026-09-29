extends Node

## QuestManager：任务 / 阶段推进单例。
## 第一关 13 个阶段 = 13 个 QuestResource（id 为 STAGE_00..STAGE_12）。
## 本作阶段推进是“事件驱动”的（如触发椅子复制 → 进入椅子重复阶段），
## 所以这里只负责：记录当前阶段、推进到下一阶段、对外广播变化。
##
## 真正的“阶段目标提示 UI”放在 P5；本期先把推进逻辑打通。

signal stage_advanced(old_stage: String, new_stage: String)

func _ready() -> void:
	# 监听“对话播完”事件：按对话数据里的 complete_* 字段推进阶段 / 置 flag。
	# 效果“仅首次生效”，靠 complete_event 防重复触发（之后再对话只重播、不再改状态）。
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

## 某段对话（链）整体播完时由 DialogueManager 调用。id 为链的根对话 id（如 "D01"）。
## 读取该对话数据里的 complete_* 字段并应用到全局状态，把对话接进 13 阶段流程。
func _on_dialogue_ended(id: String) -> void:
	if id == "":
		return
	var path := "res://data/dialogues/%s.tres" % id
	if not ResourceLoader.exists(path):
		return
	var res := load(path) as DialogueResource
	if res == null:
		return
	# 仅首次生效：若 complete_event 已 mark 过，说明之前播完时改过状态了，这次跳过
	if res.complete_event != "" and GameState.has_event_triggered(res.complete_event):
		return
	if res.complete_flag != "":
		GameState.set_flag(res.complete_flag, true)
	if res.complete_stage != "":
		advance_to(res.complete_stage)
	if res.complete_event != "":
		GameState.mark_event_triggered(res.complete_event)
	print("QuestManager：对话 %s 完成 -> flag=%s, stage=%s" % [id, res.complete_flag, res.complete_stage])

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
