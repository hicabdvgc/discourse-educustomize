# 0.3.1 安装与配置 / Installation and configuration

本插件为 Discourse 提供完整的课程工作区、助教与 Bloc 配置、JSON 迁移、Topic 生成与审核、课程报表及维护入口。新站点完成下述一次性配置后即可使用这些功能，无须导入开发站点的数据库或修改 Discourse 和 Flat 的源码。实际模型调用需要您自己的模型凭据，知识检索还需要可用的嵌入向量服务。

This plugin provides course workspaces, assistant and Bloc configuration, JSON migration, Topic generation and review, reports and maintenance. Complete the initial configuration below to use these features on a new site. You do not need the development site's database or source patches to Discourse or Flat. Model requests require your own credentials, and knowledge retrieval also requires an embedding service.

## 1. 安装兼容版本 / Install compatible versions

本版本的兼容基线为 Discourse **v2026.8.0**（`badad7b0456a628e578bc48b9f8c1259422b5d58`）及 Flat **3.0.0**（`2b6ee15f863d47a97fffce82484fb969c82c8a36`）。其他版本需要另行验收。选择允许安装自定义插件的自托管部署。Discourse 的原生 AI、Workflows、Data Explorer、Poll、Assign、Policy、Templates、Solved 和 Events 已随这个 Discourse 版本提供，应保留它们。

The validated versions are Discourse **v2026.8.0** and Flat **3.0.0**, at the commits above. Other versions require separate verification. Use a self-hosted deployment that permits custom plugins, and retain the bundled plugins listed above.

通过管理员的主题安装页面，从 [Flat 仓库](https://github.com/0niel/discourse-flat-theme) 安装主题，并将上述提交作为安装版本。将 Flat 设为默认主题，并在主题设置中选择其浅色和深色配色，以提供三种界面模式。原生 Foundation 也受到支持。

Install [Flat](https://github.com/0niel/discourse-flat-theme) from the administrator's theme page at the commit above, set it as the default theme, and select its light and dark color palettes. Foundation is also supported.

## 2. 安装插件 / Install the plugin

ZIP 顶层目录为 `discourse-educustomize/`，其中直接包含 `plugin.rb`。ZIP 是服务器插件源码包，不能上传到主题安装页面。压缩包中的 `FILES.sha256` 可用于核对文件完整性。

The ZIP contains a top-level `discourse-educustomize/` directory with `plugin.rb` directly inside it. It is a server plugin source archive, so it cannot be uploaded as a theme. `FILES.sha256` records the packaged file checksums.

源码部署时，将该目录放到 Discourse 的 `plugins/` 下，然后在 Discourse 根目录运行 `bin/rake db:migrate`，并重启完整服务。

For a source deployment, place this directory under Discourse's `plugins/`, run `bin/rake db:migrate` from the Discourse root, and restart the complete service.

标准 Docker 部署时，应将压缩包内容放入您可控的 Git 仓库，并将该仓库的克隆命令合并到 `containers/app.yml` 的 `hooks.after_code` 中，再执行 `./launcher rebuild app`。请按照 [Discourse 官方插件安装说明](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157) 保留现有命令的用户前缀和缩进。部署仓库应包含本发布包的完整源码；管理员可以通过包内版本及校验值核对内容。重新构建时，所有插件源码都需要能通过这些部署配置重新获取。

For a standard Docker deployment, put the archive contents in a Git repository that your deployment can access, merge its clone command into `hooks.after_code` in `containers/app.yml`, and run `./launcher rebuild app`. Follow the [official installation instructions](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157), retaining the existing user prefix and indentation. The deployment repository must contain the complete source from this release. Use the packaged version and checksums to verify its contents. The deployment configuration must retrieve the plugin again on subsequent rebuilds.

## 3. 启用依赖及界面选项 / Enable dependencies and interface options

管理员需要启用 `educustomize_enabled`、`discourse_ai_enabled`、`enable_category_group_moderation` 和 `data_explorer_enabled`。为允许登录用户和访客切换中文与英文，还需要启用 `allow_user_locale` 和 `set_locale_from_cookie`。

An administrator must enable `educustomize_enabled`, `discourse_ai_enabled`, `enable_category_group_moderation` and `data_explorer_enabled`. Enable `allow_user_locale` and `set_locale_from_cookie` so both signed-in users and visitors can switch between Chinese and English.

此兼容版本的 `enable_discourse_workflows` 属于隐藏的实验性设置。管理员可以通过“即将推出的更改”查看实验性功能并启用 Workflows；如果管理界面没有显示该选项，服务器管理员可在 Discourse 的 Rails 控制台执行以下命令。控制台入口为 `bin/rails c`；标准 Docker 部署应先执行 `./launcher enter app`，再运行 `rails c`。

In this Discourse version, `enable_discourse_workflows` is a hidden experimental setting. Administrators can look for Workflows among experimental upcoming changes. If it is not exposed in the interface, the server administrator can run the following command in the Rails console. Use `bin/rails c` for a source deployment, or enter a standard Docker container with `./launcher enter app` and run `rails c`.

```ruby
SiteSetting.enable_discourse_workflows = true
```

## 4. 准备教师与教学功能 / Prepare teachers and teaching features

1. 管理员创建一个自定义教师资格群组，并将其指定为 `educustomize_teacher_group`。群组所有者应为管理员，公开直接加入应处于关闭状态。
2. 管理员打开“插件 → 课程配置”，点击“准备教学功能”。此操作会配置原生教学插件、教学标签、模板分类、附件类型及需要审核的教师申请。
3. 管理员在同一页面点击“准备教学工作流”。平台会建立并授权受控工作流，重复点击会复用已经准备好的模板。
4. 管理员审批教师资格，课程教师随后可以创建课程并管理学生成员。

1. Create a custom teacher eligibility group and select it as `educustomize_teacher_group`. Its owners must be administrators, and direct public admission must be disabled.
2. Open Plugins → Course setup and select Prepare teaching features. This prepares native teaching plugins, activity tags, a template category, file types and reviewed teacher applications.
3. Select Prepare teaching workflow on the same page. The platform creates and authorizes the controlled workflow and reuses it on subsequent preparation.
4. Approve teacher membership so teachers can create courses and manage their students.

## 5. 接入模型与知识检索 / Connect models and knowledge retrieval

管理员通过课程配置页的“模型凭据”和“配置原生 AI 模型”进入原生后台，保存自己的凭据与模型配置，并测试连接。将实际模型 ID 填入 `educustomize_model_ids`。这些 ID 是目标站点的数据库记录 ID，与供应商的模型名称不同。

Use Model credentials and Configure native AI models on the course setup page to save your own credentials and models and test their connections. Add the resulting model IDs to `educustomize_model_ids`; these database record IDs are distinct from the provider’s model names.

将课程需要使用的工具加入 `educustomize_tool_names`；支持的名称为 `Time`、`RandomPicker` 和 `SearchUploadedDocuments`。如需采样参数，管理员在课程配置页启用“发送原生 temperature 和 top_p 参数”，并确认供应商支持这些参数。

Authorize the required tools through `educustomize_tool_names`. Supported names are `Time`, `RandomPicker` and `SearchUploadedDocuments`. To use sampling parameters, enable Send native temperature and top_p parameters in Course setup and confirm that the model provider supports them.

知识检索需要通过“知识嵌入向量”配置可用的嵌入模型。您可以使用自己的远程服务或自行部署的本地服务。模型权重、服务端点和凭据都需要在目标站点单独配置。将知识材料上传到助教后，应在“运行与维护”确认索引完成。用于学生阅读的附件上传到讨论帖子，供 AI 检索的材料上传到助教。

Configure an embedding model through Knowledge embeddings. You can use your own remote service or a locally hosted service. Model weights, endpoints and credentials must be configured for the destination site. After uploading knowledge materials to an assistant, confirm their indexing status in Runtime and maintenance. Attach student reading materials to discussion posts and AI retrieval materials to assistants.

## 6. 完成一次教学验证 / Complete a teaching check

教师创建课程和助教，填写 Prompt 与 Skills，选择授权模型并启用助教。需要多个助教协作时，在 Bloc 工作区选择 Dais 和多个 Delegate。随后创建课程 Topic，在其 AI 设置中选择助教或 Dais、教学工作流和审核教师，保存后选择一条学生回复并生成回答。指定教师应能查看、编辑、预览和批准草稿，批准后的回复应出现在讨论中。

Create a course and an assistant, enter its Prompt and Skills, select an authorized model and enable the assistant. For collaboration, choose a Dais and multiple Delegates in Bloc. Create a course Topic, select its assistant or Dais, workflow and reviewing teacher in AI settings, and save. Generate a response to a student reply, then verify that the assigned teacher can inspect, edit, preview and approve the draft and that the published response appears in the discussion.

最后检查 JSON 导出与导入、数据预览与下载，以及运行记录。JSON 导入会创建新副本，知识材料需要重新上传。完整操作方法见[中英文用户手册](user-manual.md)。

Finally, check JSON export and import, report preview and download, and run records. JSON import creates separate copies, and their knowledge materials must be uploaded again. See the [bilingual user manual](user-manual.md) for detailed instructions.

## 从旧版本升级 / Upgrade an existing installation

从 0.3.0 升级到 0.3.1 时，数据库结构和现有配置保持一致。此补丁更新了模型的表结构注释，没有新增数据库迁移。管理员按下述标准流程替换源码并重启服务即可。

When upgrading from 0.3.0 to 0.3.1, the database structure and existing configuration remain unchanged. This patch updates the model schema annotations and adds no database migrations. Administrators can replace the source and restart services using the standard procedure below.

升级前应备份数据库和 uploads。0.3.1 包含 `20260929073918` 迁移，为 Agent 关联保存原始 Prompt 和独立 Skills，并保留既有提示词内容。请在替换源码后运行迁移，并重启 Rails 和后台任务；标准 Docker 重建会执行该流程。已有课程、Topic 绑定、模型、凭据及材料继续使用原来的记录。

Back up the database and uploads before upgrading. Version 0.3.1 includes migration `20260929073918`, which stores original Prompts and separate Skills while preserving existing instructions. Run migrations after replacing the source and restart Rails and background jobs; a standard Docker rebuild performs this process. Existing courses, Topic bindings, models, credentials and materials retain their records.

## 备份与停用 / Backups and disabling

管理员应同时备份数据库、上传文件和部署配置，并按所用服务的要求保存模型与嵌入服务配置。发布 ZIP 包含插件源码和文档，运行数据与凭据由目标站点维护。需要暂时停用教学平台时，可以关闭 `educustomize_enabled`；课程关联和原生资源会继续保留。移除插件前，应处理尚未结束的工作流，并检查保留资源的访问权限。

Administrators should back up the database, uploads and deployment configuration and retain model and embedding service settings as required by those services. The release ZIP contains plugin source and documentation, while the destination site maintains runtime data and credentials. To disable teaching features temporarily, turn off `educustomize_enabled`; course relationships and native resources remain stored. Before removing the plugin, resolve pending workflows and review access permissions for retained resources.

系统架构、数据表及运行约束见[技术参考](technical-reference.md)，完整文档入口见[文档导航](README.md)。

See the [technical reference](technical-reference.md) for architecture, tables and operational constraints, or use the [documentation index](README.md) to find other instructions.
