# 0.3.1 技术参考 / Technical reference

本文说明 discourse-educustomize 0.3.1 的实现和运行约束。安装步骤见[安装指南](installation.md)，界面操作见[用户手册](user-manual.md)。

This document describes the implementation and operational constraints of discourse-educustomize 0.3.1. See the [installation guide](installation.md) for deployment and the [user manual](user-manual.md) for interface instructions.

## 1. 架构与依赖 / Architecture and dependencies

插件运行于 Discourse 内部，并通过 Rails 引擎、Ember 组件、插件扩展接口和主题样式提供教学功能。课程页面挂载在 `/educustomize`，管理员配置页面位于 `/admin/plugins/discourse-educustomize/courses`。兼容基线为 Discourse v2026.8.0、Flat 3.0.0 和原生 Foundation；具体提交标识见安装指南及包内 `BUILD-MANIFEST.json`。

The plugin runs inside Discourse and provides teaching features through a Rails engine, Ember components, plugin extension interfaces and theme styles. Course pages are mounted at `/educustomize`, and administrator configuration is available at `/admin/plugins/discourse-educustomize/courses`. The compatibility baseline is Discourse v2026.8.0 with Flat 3.0.0 or native Foundation. The installation guide and packaged `BUILD-MANIFEST.json` identify the exact commits.

账户、分类、群组、帖子和上传文件由 Discourse 管理。Discourse AI 管理原生 Agent、模型、凭据、材料索引和模型审计；Workflows 管理执行、等待审核及恢复流程；Data Explorer 执行受课程权限约束的报表查询。Poll、Assign、Policy、Templates、Solved 和 Events 提供相应的原生教学活动功能。

Discourse manages accounts, categories, groups, posts and uploads. Discourse AI manages native Agents, models, credentials, document indexing and model audits. Workflows manages execution, review waits and resumption, while Data Explorer runs reports within course permissions. Poll, Assign, Policy, Templates, Solved and Events provide the corresponding native teaching activities.

## 2. 配置与权限 / Configuration and permissions

管理员在原生站点设置和“课程配置”页面维护授权。插件使用以下站点设置；模型 ID 和工作流 ID 均来自目标站点的实际记录。

Administrators maintain authorization through native site settings and Course setup. The plugin uses the settings below, and model and workflow IDs refer to actual records on the destination site.

| 设置 / Setting | 作用 / Behavior |
| --- | --- |
| `educustomize_enabled` | 此开关启用教学平台页面和执行入口。 / This setting enables teaching pages and execution entry points. |
| `educustomize_teacher_group` | 此设置指定可以创建课程的教师资格群组。 / This setting identifies the teacher eligibility group whose members can create courses. |
| `educustomize_model_ids` | 此列表指定课程助教可以使用的原生模型记录。 / This list authorizes native model records for course assistants. |
| `educustomize_tool_names` | 此列表授权当前支持的原生课程工具。 / This list authorizes the currently supported native course tools. |
| `educustomize_workflow_ids` | 此列表授权课程可以选择的工作流，平台还会校验其受控结构。 / This list authorizes workflows for courses, and the platform also validates their controlled structure. |

教师资格与具体课程的教师身份分别管理。课程编辑、助教配置、Topic AI、报表和维护接口要求管理员或本课程教师身份，并检查课程分类及相关内容的可见性。学生通过课程成员权限参与讨论；其他课程教师的身份不会自动授予当前课程的管理权限。教师任命、分类安全设置、模型凭据、工具代码和工作流定义由管理员维护。

Teacher eligibility and membership of an individual course's teacher group are managed separately. Course editing, assistant configuration, Topic AI, reports and maintenance require administrator or course-teacher access and check visibility of the course category and relevant content. Students participate through course membership. Being a teacher in another course does not grant management access to this course. Administrators manage teacher appointments, category security, model credentials, tool code and workflow definitions.

“准备教学功能”配置教学活动依赖、标签、模板来源、文件类型和教师申请方式。“准备教学工作流”建立并授权受控模板；重复执行会复用符合要求的模板。知识检索还需要原生嵌入服务、对应的模型选择以及已经完成索引的材料。

Prepare teaching features configures teaching dependencies, tags, template sources, file types and teacher applications. Prepare teaching workflow creates and authorizes the controlled template and reuses a valid template when repeated. Knowledge retrieval additionally requires a native embedding service, a selected embedding model and indexed materials.

## 3. 数据存储 / Data storage

插件在 PostgreSQL 中保存课程关联及教学策略。以下表通过 ID 关联原生资源，正文、模型凭据、上传文件和工作流执行数据仍由对应的原生组件保存。

The plugin stores course relationships and teaching policies in PostgreSQL. The following tables reference native resources by ID. Native components continue to store content, model credentials, uploads and workflow execution data.

| 表 / Table | 内容 / Contents |
| --- | --- |
| `educustomize_courses` | 此表关联课程分类、教师群组、学生群组和创建人。 / This table links course categories, teacher groups, student groups and creators. |
| `educustomize_agent_links` | 此表关联课程和原生 Agent，并保存原始 Prompt 与有序 Skills。 / This table links courses to native Agents and stores their original Prompts and ordered Skills. |
| `educustomize_topic_policies` | 此表保存 Topic 的助教、工作流、审核教师、自动回复、记忆、审核要求和配置修订号。 / This table stores each Topic's assistant, workflow, reviewer, automatic-reply setting, memory setting, review requirement and policy revision. |
| `educustomize_runs` | 此表关联生成请求、来源帖子、发起人、工作流执行和已发布帖子。 / This table associates generation requests with source posts, actors, workflow executions and published posts. |

版本 0.3.1 包含三个数据库迁移，分别创建教学资源表、增加已发布帖子关联，以及增加原始 Prompt 与 Skills。最后一个迁移会保留既有 Agent 的原始提示词，并将其 Skills 初始化为空数组。部署时应通过 Discourse 的迁移流程执行这些文件。

Version 0.3.1 contains three migrations that create teaching resource tables, add published-post references, and add original Prompt and Skills storage. The last migration preserves each existing Agent's original instructions and initializes Skills to an empty array. Deployment should run these files through Discourse's migration process.

## 4. Prompt、Skills 与 Bloc / Prompt, Skills and Bloc

助教表单和 JSON 接口读取原始 `system_prompt` 及独立 `skills`。保存时，`AgentInstructions.compose` 将 Prompt、`## Skills` 标题及按列表顺序排列的技能名称、说明和指令合成为原生 `AiAgent.system_prompt`。Skills 为空时，原始 Prompt 保持原文。组合后的系统提示词最多包含 100000 个字符。

Assistant forms and JSON interfaces read the original `system_prompt` and separate `skills`. On save, `AgentInstructions.compose` combines the Prompt, the `## Skills` heading, and each Skill's name, description and instructions in list order into native `AiAgent.system_prompt`. An empty Skills list leaves the original Prompt unchanged. The composed system prompt is limited to 100,000 characters.

Bloc 使用 Dais 的原生 `subagent_ids` 关联本课程最多 20 个 Delegate。平台拒绝自引用、跨课程引用和嵌套 Delegate。Dais 通过原生子 Agent 工具调用 Delegate，并根据各自的 Prompt 与 Skills 完成分工和汇总。教师应在指令中明确需要调用的 Delegate 及其任务。

A Bloc uses the Dais's native `subagent_ids` to reference up to 20 Delegates in the same course. The platform rejects self-references, cross-course references and nested Delegates. The Dais invokes Delegates through native subagent tools and uses their Prompts and Skills to guide delegation and synthesis. Teachers should identify the required Delegates and their tasks in the instructions.

课程工具范围为管理员授权的 `Time`、`RandomPicker` 和 `SearchUploadedDocuments`。课程执行范围未开放论坛内容读取工具、自定义代码工具、MCP 或其他外部工具。采样开关控制原生 AI 是否发送已保存的 `temperature` 和 `top_p`；供应商仍需支持相应参数。

Course tools are limited to administrator-authorized `Time`, `RandomPicker` and `SearchUploadedDocuments`. Course execution does not expose forum-content retrieval tools, custom code tools, MCP or other external tools. The sampling switch controls whether native AI sends saved `temperature` and `top_p` values, and the provider must support those parameters.

## 5. Topic 执行与审核 / Topic execution and review

每个 Topic 使用一份教学策略。首次配置默认关闭自动回复和 Topic 记忆，并启用教师审核。教师保存配置后，可以对学生帖子手动生成回答；启用自动回复时，符合条件的学生新回复会触发生成。记忆关闭时使用当前触发内容，启用时按当前可见的 Topic 上下文构建请求。

Each Topic has one teaching policy. Initial settings disable automatic replies and Topic memory and require teacher review. After saving the policy, teachers can generate a response to a student post manually. When automatic replies are enabled, eligible new student replies trigger generation. Requests use the triggering content when memory is disabled and the currently visible Topic context when memory is enabled.

生成任务在后台执行，并通过原生 Workflows 保存草稿。需要审核时，指定教师可以编辑和预览 Markdown，再批准、拒绝或重新生成。批准后，平台通过原生发帖流程发布回复，并记录 `published_post_id`。审核记录使用 Discourse 的安全 Markdown 渲染。

Generation runs in the background and stores drafts through native Workflows. When review is required, the assigned teacher can edit and preview Markdown before approving, rejecting or regenerating it. Approval publishes a reply through native post creation and records `published_post_id`. Review records use Discourse's safe Markdown rendering.

平台在执行和发布时重新检查权限及配置，防止已经撤销权限或失效的配置继续运行。请求标识和发布记录用于限制重复执行及重复发布。重新生成会将旧记录标记为已替代，教师需要审核新的结果。管理员修改受控工作流的可执行结构时，需要同时维护适配代码和测试。

The platform rechecks permissions and configuration during execution and publication to prevent revoked permissions or invalid configuration from continuing. Request identifiers and publication records guard against duplicate execution and publication. Regeneration marks the previous record as superseded, and the teacher reviews the new result. Changes to the controlled workflow's executable structure require corresponding adapter and test updates.

Topic 读取接口返回 `ready` 和只读的 `readiness_reasons: string[]`，用于说明当前配置是否满足生成条件。尚未保存策略时，接口返回默认策略和空原因列表；界面会提示先完成初始化。

The Topic read interface returns `ready` and read-only `readiness_reasons: string[]` to explain whether the current configuration permits generation. Before a policy is saved, it returns default settings and an empty reasons list, and the interface asks the user to complete initialization.

## 6. 接口与数据契约 / Interfaces and data contracts

以下路径均相对于 `/educustomize`。浏览器接口沿用 Discourse 登录、CSRF 保护和服务端权限检查。读取 JSON 时可以使用 `.json` 后缀；完整路由定义位于插件的 `config/routes.rb`。

The paths below are relative to `/educustomize`. Browser interfaces use Discourse authentication, CSRF protection and server-side authorization. JSON reads can use a `.json` suffix. The plugin's `config/routes.rb` contains the complete route definitions.

| 方法与路径 / Method and path | 行为 / Behavior |
| --- | --- |
| `GET /courses`、`GET /courses/:id`、`POST /courses`、`PUT /courses/:id` | 这些接口读取、创建和更新课程。 / These interfaces read, create and update courses. |
| `POST /courses/:id/join`、`GET /courses/:course_id/learning` | 这些接口处理加入课程和读取学习工作区。 / These interfaces handle course joining and learning-workspace reads. |
| `GET /courses/:course_id/agents`、`POST /courses/:course_id/agents`、`PUT /courses/:course_id/agents/:id` | 这些接口读取、创建和更新课程助教。 / These interfaces read, create and update course assistants. |
| `POST /courses/:course_id/knowledge-upload` | 此接口接收课程助教的知识材料上传。 / This interface receives course-assistant knowledge uploads. |
| `GET /topics/:topic_id`、`PUT /topics/:topic_id` | 这些接口读取和保存 Topic 教学策略。 / These interfaces read and save Topic teaching policies. |
| `GET /topics/:topic_id/runs`、`POST /topics/:topic_id/runs`、`PUT /topics/:topic_id/runs/:id` | 这些接口读取运行记录、请求生成和提交审核操作。 / These interfaces read run records, request generation and submit review actions. |
| `GET /courses/:course_id/reports`、`POST /courses/:course_id/reports/:key/preview`、`POST /courses/:course_id/reports/:key/download` | 这些接口提供报表选项、预览和下载。 / These interfaces provide report options, previews and downloads. |
| `GET /courses/:course_id/maintenance`、`GET /courses/:course_id/runs` | 这些接口提供运行摘要和筛选后的运行记录。 / These interfaces provide maintenance summaries and filtered run records. |

JSON 配置导出、预览和创建接口详见[配置契约](agent-configuration-format.md)。导入始终在同一事务内创建完整副本，并重新校验模型、工具、名称和关系。该格式排除知识文件、凭据、Topic 绑定、审核教师、工作流策略及讨论记录。

The [configuration contract](agent-configuration-format.md) documents JSON export, preview and creation interfaces. Import creates a complete copy within one transaction and revalidates models, tools, names and relationships. The format excludes knowledge files, credentials, Topic bindings, reviewers, workflow policies and discussions.

## 7. 报表、日志与备份 / Reports, logs and backups

八种报表使用固定查询模板，并在每次请求中检查当前课程权限。预览最多返回 50 行；下载结果达到原生 10000 行上限时，平台会要求用户缩小范围。字段、日期口径、空值和费用含义见[报表字段说明](report-fields.md)。

The eight reports use fixed query templates and check current course permissions on every request. Previews return at most 50 rows. Downloads that reach the native 10,000-row limit require a narrower range. See the [report field reference](report-fields.md) for fields, date semantics, missing values and cost interpretation.

教学模型调用通过原生日志的 `feature_context` 关联课程、Run 和 Agent。教师看到的用量取决于仍然保留且能够归属当前课程的日志。原生工作流执行记录和 AI 日志具有独立保留期；保留天数为 0 时，对应的按天清理停用。已经清理的记录无法通过修改保留期恢复。

Teaching model calls use native log `feature_context` to associate courses, Runs and Agents. Visible usage depends on retained logs that can be attributed to the course. Native workflow execution records and AI logs have separate retention periods. A value of zero disables the corresponding age-based cleanup. Changing retention does not recover deleted records.

完整站点备份需要覆盖数据库、上传文件及部署配置。自行部署的嵌入服务还需要维护其模型、存储和凭据。关闭 `educustomize_enabled` 会停用教学入口，并保留课程关联及原生资源。移除插件前，管理员应处理尚未结束的工作流，并检查保留资源的原生访问权限。

A complete site backup must cover the database, uploads and deployment configuration. A locally hosted embedding service also requires maintenance of its models, storage and credentials. Disabling `educustomize_enabled` disables teaching entry points while retaining course relationships and native resources. Before removing the plugin, administrators should resolve pending workflows and review native access permissions for retained resources.

## 8. 兼容性与扩展边界 / Compatibility and extension boundaries

Workflows 在兼容基线中属于实验性组件。升级 Discourse、AI、Workflows 或主题后，应在隔离环境中检查课程权限、Prompt 与 Skills、Bloc 调用、生成审核、JSON 往返、材料检索、报表及界面导航。正式部署还需要根据实际环境确认生产负载、附件直链保护和设备可用性。

Workflows is experimental in the compatibility baseline. After upgrading Discourse, AI, Workflows or a theme, verify course permissions, Prompt and Skills behavior, Bloc calls, generation and review, JSON round trips, document retrieval, reports and navigation in an isolated environment. Production deployments also need to assess load, direct attachment protection and device usability for their environment.

平台当前提供课程教学及其运行数据管理。外部问卷自动同步、独立研究归档、服务器运维和自动学习成效评估不在当前功能范围内。扩展工具或工作流时，应继续维护课程权限和讨论上下文边界。

The platform currently provides course teaching and management of its operational data. Automatic external survey synchronization, a separate research archive, server operations and automatic learning-outcome assessment are outside its current scope. Extensions to tools or workflows must preserve course permissions and discussion-context boundaries.
