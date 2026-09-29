class_name DialogueResource
extends Resource

## 对话数据模板。一段对话 = 一个 .tres。
## lines 是逐句文本；next_id 指向下一段，用于把 D01 → D02 → ... 串成流程。
##
## 说明：本作对话多为“说话者：台词”格式（如策划案 D01 那样），
##       所以这里把说话者直接写进 lines 文本里，简单直观。
##       多分支选项（如“修复/保留”）会在 P4 事件系统里用单独的选项机制处理，
##       不在 P1 的线性对话里。

@export var id: String = ""                  # 对话 id，如 "D01"
@export var speaker: String = ""             # 说话者（元数据，如 "店长"）
@export var lines: Array[String] = []        # 这段对话的全部台词（逐句）
@export var next_id: String = ""             # 下一段对话 id；空字符串表示结束
@export var auto_advance: bool = false       # true=自动连续播放；false=每句等玩家按 Z
