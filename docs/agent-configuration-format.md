# Agent configuration JSON / 助教 JSON 配置契约

本文适用于 0.3.1 的助教 JSON 配置，其 `schema_version` 为 1。权威字段契约为 [JSON Schema](../config/agent-configuration.schema.json)，完整三助教文件见 [Bloc 示例](examples/bloc.json)。Schema 使用 JSON Schema draft 2020-12；服务端导入、导出与 Skills 校验共用此文件。

The configuration used by version 0.3.1 has `schema_version: 1`. The [JSON Schema](../config/agent-configuration.schema.json) defines every field. The [complete Bloc example](examples/bloc.json) contains one Dais and two Delegates. Import, export and Skills validation share this draft 2020-12 schema.

## 文件与关系 / Document and graph

UTF-8 JSON 顶层必须包含 `format: "discourse-educustomize/agent-config"`、`schema_version: 1`、`root` 和 `agents`。所有层级拒绝未知字段。`root` 和 `delegates` 引用文件内唯一的 `key`，与目标平台 ID 无关。单助教文件包含一个根节点；Bloc 包含一个 Dais 及其直接 Delegate，最多 21 个 Agent。所有节点必须属于根节点的完整关系图，禁止缺失引用、自引用、循环、嵌套及无关联节点。

A UTF-8 document requires `format: "discourse-educustomize/agent-config"`, `schema_version: 1`, `root` and `agents`. Unknown fields are rejected at every level. Root and Delegate references use unique in-file keys, independent of destination IDs. A single assistant has one root; a Bloc has a Dais and its direct Delegates, up to 21 agents in total. Missing references, self-references, cycles, nesting and disconnected nodes are rejected.

| Agent 字段 / Field | 内容 / Meaning |
| --- | --- |
| `key` | 此字段是文件内引用，由 1–100 个字母、数字、下划线或连字符组成。 / This field is an in-file reference containing 1–100 letters, digits, underscores or hyphens. |
| `name`, `description` | 这两个字段分别保存名称和介绍，最多为 100 和 2000 个字符，均须包含非空白内容。 / These fields store the name and description, allow at most 100 and 2,000 characters respectively, and require nonblank content. |
| `system_prompt` | 此字段保存原始 Prompt，并保留空格和换行。 / This field stores the original Prompt and preserves its whitespace and line breaks. |
| `skills` | 此字段是最多包含 100 项的有序数组，每项包含 `name`、`description` 和 `instructions`。 / This field is an ordered array of up to 100 entries, each containing `name`, `description` and `instructions`. |
| `model` | 此字段保存含 `provider`、`name` 和 `display_name` 的模型描述对象，未选择模型时为 `null`。 / This field stores a model descriptor with `provider`, `name` and `display_name`, or `null` when no model is selected. |
| `enabled` | 此字段使用布尔值表示助教是否启用。 / This Boolean field indicates whether the assistant is enabled. |
| `temperature`, `top_p` | 这两个字段接受数字或 `null`，数字范围分别为 0–2 和 (0,1]。 / These fields accept numbers or `null`, with numeric ranges of 0–2 and (0,1] respectively. |
| `tools` | 此字段保存已授权工具的名称数组，元素须唯一。 / This field stores an array of authorized tool names, and its entries must be unique. |
| `delegates` | 此字段保存最多 20 个子助教 key，元素须唯一。 / This field stores up to 20 Delegate keys, and its entries must be unique. |

Prompt 与 Skills 组合后的系统提示词最多 100000 字符。保存原始内容后，按顺序追加 `## Skills`、每项 `### 名称`、说明及指令正文，交给原生 AiAgent 执行。知识文件、上传关联、API 密钥、凭据、Topic 绑定、审核人、工作流策略和讨论记录均独立于本格式。

The composed system prompt is limited to 100000 characters. Raw Prompt and Skills are stored separately; native AiAgent receives Prompt followed by `## Skills`, then each `### name`, description and instructions in order. Knowledge files, upload associations, API keys, credentials, Topic bindings, reviewers, Topic workflow policies and discussions are outside this format.

## API

以下路径以 `/educustomize/courses/:course_id` 为前缀，均要求管理员或本课程教师权限，并沿用站点认证与 CSRF 保护。

All paths below are relative to `/educustomize/courses/:course_id`. They require administrator or course-teacher access and use existing authentication and CSRF protection.

| 方法与路径 / Method and path | 请求与结果 / Request and response |
| --- | --- |
| `GET /agents/:agent_id/configuration.json` | 下载已保存的完整根节点配置。 / Download the saved root configuration with its Delegates. |
| `POST /agent-configurations/preview.json` | 此接口接收 `{document}`，并返回 `{document, model_mappings}`。 / Submit a document; receive normalized proposed names and model mappings. |
| `POST /agent-configurations.json` | 此接口接收 `{document, model_mappings}`，并在成功时返回 HTTP 201 和 `{agent_id, agent_ids}`。 / Create a complete copy; receive root ID and key-to-ID mapping. |

预览将名称冲突改为本地化的“副本 2”等唯一建议值，保持 Prompt 正文原样。模型按授权范围内的 provider + name 唯一匹配；缺失或多候选返回空映射，提交前必须选择目标模型。`model_mappings` 是 key 到目标整数模型 ID 的对象；`model: null` 对应空映射。提交可选择其他授权模型。预览无需创建数据库记录。

Preview proposes localized unique names such as “copy 2” while retaining Prompt verbatim. Models auto-map only when provider and name uniquely match an authorized model. Missing or ambiguous matches require manual selection. Model mappings associate in-file keys with authorized integer model IDs; a null model has a null mapping. Users may select another authorized model. Preview creates no records.

服务器提交时重新验证，按 Delegate、Dais 的顺序在同一事务中创建 Agent、关联和审计；任一步骤失败全部回滚。非法版本、未知字段、类型、关系、工具或模型映射返回具体错误（422）；未授权访问返回 403，缺失资源遵循既有 404 行为。未登录请求遵循站点登录要求。

Submission revalidates the document and atomically creates Delegates, the Dais, links and audit records. Any failure rolls back the transaction. Invalid versions, fields, types, relations, tools or mappings produce detailed 422 errors. Unauthorized access returns 403, missing resources use existing 404 behavior, and unauthenticated requests follow site login requirements.

既有 Agent 创建、更新和读取接口同时包含 `skills` 与原始 `system_prompt`。导出检查当前工具授权；已撤销工具应先由管理员恢复授权或由教师移除后再导出。

Existing Agent create, update and read APIs include Skills and the original system prompt. Export also checks current tool authorization; restore authorization or remove revoked tools before exporting.
