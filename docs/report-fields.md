# 0.3.1 报表字段说明

本文说明 0.3.1 的八种教学报表。报表键与列名为固定接口契约，预览与下载使用同一授权范围和查询模板。界面提供本地化字段名称，导出表头保留以下机器字段。

## 共同口径

日期筛选默认覆盖最近 30 个自然日，并包含起止日期。平台按页面所选的 IANA 时区转换筛选范围，输出时间统一使用 UTC ISO 8601 格式。教师仅查询当前负责课程且可见的数据，每次请求重新检查授权；帖子移动、教师撤权后立即按当前权限处理。已删除帖子与私信不在教学讨论导出范围。

JSON 沿用 Data Explorer 的 `columns` 与 `rows` 结构。缺失值表示为 `null`，空文本表示为 `""`，零值保持原生类型。CSV 缺失值为空字段，空文本为带引号的空字符串；导入软件可能合并两者，需要精确区分时使用 JSON。帖子和草稿保留 Markdown；投票选项沿用原生 HTML。页面以文本安全展示。

预览最多显示 50 行，页面会提示是否存在更多数据。下载使用原生 10000 行上限，达到上限即拒绝整次下载，须缩小日期或 Topic 范围；不会交付被截断的文件。费用采用原生估算值，并以美元计价。无法归属的历史日志不纳入课程用量；没有日志表示缺失或无记录，无法据此推断零成本。汇总中 missing_cost_count 指明缺失费用的调用数，SUM 仅累计已有值；全部缺失时保留 null。

AI 帖子只通过 Run.published_post_id 识别。reviewer_username 为生成执行数据当时留存的指定审核教师，不能代替独立的实际审批人审计记录；执行数据清理后留空。execution_status 为原生状态或 pending / unavailable；outcome 为 published / rejected / superseded，未知时为 null。重新生成的旧 Run 标记 superseded。执行成功与审核拒绝可以同时成立。

投票类型 poll_type 沿用数据库枚举：0 regular、1 multiple、2 number、3 ranked_choice；status 为 open / closed，票数为当前选项票数。投票报表时间区间用于选择投票，无法重建区间内投票增量或历史时点票数。

## discussions

此报表提供“讨论与参与”中的帖子明细。每行对应一个当前可见的普通帖子，日期筛选使用帖子创建时间。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `topic_title` | 该字段记录讨论主题。 |
| `post_id` | 该字段记录帖子 ID。 |
| `post_number` | 该字段记录帖子序号。 |
| `user_id` | 该字段记录用户 ID。 |
| `username` | 该字段记录用户名。 |
| `text` | 该字段记录 Markdown 正文。 |
| `created_at_utc` | 该字段记录创建时间（UTC）。 |
| `updated_at_utc` | 该字段记录修改时间（UTC）。 |
| `reply_to_post_number` | 该字段记录所回复帖子的序号。 |
| `ai_run_id` | 该字段记录教学 AI 运行 ID。 |

## participation

此报表提供“讨论与参与”中的参与汇总。报表按作者汇总所选时间内的可见帖子；回复数统计 `post_number > 1` 的帖子，首次和最近发帖时间均限于所选范围。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `user_id` | 该字段记录用户 ID。 |
| `username` | 该字段记录用户名。 |
| `post_count` | 该字段记录帖子数。 |
| `reply_count` | 该字段记录回复数。 |
| `topic_count` | 该字段记录参与 Topic 数。 |
| `first_post_at_utc` | 该字段记录所选范围内首次发帖的时间（UTC）。 |
| `last_post_at_utc` | 该字段记录所选范围内最近发帖的时间（UTC）。 |

## reviews

此报表提供“AI 回复与审核”中的运行明细。每行对应一个 Run，日期筛选使用 Run 创建时间。原稿和编辑稿来自原生执行数据，发布正文来自当前帖子。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `source_post_id` | 该字段记录学生帖子 ID。 |
| `student_user_id` | 该字段记录学生用户 ID。 |
| `student_username` | 该字段记录学生用户名。 |
| `actor_id` | 该字段记录发起人用户 ID。 |
| `actor_username` | 该字段记录发起人用户名。 |
| `run_id` | 该字段记录运行 ID。 |
| `execution_id` | 该字段记录工作流执行 ID。 |
| `created_at_utc` | 该字段记录创建时间（UTC）。 |
| `original_draft` | 该字段记录生成原稿。 |
| `edited_draft` | 该字段记录教师编辑稿。 |
| `reviewer_username` | 该字段记录生成时指定审核教师的用户名。 |
| `execution_status` | 该字段记录执行状态。 |
| `outcome` | 该字段记录处理结果。 |
| `superseded` | 该字段表示本次运行是否已被重新生成的运行替代。 |
| `published_post_id` | 该字段记录发布帖子 ID。 |
| `published_text` | 该字段记录已发布帖子当前的 Markdown 正文。 |

## usage

此报表提供“AI 使用情况”中的调用明细。每行对应一条已关联 Run 的原生审计日志，日期筛选使用调用日志创建时间。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `log_id` | 该字段记录 AI 日志 ID。 |
| `run_id` | 该字段记录运行 ID。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `source_post_id` | 该字段记录学生帖子 ID。 |
| `agent_id` | 该字段记录 Agent ID。 |
| `parent_agent_id` | 该字段记录父 Agent ID。 |
| `subagent_depth` | 该字段记录子 Agent 层级。 |
| `feature_name` | 该字段记录 AI 功能。 |
| `llm_id` | 该字段记录模型 ID。 |
| `language_model` | 该字段记录原生日志中的模型名称。 |
| `created_at_utc` | 该字段记录创建时间（UTC）。 |
| `request_tokens` | 该字段记录输入 token 数。 |
| `response_tokens` | 该字段记录输出 token 数。 |
| `cache_read_tokens` | 该字段记录缓存读取的 token 数。 |
| `cache_write_tokens` | 该字段记录缓存写入的 token 数。 |
| `duration_msecs` | 该字段记录耗时（毫秒）。 |
| `response_status` | 该字段记录响应状态。 |
| `outcome` | 该字段记录处理结果。 |
| `estimated_cost` | 该字段记录估算费用（美元）。 |

## usage_summary

此报表提供“AI 使用情况”中的模型汇总。报表按课程、模型 ID 和原生日志中的模型名称汇总所选范围内的调用，并沿用原生的成功与失败统计条件。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `llm_id` | 该字段记录模型 ID。 |
| `language_model` | 该字段记录原生日志中的模型名称。 |
| `call_count` | 该字段记录 LLM 调用数。 |
| `success_count` | 该字段记录成功调用数。 |
| `failure_count` | 该字段记录失败调用数。 |
| `request_tokens` | 该字段记录输入 token 数。 |
| `response_tokens` | 该字段记录输出 token 数。 |
| `cache_read_tokens` | 该字段记录缓存读取的 token 数。 |
| `cache_write_tokens` | 该字段记录缓存写入的 token 数。 |
| `estimated_cost` | 该字段记录估算费用（美元）。 |
| `missing_cost_count` | 该字段记录缺失费用的调用数。 |

## polls

此报表提供“投票与反馈”中的投票汇总。每行对应一个可见投票选项，票数包含原生匿名票数，日期筛选使用投票创建时间。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `post_id` | 该字段记录帖子 ID。 |
| `poll_id` | 该字段记录投票 ID。 |
| `poll_name` | 该字段记录投票名称。 |
| `poll_title` | 该字段记录投票标题。 |
| `poll_type` | 该字段记录原生投票类型。 |
| `option_id` | 该字段记录选项 ID。 |
| `option_html` | 该字段记录原生选项 HTML。 |
| `vote_count` | 该字段记录票数。 |
| `status` | 该字段记录状态。 |
| `created_at_utc` | 该字段记录创建时间（UTC）。 |

## poll_votes

此报表提供“投票与反馈”中的可见投票明细。每行对应一项用户与选项的关系，读取时要求原生规则同时允许查看结果及投票身份。日期筛选使用投票创建时间。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `post_id` | 该字段记录帖子 ID。 |
| `poll_id` | 该字段记录投票 ID。 |
| `poll_name` | 该字段记录投票名称。 |
| `poll_type` | 该字段记录原生投票类型。 |
| `option_id` | 该字段记录选项 ID。 |
| `option_html` | 该字段记录原生选项 HTML。 |
| `user_id` | 该字段记录用户 ID。 |
| `username` | 该字段记录用户名。 |

## feedback

此报表提供“投票与反馈”中的文本反馈，并使用与帖子明细相同的查询。用户需要在页面选择反馈 Topic，平台不会自动推断哪些帖子属于反馈。

| 字段 | 含义 |
| --- | --- |
| `course_id` | 该字段记录课程 ID。 |
| `course_name` | 该字段记录课程名称。 |
| `topic_id` | 该字段记录 Topic ID。 |
| `topic_title` | 该字段记录讨论主题。 |
| `post_id` | 该字段记录帖子 ID。 |
| `post_number` | 该字段记录帖子序号。 |
| `user_id` | 该字段记录用户 ID。 |
| `username` | 该字段记录用户名。 |
| `text` | 该字段记录 Markdown 正文。 |
| `created_at_utc` | 该字段记录创建时间（UTC）。 |
| `updated_at_utc` | 该字段记录修改时间（UTC）。 |
| `reply_to_post_number` | 该字段记录所回复帖子的序号。 |
| `ai_run_id` | 该字段记录教学 AI 运行 ID。 |

完整操作流程见[用户手册](user-manual.md)，接口及运行约束见[技术参考](technical-reference.md)。
