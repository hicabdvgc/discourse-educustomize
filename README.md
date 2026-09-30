# discourse-educustomize 0.3.1

本插件为 Discourse 提供课程管理、AI 助教、多个 Delegate 协作的 Bloc、Topic 生成与教师审核、JSON 配置迁移、教学报表及运行维护入口。管理员、教师和学生可以通过中英文界面、五个课程工作区和按需展开的使用指引完成操作。

This plugin provides course management, AI assistants, Blocs with multiple Delegates, Topic generation and teacher review, JSON configuration migration, teaching reports and maintenance for Discourse. Administrators, teachers and students use a bilingual interface, five course workspaces and on-demand guides to complete their workflows.

## 安装与使用 / Installation and use

本版本的兼容基线为 Discourse **v2026.8.0**、Flat **3.0.0** 和原生 Foundation。部署需要保留安装指南列出的原生插件，并完成数据库迁移。管理员需要配置教师资格、模型凭据、课程授权、教学工作流及知识检索所需的嵌入服务。

The compatibility baseline is Discourse **v2026.8.0** with Flat **3.0.0** or native Foundation. Deployment must retain the bundled plugins listed in the installation guide and run database migrations. Administrators configure teacher eligibility, model credentials, course authorization, the teaching workflow and any embedding service needed for retrieval.

发布 ZIP 包含完整插件源码和当前版本文档。其顶层目录为 `discourse-educustomize/`，需要安装到 Discourse 服务器的插件目录。模型凭据、知识文件、课程数据和嵌入服务由部署方配置和管理。

The release ZIP contains the complete plugin source and current-version documentation. Its top-level `discourse-educustomize/` directory belongs in the Discourse server's plugin directory. The deployment administrator configures and manages model credentials, knowledge files, course data and embedding services.

- 管理员可以按照[安装指南](docs/installation.md)完成首次部署、配置和升级。 / Administrators can follow the [installation guide](docs/installation.md) for deployment, configuration and upgrades.
- 管理员、教师和学生可以按照[用户手册](docs/user-manual.md)完成各自的操作。 / Administrators, teachers and students can follow the [user manual](docs/user-manual.md) for their workflows.
- 维护人员可以查阅[技术参考](docs/technical-reference.md)、[JSON 配置契约](docs/agent-configuration-format.md)和[报表字段说明](docs/report-fields.md)。 / Maintainers can consult the [technical reference](docs/technical-reference.md), [JSON configuration contract](docs/agent-configuration-format.md) and [report field reference](docs/report-fields.md).
- 完整文档、JSON Schema 和 Bloc 示例均可从[文档导航](docs/README.md)找到。 / The [documentation index](docs/README.md) links to all guides, the JSON Schema and the Bloc example.

## 功能与运行约束 / Features and operational constraints

教师可以分别编辑 Prompt 与 Skills，选择管理员授权的模型和工具，并上传知识材料。Bloc 使用一个 Dais 和最多 20 个同课程 Delegate。Topic 设置决定上下文、自动回复、工作流和审核教师。JSON 导入会创建完整配置副本，知识材料需要在目标站点重新上传。

Teachers can edit Prompt and Skills separately, select administrator-authorized models and tools, and upload knowledge materials. A Bloc uses one Dais and up to 20 Delegates from the same course. Topic settings determine context, automatic replies, workflow and reviewer. JSON import creates complete configuration copies, and knowledge materials must be uploaded again on the destination site.

课程工具范围为 `Time`、`RandomPicker` 和 `SearchUploadedDocuments`；Bloc 通过原生子 Agent 调用实现协作。平台沿用原生账户、帖子、群组、模型、知识索引和工作流记录。Workflows 在兼容基线中属于实验性组件，部署方应按技术参考检查环境适用性。

Course tools are limited to `Time`, `RandomPicker` and `SearchUploadedDocuments`, and Blocs collaborate through native subagent calls. The platform uses native accounts, posts, groups, models, knowledge indexes and workflow records. Workflows is experimental in the compatibility baseline, so deployments should review the environmental requirements in the technical reference.

## 许可 / License

插件代码采用 [MIT 许可](LICENSE)。第三方骨架的许可与署名见[第三方说明](THIRD_PARTY_NOTICES.md)。

The plugin code uses the [MIT License](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) for the source skeleton's license and attribution.
