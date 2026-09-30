# Kassel AI 教学平台用户手册 / User manual

本手册适用于 **discourse-educustomize 0.3.1**，并于 **2026 年 9 月 30 日**完成修订。已验证的运行环境为 Discourse **v2026.8.0** 及其附带的 AI、Workflows 和 Data Explorer，界面支持 Flat **3.0.0** 与 Foundation。

This manual describes **discourse-educustomize 0.3.1** and was revised on **30 September 2026**. The verified environment uses Discourse **v2026.8.0** with its bundled AI, Workflows and Data Explorer plugins. The interface supports Flat **3.0.0** and Foundation.

本手册按章节提供对应的中英文说明。管理员首次部署时应先阅读 [0.3.1 安装指南](installation.md)，系统架构、接口和功能边界见[技术参考](technical-reference.md)。本手册中的站内路径均相对于您部署的平台地址。

Each section provides corresponding Chinese and English instructions. Administrators should begin a new deployment with the [0.3.1 installation guide](installation.md). The [technical reference](technical-reference.md) explains the architecture, interfaces and feature boundaries. Site paths in this manual are relative to your deployed platform address.

## 目录 / Contents

1. [角色与导航 / Roles and navigation](#1-角色与导航--roles-and-navigation)
2. [安装 Discourse / Install Discourse](#2-安装-discourse--install-discourse)
3. [安装、升级插件 / Install and upgrade the plugin](#3-安装升级插件--install-and-upgrade-the-plugin)
4. [管理员首次配置 / Initial administration](#4-管理员首次配置--initial-administration)
5. [注册、登录与个人资料 / Accounts and profile](#5-注册登录与个人资料--accounts-and-profile)
6. [配色与语言 / Colors and language](#6-配色与语言--colors-and-language)
7. [教师资格与课程成员 / Teacher approval and membership](#7-教师资格与课程成员--teacher-approval-and-membership)
8. [课程和学习工作区 / Courses and workspace](#8-课程和学习工作区--courses-and-workspace)
9. [发帖、回复与管理 / Topics, replies and management](#9-发帖回复与管理--topics-replies-and-management)
10. [公告、材料、问答与反馈 / Learning activities](#10-公告材料问答与反馈--learning-activities)
11. [模型与密钥 / Models and credentials](#11-模型与密钥--models-and-credentials)
12. [本地向量服务 / Local embeddings](#12-本地向量服务--local-embeddings)
13. [教师 AI 配置 / Teacher AI configuration](#13-教师-ai-配置--teacher-ai-configuration)
14. [知识材料 / Knowledge materials](#14-知识材料--knowledge-materials)
15. [Bloc 与 Delegate / Blocs and Delegates](#15-bloc-与-delegate--blocs-and-delegates)
16. [Topic 策略与记忆 / Topic policy and memory](#16-topic-策略与记忆--topic-policy-and-memory)
17. [生成与审核 / Generation and review](#17-生成与审核--generation-and-review)
18. [运行状态、用量与费用 / Operations, usage and cost](#18-运行状态用量与费用--operations-usage-and-cost)
19. [数据预览与导出 / Preview and export](#19-数据预览与导出--preview-and-export)
20. [保留期、备份与维护 / Retention, backups and maintenance](#20-保留期备份与维护--retention-backups-and-maintenance)
21. [故障处理 / Troubleshooting](#21-故障处理--troubleshooting)
22. [角色操作示例与边界 / Walkthroughs and boundaries](#22-角色操作示例与边界--walkthroughs-and-boundaries)
23. [JSON 配置迁移 / JSON configuration migration](#23-json-配置迁移--json-configuration-migration)
24. [页面内指引与保存 / In-page guidance and saving](#24-页面内指引与保存--in-page-guidance-and-saving)

## 1. 角色与导航 / Roles and navigation

| 角色 / Role | 可用功能 / Available capabilities |
| --- | --- |
| 管理员 / Administrator | 管理员可以管理全站用户、教师资格、模型凭据、插件、主题、课程配置、日志、备份和保留期，也可以选择课程查看报表与运行记录。 / Administrators can manage users, teacher eligibility, model credentials, plugins, themes, course settings, logs, backups and retention across the site. They can also select a course to inspect its reports and run records. |
| 本课程教师 / Course teacher | 教师可以管理自己负责的课程、学生成员、教学讨论、助教、Bloc、知识材料和 AI 策略，并按权限审核回复、查看用量和导出数据。 / Teachers can manage their assigned courses, student membership, discussions, assistants, Blocs, knowledge materials and AI policies. Their permissions also determine which replies they can review and which usage records and exports they can access. |
| 学生 / Student | 学生可以加入课程、阅读材料、参与讨论、创建课程允许的 Topic，以及提交投票和文字反馈。 / Students can join courses, read materials, participate in discussions, create Topics where permitted, and submit votes or written feedback. |

教师资格决定用户能否创建课程，课程教师群组则决定用户负责哪些课程。某门课程的教师不会自动获得其他课程的管理权限。平台会根据权限显示入口，服务器也会校验实际请求。每个 Topic 的审核决定由该 Topic 指定的审核教师执行；管理员查看审核记录时仍需遵守这一指定关系。

Teacher eligibility determines whether a user can create courses, while course teacher groups determine which courses the user manages. Teaching one course does not automatically grant access to another course's management functions. The interface displays authorized entry points, and the server checks each request. The reviewing teacher assigned to a Topic makes its review decisions; administrator access to a record does not change that assignment.

用户可以通过以下入口访问主要功能。

Users can reach the main functions through the following entry points.

- 侧栏中的“课程 / Courses”会打开课程目录，用户可以从目录进入课程学习工作区。 / The “Courses” sidebar link opens the course catalog, which provides access to each course's learning workspace.
- “课程管理 / Course management”会打开课程资料、成员和 AI 配置的编辑工作区。 / “Course management” opens the workspaces for course details, membership and AI configuration.
- 课程导航中的“数据导出 / Data export”和“运行与维护 / Runtime and maintenance”分别提供报表与运行检查入口。 / “Data export” and “Runtime and maintenance” in the course navigation open reports and operational checks.
- Topic 中的“AI 设置 / AI settings”会打开该讨论的回复配置、生成操作和审核记录。 / “AI settings” in a Topic opens its reply configuration, generation controls and review records.
- 管理员可以从“管理员 → 插件 → 课程配置 / Admin → Plugins → Course setup”准备教学功能、维护授权并进入相关原生后台。 / Administrators can use “Admin → Plugins → Course setup” to prepare teaching features, maintain authorization and open the relevant native administration pages.
- 用户可以从头像菜单打开个人资料、偏好设置和通知，也可以在该菜单中退出登录。 / Users can open their profile, preferences and notifications from the avatar menu, which also provides the sign-out action.

## 2. 安装 Discourse / Install Discourse

### 云端 / Cloud

管理员需要选择允许安装自定义插件的自托管部署或托管方案，并准备 Linux 服务器、站点域名和 HTTPS。使用本地邮箱与密码注册的站点还需要配置邮件服务。管理员可以按照 [Discourse 官方安装指南](https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md)，在新的服务器上运行以下安装命令。

Administrators need a self-hosted deployment or a hosting plan that permits custom plugins, together with a Linux server, a site domain and HTTPS. Sites that use local email and password registration also need a mail service. The [official Discourse installation guide](https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md) provides the following installer command for a new server.

```sh
wget -qO- https://raw.githubusercontent.com/discourse/discourse_docker/main/install-discourse | sudo bash
```

管理员需要按安装向导填写域名、管理员邮箱及登录或邮件配置，并在建站后使用对应邮箱完成管理员注册和站点向导。官方安装器可能选择较新的 Discourse 版本。本插件的验证基线为 v2026.8.0，其他版本需要先在预发布环境中验证。

Administrators complete the installation prompts for the domain, administrator email and authentication or email settings, then register the administrator account and finish the site wizard. The installer may select a newer Discourse release. This plugin was verified against v2026.8.0, so other versions require validation in staging.

此基线版本已附带 AI、Workflows、Data Explorer、Poll、Assign、Policy、Templates、Solved 和 Events 等原生插件。管理员需要保留这些组件，才能按本手册启用相应功能。

The baseline release includes native plugins such as AI, Workflows, Data Explorer, Poll, Assign, Policy, Templates, Solved and Events. Administrators need to retain these components to enable the corresponding features described in this manual.

### 现有站点 / Existing sites

管理员为现有站点安装插件前，应确认 Discourse 版本、原生依赖和主题符合兼容要求，并备份数据库、上传文件和部署配置。安装过程应沿用现有数据库与账户，并按站点实际部署方式执行插件安装和服务重启。

Before adding the plugin to an existing site, administrators should confirm that its Discourse version, bundled dependencies and theme meet the compatibility requirements and back up the database, uploads and deployment configuration. Installation should retain the existing database and accounts and follow the plugin installation and service restart procedure for that deployment.

## 3. 安装、升级插件 / Install and upgrade the plugin

新站点管理员应先完成 [0.3.1 安装指南](installation.md) 中的步骤。发布 ZIP 包含服务器插件源码，其顶层目录为 `discourse-educustomize/`，该目录内直接包含 `plugin.rb`。管理员需要将插件安装到服务器的插件目录，主题上传入口无法安装这个源码包。

Administrators of a new site should follow the [0.3.1 installation guide](installation.md). The release ZIP contains server plugin source inside a top-level `discourse-educustomize/` directory, with `plugin.rb` directly inside it. The plugin must be installed in the server's plugin directory; the theme upload interface cannot install this archive.

### 源码安装 / Source installation

1. 管理员需要将压缩包中的 `discourse-educustomize/` 目录解压到 Discourse 的 `plugins/` 目录。升级已有插件前，管理员应备份数据库和上传文件，停止相关服务，再替换插件源码。
2. 管理员需要从 Discourse 根目录运行 `bin/rake db:migrate`，然后重新启动完整服务。0.3.1 包含 Prompt 与 Skills 迁移 `20260929073918`；首次安装和升级时均应运行迁移检查，已经执行的迁移会自动跳过。
3. 管理员需要在“管理员 → 插件”中确认插件版本和启用状态，再完成下一节的首次配置。

1. Administrators extract the `discourse-educustomize/` directory into Discourse's `plugins/` directory. Before upgrading an existing plugin, they back up the database and uploads, stop the relevant services, and replace the plugin source.
2. Administrators run `bin/rake db:migrate` from the Discourse root and restart the complete service. Version 0.3.1 includes Prompt and Skills migration `20260929073918`. Run the migration check on both new installations and upgrades; migrations that have already run are skipped automatically.
3. Administrators confirm the plugin version and enabled state under “Admin → Plugins” before completing the initial configuration in the next section.

### 标准 Docker 云端安装 / Standard Docker deployment

管理员需要将本次发布包的源码提交到部署环境可访问的插件 Git 仓库，并按照 [官方插件安装说明](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157)，将该仓库的克隆命令合并到 `/var/discourse/containers/app.yml` 已有的 `hooks.after_code` 中。管理员应保留原有命令、用户前缀和 YAML 缩进，再执行以下重建命令。

Administrators commit this release's source to a Git repository that the deployment can access. They then follow the [official plugin installation instructions](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157) to merge that repository's clone command into the existing `hooks.after_code` in `/var/discourse/containers/app.yml`, preserving existing commands, user prefixes and YAML indentation. The following commands rebuild the application.

```sh
cd /var/discourse
./launcher rebuild app
```

管理员需要为私有仓库配置部署读权限，并确认远端包含 0.3.1 的完整源码。发布包的版本和校验文件可用于核对部署仓库中的源码。真实访问令牌应保存在部署的凭据管理中。目标 Discourse 已附带的原生插件无需重复克隆。

Administrators configure deployment read access for a private repository and confirm that it contains the complete 0.3.1 source. The release version and checksum files can be used to verify the source in the deployment repository. Real access tokens belong in deployment credential management. Native plugins already bundled with the target Discourse release do not need another clone command.

标准 Docker 重建会执行插件迁移并更新服务。升级前的备份应包含数据库和上传文件，升级后管理员应重新检查插件状态。源码包不包含课程数据、用户账户、API 密钥、主题数据库或向量模型权重。`FILES.sha256` 用于核对包内文件，外部 `SHA256SUMS` 用于核对整个 ZIP。

A standard Docker rebuild runs plugin migrations and updates the services. Administrators should back up the database and uploads before upgrading and check the plugin state afterward. The source archive excludes course data, user accounts, API keys, theme database records and embedding model weights. `FILES.sha256` verifies individual packaged files, while the external `SHA256SUMS` verifies the ZIP.

## 4. 管理员首次配置 / Initial administration

管理员需要先启用依赖并建立教师资格群组，再准备教学功能和工作流，最后配置模型与知识检索。以下设置决定相应功能是否可用。

Administrators first enable dependencies and establish the teacher eligibility group, then prepare teaching features and workflows, and finally configure models and knowledge retrieval. The following settings control the corresponding capabilities.

| 设置 / Setting | 用途 / Purpose |
| --- | --- |
| `educustomize_enabled` | 此设置启用教学平台插件。 / This setting enables the teaching platform plugin. |
| `discourse_ai_enabled` | 此设置启用原生 AI 功能。 / This setting enables native AI features. |
| `enable_discourse_workflows` | 此设置启用原生 Workflows，教学回复流程依赖该组件。 / This setting enables native Workflows, which the teaching reply process requires. |
| `enable_category_group_moderation` | 此设置允许通过课程教师群组管理相应分类。 / This setting enables category moderation through the course teacher group. |
| `data_explorer_enabled` | 此设置启用课程报表所需的 Data Explorer。 / This setting enables Data Explorer, which course reports require. |
| `educustomize_teacher_group` | 此设置指定经管理员审批的教师资格群组。 / This setting identifies the group for teachers approved by administrators. |
| `educustomize_model_ids` | 此设置指定课程可以使用的原生模型 ID。 / This setting identifies the native model IDs that courses may use. |
| `educustomize_tool_names` | 此设置指定课程可以使用的工具名称。 / This setting identifies the tools that courses may use. |
| `educustomize_workflow_ids` | 此设置保存已准备并授权的教学工作流 ID。 / This setting records the prepared and authorized teaching workflow IDs. |
| `allow_user_locale` | 此设置允许登录用户选择自己的界面语言。 / This setting lets signed-in users choose their interface language. |
| `set_locale_from_cookie` | 此设置允许访客通过浏览器 Cookie 保留界面语言。 / This setting lets visitors retain their interface language through a browser cookie. |

管理员可以在“所有站点设置”中搜索公开设置。在本手册对应的 Discourse 版本中，`enable_discourse_workflows` 是隐藏的实验性设置。管理员可以在“即将推出的更改”中查找 Workflows；如果界面没有显示该选项，服务器管理员可以通过 Rails 控制台执行以下命令。源码部署使用 `bin/rails c`；标准 Docker 部署先执行 `./launcher enter app`，再执行 `rails c`。

Administrators can search for public settings under “All site settings”. In the Discourse version covered by this manual, `enable_discourse_workflows` is a hidden experimental setting. Administrators can look for Workflows among upcoming changes. If the interface does not expose it, the server administrator can run the following command in the Rails console. A source deployment uses `bin/rails c`; a standard Docker deployment uses `./launcher enter app`, followed by `rails c`.

```ruby
SiteSetting.enable_discourse_workflows = true
```

管理员需要创建一个自定义教师资格群组，并将其指定为 `educustomize_teacher_group`。该群组的所有者应为管理员，公开直接加入功能应处于关闭状态。随后，管理员可以进入“插件 → 课程配置”，依次点击“准备教学功能”和“准备教学工作流”，并检查页面反馈。

Administrators create a custom teacher eligibility group and select it as `educustomize_teacher_group`. Its owners must be administrators, and direct public admission must be disabled. Administrators then open “Plugins → Course setup”, select “Prepare teaching features” followed by “Prepare teaching workflow”, and inspect the feedback.

“准备教学功能”会启用投票、指派、政策确认、活动、标签、采纳答案和模板功能，并准备常用附件类型、需要审核的教师申请及教师私有模板分类。现有权限列表和附件类型列表会得到扩充，数据保留期继续使用当前值。“准备教学工作流”会创建并授权受控教学流程；重复执行准备操作会复用已经建立的相应资源。

“Prepare teaching features” enables polls, assignments, policy acknowledgements, events, tags, accepted answers and templates. It also prepares common attachment types, reviewed teacher applications and a private template category for teachers. Existing permission and attachment lists are extended, while retention settings keep their current values. “Prepare teaching workflow” creates and authorizes the controlled teaching process. Repeating these preparation actions reuses the corresponding resources already created.

管理员可以通过主题安装页面导入 Flat 3.0.0，将其设为默认主题，并选择其浅色和深色配色。Foundation 也受到支持。插件会提供 Light、Ambient 和 Dark 三种模式；Dark 模式依赖当前主题可用的原生深色配色。管理员还需要按照第 11、12 节完成模型、凭据、工具授权和嵌入服务配置。

Administrators can import Flat 3.0.0 from the theme installation page, set it as the default theme, and select its light and dark palettes. Foundation is also supported. The plugin provides Light, Ambient and Dark modes; Dark mode requires a working native dark palette in the selected theme. Administrators also need to configure models, credentials, tool authorization and embeddings as described in sections 11 and 12.

## 5. 注册、登录与个人资料 / Accounts and profile

用户可以在首页点击“注册 / Sign Up”，填写站点要求的邮箱、用户名和密码，并按邮件完成验证。如果站点要求管理员审批，用户需要等待审批完成。采用 SSO 或 Discourse ID 的站点会提供对应登录入口。安装插件后，用户仍需按本站的注册或登录方式使用自己的账户。

Users can select “Sign Up” on the home page, enter the email, username and password required by the site, and complete email verification. If administrator approval is required, users must wait for that approval. Sites using SSO or Discourse ID provide the corresponding sign-in option. After the plugin is installed, users still access their own accounts through the site’s registration or sign-in process.

用户可以从头像菜单打开个人资料和偏好设置，修改头像、显示名称、自我介绍及站点开放的其他资料字段，并分别保存各分区的修改。用户名、邮箱和密码的变更可能需要再次验证，也可能受到站点规则限制。

Users can open their profile and preferences from the avatar menu, update their avatar, display name, biography and other fields enabled by the site, and save each section. Changes to usernames, email addresses or passwords may require verification or be restricted by site rules.

偏好设置还提供邮件、通知、分类或标签跟踪，以及可用的登录安全选项。忘记密码的用户可以在登录页面申请重置，并按邮件提示完成操作。用户切换账户或测试角色前，应先退出当前账户。

Preferences also provide email settings, notifications, category or tag tracking, and available sign-in security options. Users who forget their password can request a reset from the login page and follow the email instructions. Users should sign out of the current account before switching accounts or test roles.

## 6. 配色与语言 / Colors and language

侧栏顶部提供配色和语言控件。窗口较窄或侧栏收起时，同样的控件会显示在内容顶部。登录用户和访客均可使用站点已启用的界面偏好功能。

Color and language controls appear at the top of the sidebar. When the window is narrow or the sidebar is collapsed, the same controls appear above the content. Signed-in users and visitors can use the interface preferences enabled by the site.

| 选项 / Choice | 配色说明 / Palette behavior |
| --- | --- |
| Dark | 此模式使用当前主题的原生深色配色。 / This mode uses the current theme's native dark palette. |
| Light | 此模式将侧栏等区域设为蓝色 `#005375`，并为浅色内容区域配置深色文字。 / This mode uses blue `#005375` for areas such as the sidebar and dark text on light content backgrounds. |
| Ambient | 此模式将侧栏等区域设为紫色 `#53205c`，并为浅色内容区域配置深色文字。 / This mode uses purple `#53205c` for areas such as the sidebar and dark text on light content backgrounds. |

用户在配色菜单中选择模式后，浏览器会通过 Cookie 保留选择。刷新页面后，该选择仍然有效，不同浏览器可以保留不同配色。三种模式沿用相同的页面布局、内容和权限。用户通过其他原生控件切换深浅色时，插件会同步到相应的 Dark 或 Light 模式。

The browser stores the selected color mode in a cookie, so the choice survives a page reload. Different browsers can retain different palettes. All three modes use the same layout, content and permissions. When users switch between light and dark through another native control, the plugin synchronizes to Light or Dark accordingly.

语言菜单提供简体中文和 English。登录用户的语言选择保存到账户，访客的语言选择保存在浏览器 Cookie 中。切换界面语言会更新界面文案，帖子、用户输入和模型回答保留原有内容。如果页面显示“配色由主题固定 / Theme controls color”，管理员需要检查当前主题的原生深浅色支持。

The language menu offers Simplified Chinese and English. Signed-in users save their language choice to their account, while visitors retain it in a browser cookie. Switching the interface language updates interface text; posts, user input and model responses retain their original content. If the page displays “Theme controls color”, an administrator needs to check the selected theme's native light and dark support.

## 7. 教师资格与课程成员 / Teacher approval and membership

普通用户注册后需要另行申请教师资格。课程目录中的教师申请入口会引导用户提交入组申请，管理员在教师资格群组中审核请求，也可以直接将已获批的教师加入该群组。

Registered users need separate approval for teacher eligibility. The teacher application entry in the course catalog directs users to submit a group membership request. Administrators review those requests in the teacher eligibility group or add teachers who have already been approved.

教师创建课程后，可以打开“课程管理 → 课程与成员”，通过“管理学生 / Manage students”进入原生群组页面。学生可以从课程目录申请或执行站点允许的加入操作。退出课程、移除成员和调整加入策略均遵循原生群组规则。

After creating a course, teachers can open “Course management → Course and members” and use “Manage students” to reach the native group page. Students can request or complete enrollment through the course catalog as permitted by the site. Leaving a course, removing members and changing admission rules follow native group behavior.

管理员负责在课程教师群组中任命或移除教师。课程教师管理本课程所需的权限由课程关系提供，无需为此授予全站管理员身份。

Administrators appoint or remove teachers through the course teacher group. Course assignments provide the permissions needed to manage that course, without requiring site administrator status.

## 8. 课程和学习工作区 / Courses and workspace

教师可以从“课程 → 创建课程”填写名称和简介并创建课程。课程建立后，“课程管理”提供名称、简介、颜色、课程图片和背景图片的编辑入口。每门课程使用一个原生分类，并关联相应的教师群组和学生群组。

Teachers can create a course from “Courses → Create course” by entering its name and introduction. Once the course exists, “Course management” provides fields for its name, introduction, color, course image and background image. Each course uses a native category associated with its teacher and student groups.

“进入课程 / Enter course”会打开学习工作区，其中集中展示全部讨论、讨论任务、公告、材料、问答和反馈。活动创建入口会预选课程分类和教学标签，并提供可修改的正文模板。尚未加入课程的用户会先看到课程简介和加入入口，管理操作则按当前用户的权限显示。

“Enter course” opens the learning workspace, which brings together discussions, discussion assignments, announcements, materials, questions and feedback. Activity creation links preselect the course category and teaching tag and provide an editable body template. Users who have not joined first see the course introduction and enrollment entry. Management actions appear according to the current user's permissions.

课程管理包含“课程与成员、AI 助教、Bloc、JSON 迁移、Topic AI 设置”五个工作区，每次显示其中一个。桌面顶部导航便于切换，窄屏通过“本页导航 / On this page”选择工作区。教师可以在各工作区中分别管理课程信息、配置助教、保存协作关系、迁移配置和进入 Topic 的 AI 设置。

Course management contains five workspaces: “Course and members”, “AI assistants”, “Bloc”, “JSON migration” and “Topic AI settings”. The page displays one workspace at a time. Desktop navigation provides direct switching, while narrow screens use the “On this page” menu. These workspaces let teachers manage course details, configure assistants, save collaboration relationships, migrate configurations and open Topic AI settings.

管理员可以通过原生分类设置调整访问权限和归档安排。当前插件没有独立的一键删除整门课程功能，管理员维护原生资源时应保留课程分类与教师、学生群组之间的关联。

Administrators can adjust access and archival arrangements through native category settings. The plugin currently has no dedicated action for deleting an entire course at once. Administrators should preserve the associations between the course category and its teacher and student groups when maintaining native resources.

## 9. 发帖、回复与管理 / Topics, replies and management

1. 用户进入课程并选择相应活动后，可以点击该活动的 Topic 创建入口。
2. 用户需要填写标题、确认课程分类和标签，并在编辑器中输入正文。编辑器可以按站点配置提供富文本或 Markdown、引用、代码块、链接、列表和附件上传功能。
3. 用户确认预览内容后可以发布 Topic。参与已有讨论时，用户可以点击“回复”；回应某一条帖子时，使用该帖下的回复按钮可以保留回复关系。
4. 用户可以在权限和编辑时限允许的范围内，通过铅笔按钮修改自己的帖子。其他操作位于帖子的“…”菜单或 Topic 管理菜单中。教师可以执行课程权限允许的管理操作，超出权限的事项需要由管理员处理。

1. Users open the course and select the relevant activity, then use its Topic creation entry.
2. Users enter a title, confirm the course category and tags, and compose the body. Depending on site settings, the editor provides rich text or Markdown, quotations, code blocks, links, lists and file uploads.
3. Users can publish the Topic after checking its preview. They can participate in an existing discussion with “Reply”, or use the reply button beneath a particular post to preserve that reply relationship.
4. Users can edit their own posts with the pencil button within the permitted editing window. Other actions appear in the post's “…” menu or the Topic management menu. Teachers can perform the management actions authorized for their course; administrators handle actions beyond those permissions.

用户可以通过书签保存稍后阅读的内容，并通过通知级别控制关注、跟踪或静音状态。搜索功能支持按课程分类、作者和关键词定位内容。用户遇到不当内容时可以使用举报功能。个人消息和聊天入口是否可用，取决于站点启用的原生功能及当前账户权限。

Users can bookmark content for later reading and choose a notification level to watch, track or mute a discussion. Search can locate content by course category, author and keyword. Users can flag inappropriate content. Personal messages and chat are available according to native site settings and account permissions.

## 10. 公告、材料、问答与反馈 / Learning activities

| 活动 / Activity | 操作说明 / Instructions |
| --- | --- |
| 公告 / Announcements | 教师可以创建公告 Topic，并在需要时通过原生 Topic 菜单将其置顶。 / Teachers can create an announcement Topic and pin it through the native Topic menu when needed. |
| 学习材料 / Learning materials | 教师可以在材料 Topic 中上传附件并说明用途，学生随后可以打开帖子查看或下载文件。 / Teachers can upload attachments to a material Topic and explain their purpose. Students can then open the post to view or download the files. |
| 问答 / Questions | 学生可以发布问题，教师和同学可以回复。启用 Solved 后，有相应权限的用户可以标记解决方案。 / Students can post questions, and teachers or classmates can reply. When Solved is enabled, authorized users can mark a solution. |
| 反馈 / Feedback | 教师可以在反馈 Topic 中使用投票编辑器或模板设置选项与结果可见性，学生可以投票并提交文字回复。 / Teachers can use the poll editor or a template in a feedback Topic to set options and result visibility. Students can vote and submit written replies. |
| 外部问卷 / External survey | 教师可以将外部问卷链接放入反馈 Topic。平台不会自动同步外部问卷的答卷。 / Teachers can place an external questionnaire link in a feedback Topic. The platform does not automatically synchronize responses from that questionnaire. |

管理员准备原生教学功能后，用户可以按权限使用以下扩展。具体入口还受相关插件和站点设置控制。

After administrators prepare the native teaching features, users can access the following extensions according to their permissions. The relevant plugins and site settings also control which entry points appear.

- 教师可以在指定模板分类中维护模板 Topic，并通过编辑器的模板插入入口复用其内容。 / Teachers can maintain template Topics in the designated category and reuse their content through the composer's template insertion control.
- 教师可以通过 Calendar 或 Events 的编辑器入口插入日期或创建活动，学生可以从 Topic 或“近期活动 / Upcoming events”查看并参与活动。 / Teachers can use Calendar or Events controls in the composer to insert dates or create events. Students can view and participate in events from the Topic or “Upcoming events”.
- 教师可以通过 Assign 的 Topic 指派入口安排人员跟进任务。AI Delegate 的配置需要在课程的 Bloc 工作区完成。 / Teachers can use Assign controls in a Topic to arrange human follow-up. AI Delegates are configured in the course's Bloc workspace.
- 教师可以通过 Policy 的原生功能要求适用成员确认相应内容，并在帖子中查看确认状态。 / Teachers can use native Policy controls to request acknowledgements from the applicable members and inspect their status in the post.

## 11. 模型与密钥 / Models and credentials

模型连接和凭据由管理员维护。课程教师可以选择获准使用的模型，并配置助教行为。

Administrators maintain model connections and credentials. Course teachers can select authorized models and configure assistant behavior.

1. 管理员可以从课程配置页的“模型凭据 / Model credentials”进入原生 AI 凭据页面，并保存供应商提供的 API 密钥。
2. 管理员需要在原生模型页面填写供应商、模型名称、接口地址、凭据、分词器、上下文长度和输出限制。工具、流式输出和推理选项应按照该模型实际支持的能力设置。
3. 管理员可以填写输入、输出和缓存的计费单价，以供原生用量页面估算费用，并通过模型页面的测试按钮检查连接。
4. 连接测试通过后，管理员需要将目标站点实际创建的模型记录 ID 加入 `educustomize_model_ids`。该 ID 与供应商的模型名称属于不同字段，其他站点的记录 ID 不能直接代入。
5. 如果需要发送助教保存的 `temperature` 和 `top_p`，管理员需要在“课程配置”中启用“发送原生 temperature 和 top_p 参数”，再点击“保存采样设置”。该开关控制全站原生 AI 的采样参数发送行为。

1. Administrators can open the native AI credentials page through “Model credentials” in Course setup and save the API key supplied by their provider.
2. Administrators configure the provider, model name, endpoint, credential, tokenizer, context length and output limit on the native model page. Tool, streaming and reasoning options should match the model's supported capabilities.
3. Administrators can enter input, output and cache prices for native cost estimates and use the model page's test action to check the connection.
4. After a successful connection test, administrators add the model record ID created on the destination site to `educustomize_model_ids`. This database ID is distinct from the provider's model name; an ID from another site cannot be reused as a substitute.
5. To send an assistant's saved `temperature` and `top_p` values, administrators enable “Send native temperature and top_p parameters” in Course setup and select “Save sampling settings”. This option controls native AI sampling parameter submission across the site.

管理员还需要通过 `educustomize_tool_names` 授权课程工具。当前支持的工具名称为 `Time`、`RandomPicker` 和 `SearchUploadedDocuments`。课程助教随后可以从复选列表中选择已授权的工具。当前课程执行范围不包含论坛讨论读取工具、自定义代码工具、MCP 或其他外部工具。

Administrators also authorize course tools through `educustomize_tool_names`. The supported names are `Time`, `RandomPicker` and `SearchUploadedDocuments`. Course assistants can then select authorized tools from the checkbox list. The current course execution scope excludes forum discussion retrieval tools, custom code tools, MCP and other external tools.

管理员应按照供应商当前支持的能力配置上下文、输出限制、工具调用和采样参数，并在目标站点验证连接与实际教学流程。供应商可能忽略不支持的参数，或限制推理模式下的采样行为。

Administrators should configure context limits, output limits, tool calls and sampling parameters according to the provider's supported capabilities and verify both connectivity and teaching workflows on the destination site. Providers may ignore unsupported parameters or restrict sampling in reasoning mode.

原生费用依据管理员填写的价格估算，平台不会自动同步供应商账单或随时段变化的价格。Fake 模型用于自动化和本地流程验证，其预设响应不能用来评价真实模型的回答效果。

Native cost estimates use the prices entered by an administrator. The platform does not automatically synchronize provider bills or prices that vary by time. The Fake model supports automated and local workflow verification; its prepared responses cannot establish the quality of a real model's answers.

## 12. 本地向量服务 / Local embeddings

对话模型负责生成回答，嵌入向量模型负责生成检索所需的文件向量。Discourse AI 继续管理知识材料的上传、分片、索引和检索。目标站点可以连接远程嵌入服务，也可以单独部署兼容的本地服务。

The conversation model generates answers, while the embedding model produces document vectors for retrieval. Discourse AI manages knowledge uploads, chunking, indexing and retrieval. A destination site can connect to a remote embedding service or deploy a compatible local service separately.

管理员需要先部署嵌入服务，或选择原生 AI 支持的远程服务。自行部署时，应按照服务提供方的安装说明准备所需硬件、模型权重、存储、服务地址和凭据。插件发布包包含接入教学功能所需的代码，嵌入服务及其模型权重需要另行配置。

Administrators first deploy an embedding service or choose a remote service supported by native AI. For a self-hosted service, they should follow the provider's installation instructions for hardware, model weights, storage, endpoints and credentials. The plugin release contains the teaching integration code; the embedding service and its model weights require separate configuration.

管理员可以从课程配置页的“知识嵌入向量 / Knowledge embeddings”进入原生配置页面，并按照实际模型填写服务地址、凭据、维度和分词器。例如，使用兼容的 BGE-M3 服务时，可以选择 `bge-m3` 预设，并使用 1024 维及原生 `BgeM3Tokenizer`。管理员随后需要选择 `ai_embeddings_selected_model`、启用 `ai_embeddings_enabled`，并运行原生连接测试。

Administrators can open the native configuration page through “Knowledge embeddings” in Course setup and enter the endpoint, credential, dimensions and tokenizer required by their model. For example, a compatible BGE-M3 service can use the `bge-m3` preset with 1,024 dimensions and native `BgeM3Tokenizer`. Administrators then select `ai_embeddings_selected_model`, enable `ai_embeddings_enabled`, and run the native connection test.

服务地址必须能够从目标站点的 Discourse 服务访问。使用受信任的内网服务时，管理员还需要按部署要求将对应主机加入 `allowed_internal_hosts`。连接测试通过后，教师仍需在“运行与维护”确认上传材料已经完成索引，再启用知识检索工具。

The endpoint must be reachable from the destination site's Discourse service. When using a trusted internal service, administrators also need to add its host to `allowed_internal_hosts` as required by the deployment. After the connection test passes, teachers still need to confirm in Runtime and maintenance that uploaded materials have finished indexing before enabling the retrieval tool.

## 13. 教师 AI 配置 / Teacher AI configuration

教师可以从“课程管理 → AI 助教”创建或编辑助教。编辑器显示当前助教名称，并提供返回助教列表的入口。表单按助教信息、Prompt 与 Skills、模型与工具、知识材料分组；“高级模型参数”区域可以展开查看采样参数。

Teachers can create or edit an assistant in “Course management → AI assistants”. The editor identifies the current assistant and provides a link back to the assistant list. The form groups assistant details, Prompt and Skills, model and tools, and knowledge materials. Teachers can expand “Advanced model parameters” to access sampling controls.

教师需要填写助教名称、简介和主要 Prompt，并选择管理员授权的模型。助教启用后，还需要满足 Topic 工作流、权限和材料就绪条件才能生成回复。教师可以点击“保存助教 / Save assistant”保存配置；停用助教会保留已保存的配置。

Teachers enter the assistant's name, introduction and main Prompt and choose an administrator-authorized model. An enabled assistant must also satisfy the Topic's workflow, authorization and knowledge readiness requirements before it can generate a reply. “Save assistant” saves its configuration. Disabling an assistant preserves its saved configuration.

Prompt 应说明助教的角色、任务、回答语言、输出格式、证据要求和追问规则。字段旁的说明按钮支持悬停、键盘聚焦和点击。下面的示例说明了这些要求如何组合成一段完整指令。

The Prompt should define the assistant's role, task, response language, output format, evidence requirements and follow-up rules. The adjacent help button supports hovering, keyboard focus and clicking. The following example combines those requirements into a complete set of instructions.

> 你是本课程的教学助理。你需要使用学生提问时的语言回答，先给出简短提示，再提出一个帮助学生解释依据的问题。如果回答涉及课程材料，你需要先检索已上传的文件，并引用实际检索到的文件名。如果检索结果无法提供证据，你需要明确说明这一点。
>
> You are the teaching assistant for this course. You should respond in the language used by the student, offer a short hint, and ask one question that helps the student explain their reasoning. If the answer concerns course materials, you must search the uploaded files first and cite the filenames actually returned by retrieval. If the retrieved material does not provide evidence, you must state that clearly.

教师可以在独立的 Skills 区域添加、编辑或删除技能。每项技能需要名称和指令正文，说明字段可以留空。技能归属于当前助教，平台按列表顺序将其组合到原始 Prompt 之后，再交给原生 Agent 执行。重新打开表单时，原始 Prompt 和 Skills 仍分别显示，重复保存不会重复追加技能。由旧版迁移的助教会保留原提示词，Skills 列表初始为空。

Teachers can add, edit or remove entries in the separate Skills section. Each skill requires a name and instructions, while its description may be blank. Skills belong to the current assistant. The platform combines them with the original Prompt in list order and passes the result to the native Agent. Reopening the form displays the original Prompt and Skills separately, and repeated saves do not append duplicate skills. Assistants migrated from an earlier version retain their original instructions and begin with an empty Skills list.

Tools 区域以复选列表展示工具名称和用途，教师可以同时选择多个工具。`Time` 提供当前时间，`RandomPicker` 从模型提供的选项中随机选择，`SearchUploadedDocuments` 检索当前助教已经完成索引的知识材料。没有可用工具时，页面会显示说明；缺少模型或工具授权时，教师需要联系管理员。

The Tools section presents tool names and purposes in a checkbox list, and teachers can select multiple tools. `Time` provides the current time, `RandomPicker` chooses randomly from options supplied by the model, and `SearchUploadedDocuments` searches the current assistant's indexed knowledge materials. The page explains when no tools are available. Teachers need an administrator to provide missing model or tool authorization.

`temperature` 接受 0 到 2 的值，`top_p` 接受大于 0 且不超过 1 的值。字段留空时，平台沿用原生默认行为。管理员关闭采样参数开关时，教师仍可保存这些值，但平台会在模型请求中省略它们。参数是否生效还取决于供应商的支持情况。

`temperature` accepts values from 0 to 2, and `top_p` accepts values greater than 0 and no greater than 1. Blank fields retain native default behavior. When the administrator's sampling option is disabled, teachers can still save these values, but the platform omits them from model requests. Their effect also depends on provider support.

## 14. 知识材料 / Knowledge materials

1. 教师需要打开目标助教的编辑器，在“知识材料”区域上传 TXT、Markdown 或 PDF 文件。
2. 教师确认文件出现在列表后，需要保存助教。替换材料时，教师可以解除旧文件关联、上传新版本，再保存修改。
3. 教师可以在“运行与维护”中查看材料的总片段数、已索引片段数和剩余片段数。索引尚未完成时，教师应等待后台处理并刷新状态；异常情况需要由管理员检查原生后台任务和嵌入服务。
4. 教师需要为承担检索的助教选择 `SearchUploadedDocuments`，并在 Prompt 或 Skills 中说明检索与引用要求。
5. 教师可以在已配置的 Topic 中生成一条关于材料的回复，并核对实际检索结果、引用文件和回答内容。模型自行声称读过文件，无法单独证明检索成功。

1. Teachers open the target assistant's editor and upload TXT, Markdown or PDF files under “Knowledge materials”.
2. Teachers save the assistant after confirming that the files appear in the list. To replace material, they can remove the old association, upload the revision and save the changes.
3. Teachers can inspect total, indexed and remaining chunks in “Runtime and maintenance”. They should wait for background processing and refresh the status while indexing is incomplete. An administrator needs to investigate native jobs and the embedding service if processing fails.
4. Teachers select `SearchUploadedDocuments` for the assistant responsible for retrieval and describe retrieval and citation requirements in its Prompt or Skills.
5. Teachers can generate a material-related reply in a configured Topic and inspect the retrieved content, cited files and answer. A model's claim that it read a file is insufficient evidence of successful retrieval.

知识材料关联到具体助教。Bloc 中负责检索的 Delegate 需要自己的材料和工具配置。供学生阅读的文件应上传到课程材料 Topic，供 AI 检索的文件应上传到助教。如果同一文件同时承担两种用途，教师需要分别通过这两个入口上传。

Knowledge materials belong to a specific assistant. A Delegate responsible for retrieval needs its own materials and tool configuration. Files for students to read belong in course material Topics, while files for AI retrieval belong in an assistant's knowledge area. If one file serves both purposes, teachers need to upload it through both entry points.

扫描 PDF 能否提取文本取决于原生解析能力，当前手册不将 OCR 视为已提供的功能。移除文件关联不会撤回已经发布的回答。知识材料关联权限与附件直链的存储保护需要分别检查，部署管理员应确认实际使用的附件存储策略。

Text extraction from scanned PDFs depends on native parsing support; this manual does not treat OCR as an available feature. Removing a file association does not retract previously published answers. Knowledge association permissions and storage protection for direct attachment links require separate checks. Deployment administrators should verify the attachment storage policy in use.

## 15. Bloc 与 Delegate / Blocs and Delegates

一个 Bloc 由负责协调的 Dais 和若干 Delegate 组成。教师可以先创建职责不同的 Delegate，例如分别负责材料解读和论证检查，再为每个 Delegate 配置模型、Prompt、Skills、工具和材料。Dais 同样使用助教编辑器创建和配置。

A Bloc consists of a coordinating Dais and its Delegates. Teachers can first create Delegates with distinct responsibilities, such as interpreting materials and checking arguments, then configure each Delegate's model, Prompt, Skills, tools and materials. The Dais is created and configured through the same assistant editor.

教师在课程管理的 Bloc 工作区选择一个 Dais 后，页面会立即显示可选 Delegate 的复选列表和已选数量。教师可以同时选择多个 Delegate，并点击“保存 Bloc / Save Bloc”保存关系。“编辑 Dais 提示词 / Edit Dais prompt”和“编辑 Delegate / Edit Delegate”会打开相应助教的编辑器，教师完成编辑后可以返回 Bloc。

Selecting a Dais in the course's Bloc workspace immediately displays the eligible Delegate checkbox list and the selected count. Teachers can choose multiple Delegates and save the relationship with “Save Bloc”. “Edit Dais prompt” and “Edit Delegate” open the corresponding assistant editor, from which teachers can return to the Bloc.

Dais 与 Delegate 必须属于同一课程，一个 Dais 最多可以关联 20 个 Delegate。平台会拒绝自引用和嵌套的 Delegate 关系。教师在 Topic 的 AI 设置中选择该 Dais 后，Topic 就会使用对应的 Bloc。

The Dais and its Delegates must belong to the same course, and a Dais can have at most 20 Delegates. The platform rejects self-references and nested Delegate relationships. Selecting the Dais in a Topic's AI settings makes that Topic use the associated Bloc.

执行时，Dais 根据指令分配任务，Delegate 生成各自的内容，Dais 再汇总结果。Topic 的审核设置决定汇总后的回复是否需要等待教师批准。各助教的具体职责由其 Prompt 和 Skills 指导，Topic 的工作流、讨论记忆、自动回复与审核教师则在 Topic AI 设置中配置。

During execution, the Dais assigns tasks according to its instructions, the Delegates produce their contributions, and the Dais combines the results. The Topic's approval setting determines whether the resulting reply waits for teacher review. Each assistant's Prompt and Skills guide its responsibilities. The workflow, discussion memory, automatic replies and reviewing teacher are configured in the Topic's AI settings.

关联多个 Delegate 并不保证模型每次都会调用所有 Delegate。教师需要明确分工，并通过用量日志检查实际调用。Dais 和所有关联 Delegate 都需要启用，并使用有效的授权模型。主助教和子助教的调用都会增加模型用量。

Associating multiple Delegates does not guarantee that the model calls all of them on every run. Teachers need to define clear responsibilities and inspect usage logs for actual calls. The Dais and all associated Delegates must be enabled and use authorized models. Calls to the main assistant and its Delegates contribute to model usage.

## 16. Topic 策略与记忆 / Topic policy and memory

教师发布课程讨论 Topic 后，可以打开该 Topic 的“AI 设置”，也可以从课程管理的“Topic AI 设置”工作区进入对应讨论的配置页面。

After publishing a course discussion Topic, teachers can open its “AI settings”. They can also reach the corresponding configuration page through the “Topic AI settings” workspace in course management.

1. 教师需要选择当前 Topic 使用的助教或 Dais，并选择已经准备好的教学工作流。
2. 教师需要指定本课程的审核教师，再按教学需求设置自动回复、讨论记忆和教师审核选项。
3. 教师需要点击“保存 Topic 设置 / Save Topic settings”，再根据页面显示的就绪状态处理缺失配置。
4. 配置就绪后，教师可以选择一条学生帖子并生成回复；开启自动回复的 Topic 也可以响应之后的新学生帖子。

1. Teachers select the assistant or Dais for the Topic and choose a prepared teaching workflow.
2. Teachers assign a reviewing teacher from the course and configure automatic replies, discussion memory and teacher approval as needed.
3. Teachers select “Save Topic settings” and address any missing configuration identified by the readiness information.
4. Once the configuration is ready, teachers can select a student post and generate a reply. Topics with automatic replies enabled can also respond to subsequent student posts.

默认设置关闭自动回复和讨论记忆，并要求教师审核。关闭记忆时，生成请求使用选中的学生帖子；开启记忆时，请求还会包含当前 Topic 中允许访问的讨论内容，并将当前问题放在最后。讨论记忆的范围限于当前 Topic，不提供跨课程或跨 Topic 的长期记忆。

Automatic replies and discussion memory are disabled by default, and teacher approval is required. With memory disabled, generation uses the selected student post. With memory enabled, the request also includes accessible discussion from the current Topic and places the current question last. Discussion memory is confined to the current Topic and does not provide persistent memory across courses or Topics.

教师为 Topic 配置 AI 并开启自动回复后，该 Topic 中新提交的学生帖子会触发生成。学生自行创建且尚未配置 AI 的 Topic 默认不会触发自动回答。教师帖子、AI 发布的回复和重复事件会受到过滤，避免形成自动回复循环。

Once a teacher configures AI and enables automatic replies for a Topic, new student posts in that Topic trigger generation. A student-created Topic without AI configuration does not trigger an automatic answer. Teacher posts, AI publications and duplicate events are filtered to prevent automatic reply loops.

自动回复开关会作用于后续事件，不会批量补答历史帖子。教师需要为已有帖子补答时，可以使用手动生成。课程配置、教师权限或 Topic 分类发生变化后，教师应重新检查策略和待审核记录。

The automatic reply option applies to subsequent events and does not backfill historical posts in bulk. Teachers can generate replies manually for existing posts. After changes to course configuration, teacher permissions or a Topic's category, teachers should recheck its policy and pending review records.

## 17. 生成与审核 / Generation and review

教师可以在 Topic 的 AI 设置中选择学生帖子，然后点击“生成回复 / Generate reply”。请求进入队列后，教师可以刷新记录查看进展。自动触发的运行也会出现在同一列表中，原生工作流还可能通过弹窗通知指定教师。

Teachers can select a student post in the Topic's AI settings and choose “Generate reply”. After the request enters the queue, teachers can refresh the records to inspect progress. Automatically triggered runs appear in the same list, and native workflows may also notify the assigned teacher through a dialog.

指定审核教师可以在草稿编辑区修改回复，并通过“预览回复 / Preview reply”检查 Markdown 渲染结果。“编辑回复 / Edit reply”会返回编辑状态，切换预览不会清空修改。确认内容后，审核教师可以选择批准或拒绝。

The assigned reviewing teacher can edit the draft and use “Preview reply” to inspect its rendered Markdown. “Edit reply” returns to editing, and switching to the preview preserves changes. After checking the content, the reviewer can approve or reject the reply.

| 操作 / Action | 执行结果 / Result |
| --- | --- |
| 批准并发布 / Approve and publish | 平台会将当前审核稿发布到原 Topic。原生工作流显示确认提示时，审核教师需要按提示完成操作。 / The platform publishes the current reviewed draft to the original Topic. The reviewer completes any confirmation required by the native workflow. |
| 编辑后批准 / Edit then approve | 教师可以先修改草稿再批准，原始草稿、教师编辑稿和最终发布正文会分别保留在相应记录中。 / The teacher can edit the draft before approval. The original draft, teacher-edited draft and published text are retained in their corresponding records. |
| 拒绝 / Reject | 平台会记录拒绝决定，并保留该次运行记录，草稿不会发布。 / The platform records the rejection and retains the run record without publishing the draft. |
| 重新生成 / Regenerate | 平台会将旧运行标记为已被替代，并发起新的生成请求。新的请求会产生相应模型用量。 / The platform marks the previous run as superseded and requests another answer. The new request contributes to model usage. |
| 关闭教师审核 / Disable teacher approval | 教师保存关闭审核的 Topic 设置后，后续成功生成的回复会直接发布。 / After the teacher saves Topic settings with approval disabled, subsequent successful replies are published directly. |

学生无法查看尚未批准的草稿。已发布回复的后续修改遵循原生帖子编辑权限。“在 Topic 中查看已发布回复 / View published reply in Topic”会打开已发布的具体回复。

Students cannot access unapproved drafts. Subsequent changes to a published reply follow native post editing permissions. “View published reply in Topic” opens the specific published reply.

配置变化、教师撤权或 Topic 移动可能使旧待审记录失效。教师需要先恢复有效配置，再发起新的生成请求。生成失败时，平台不会发布不完整的回答。对审核稿的未保存修改会受到页面内保护，具体行为见第 24 节。

Configuration changes, revoked teacher permissions or a moved Topic may invalidate an earlier pending review. Teachers need to restore valid configuration before requesting another generation. Failed generation does not publish a partial answer. The page protects unsaved review edits as described in section 24.

## 18. 运行状态、用量与费用 / Operations, usage and cost

教师可以从课程导航打开“运行与维护”，按 Topic、执行状态和审核结果筛选记录，并使用翻页与刷新操作。打开运行记录后，页面会定位到对应 Topic 的审核位置。某条记录可以同时显示工作流执行成功和审核已拒绝，因为这两个状态分别描述执行过程与审核决定。

Teachers can open “Runtime and maintenance” from course navigation, filter records by Topic, execution status and review outcome, and use pagination or refresh controls. Opening a run record leads to its review location in the corresponding Topic. A record can show both successful workflow execution and a rejected review because those states describe the execution process and the review decision separately.

该页面还显示依赖状态、模型授权、工作流有效性和知识材料索引摘要。“未知”表示现有原生数据不足以判断状态。“记录不可用”可能由保留期清理造成，因此该提示无法证明调用从未发生。

The page also shows dependency status, model authorization, workflow validity and knowledge indexing summaries. “Unknown” means that the available native data is insufficient to determine the state. “Record unavailable” may result from retention cleanup, so it does not establish that a call never occurred.

教师可以在“数据导出”的 AI 使用情况报表中查看课程调用明细和按模型汇总的数据。管理员可以从“课程配置”进入原生 AI 用量与日志页面，查看全站情况。用户核对调用时，可以比较运行记录、Agent、父 Agent、token 数、耗时、调用结果和估算费用。

Teachers can inspect course call details and model summaries in the AI usage reports under “Data export”. Administrators can open native AI usage and log pages from Course setup to inspect site-wide activity. Users can compare run records, Agent and parent Agent identifiers, token counts, duration, call results and estimated costs.

缺少日志、无法归属的调用、缺失费用和零用量分别代表不同情况。课程报表统计仍被保留且能够归属到课程的模型审计记录，不能代表供应商账户的全部消费。原生费用以美元估算，实际扣费需要以供应商账单为准。当前插件没有自动按课程预算上限停止模型调用的功能。

Missing logs, unattributed calls, missing cost data and zero usage represent different conditions. Course reports include retained model audit records that can be attributed to the course; they do not represent all spending on the provider account. Native costs are estimated in US dollars, while the provider's bill determines actual charges. The plugin currently has no feature that automatically stops model calls at a course budget limit.

## 19. 数据预览与导出 / Preview and export

教师可以从课程统一导航打开“数据导出”，管理员也可以在“课程配置”中选择课程并进入报表。教师能够导出的范围限于自己负责的课程，以及该课程中自己有权访问的数据。

Teachers can open “Data export” from the shared course navigation, and administrators can select a course in Course setup to reach its reports. Teachers can export only data they are authorized to access in courses they currently manage.

1. 用户需要选择相应的报表视图。页面会按用途将视图归入不同类别。
2. 用户可以设置起止日期、时区和可选的 Topic。默认日期范围为包括今天在内的最近 30 天。
3. 用户点击“预览 / Preview”后，可以检查字段和最多前 50 行数据。
4. 用户确认筛选条件后，可以选择 CSV 或 JSON 并点击“下载 / Download”。下载会获取符合筛选条件的完整结果，但仍受到原生行数上限限制。

1. Users select the required report view. The page groups views by their purpose.
2. Users can set the start and end dates, timezone and optional Topic. The default range covers the last 30 days, including today.
3. After selecting “Preview”, users can inspect the fields and up to the first 50 rows.
4. Users can choose CSV or JSON and select “Download” after checking the filters. The download contains the complete matching result, subject to the native row limit.

| 类别 / Category | 视图用途 / Purpose of the views |
| --- | --- |
| 讨论与参与 / Discussion and participation | 此类报表提供帖子明细和参与汇总，用户可以查看作者、正文、回复关系、发帖数量及参与的 Topic 数量。 / These reports provide post details and participation summaries, including authors, text, reply relationships, post counts and the number of Topics in which users participated. |
| AI 回复与审核 / AI replies and review | 此类报表展示每次运行的原始草稿、编辑稿、审核结果、替代状态和发布正文。 / These reports show each run's original draft, edited draft, review outcome, supersession state and published text. |
| AI 使用情况 / AI usage | 此类报表提供调用明细和按模型汇总的数据，用户可以检查主助教与子助教、token 数、耗时和估算费用。 / These reports provide call details and model summaries for checking main assistants, Delegates, token counts, duration and estimated costs. |
| 投票与反馈 / Polls and feedback | 此类报表提供投票汇总、原生规则允许的投票人明细和文字反馈。用户也可以在帖子报表中选择反馈 Topic，查看相应讨论。 / These reports provide poll summaries, voter details permitted by native rules and written feedback. Users can also select a feedback Topic in the post report to inspect its discussion. |

日期筛选按所选时区解释，并包含起止日期；导出的时间戳统一使用 UTC。原生用户 ID、用户名和完整文本会保留在相应字段中。帖子和草稿以 Markdown 导出，投票选项保留原生 HTML。参与统计描述平台活动，单凭这些统计无法判断学习成效。

Date filters use the selected timezone and include the start and end dates. Exported timestamps use UTC. The corresponding fields retain native user IDs, usernames and full text. Posts and drafts are exported as Markdown, while poll options retain native HTML. Participation statistics describe platform activity and cannot establish learning outcomes on their own.

JSON 报表采用 `columns` 和 `rows` 结构，并保留 `null`、空字符串和 `0` 之间的区别。CSV 阅读软件可能将部分空值显示为相同内容。结果达到原生 10000 行上限时，平台会拒绝整次下载，用户需要缩小日期范围或选择具体 Topic 后重试。预览显示 50 行时，实际结果可能超过 50 行。完整字段说明见[报表字段文档](report-fields.md)。

JSON reports use a `columns` and `rows` structure that preserves the distinctions among `null`, empty strings and `0`. CSV readers may display some empty representations identically. When a result reaches the native 10,000-row limit, the platform rejects the download. Users need to narrow the dates or select a specific Topic before trying again. A preview containing 50 rows may represent a larger result. The [report field documentation](report-fields.md) explains the fields in detail.

停用 Data Explorer 会使报表预览与下载不可用，课程的其他教学功能仍可按各自依赖继续运行。投票人的身份信息遵循原生可见性规则，教师身份本身不保证能够查看或导出所有投票人的身份。

Disabling Data Explorer makes report preview and download unavailable. Other teaching functions can continue according to their own dependencies. Voter identities follow native visibility rules; teacher status alone does not grant access to every voter's identity.

## 20. 保留期、备份与维护 / Retention, backups and maintenance

管理员可以在课程配置中设置工作流保留天数，并点击“保存保留设置 / Save retention settings”。AI 审计日志的保留期通过原生 AI 日志配置调整。如果某项保留期设为 0，平台就不会按记录的存储时长自动清理该类记录。教师可以查看页面显示的当前保留期。

Administrators can set workflow retention days in Course setup and select “Save retention settings”. AI audit log retention is configured through the native AI log settings. If a retention period is set to 0, the platform does not automatically delete that type of record based on its age. Teachers can inspect the current retention periods displayed on the page.

草稿、审核记录、执行数据或日志一旦被清理，就无法继续从平台导出。延长保留期不会恢复已清理的数据。管理员应根据教学和数据使用需求安排保留期与备份。

Once drafts, review records, execution data or logs have been deleted, users can no longer export them from the platform. Extending retention does not restore deleted data. Administrators should set retention and backup policies according to teaching and data requirements.

部署备份应覆盖数据库、上传文件、站点配置及独立向量服务所需的数据。源码 ZIP 用于交付程序文件，无法替代这些数据备份。管理员可以从课程配置进入原生用户、插件、主题、备份、操作日志、错误日志和后台任务页面。

Deployment backups should cover the database, uploads, site configuration and data required by the independent embedding service. The source ZIP delivers program files and cannot replace those backups. Course setup links to native administration pages for users, plugins, themes, backups, action logs, errors and background jobs.

管理员更换模型密钥时，应在原生 AI 凭据管理中保存新值，并重新测试模型连接。助教 Prompt 和 Skills 中应避免填写 API 密钥。正式开放站点前，管理员应检查重启后的生成与检索、上传文件持久化、邮件、角色权限和下载。测试结束后，教师应关闭测试 Topic 的自动回复，避免后续互动继续触发模型调用。

When replacing a model key, administrators should save the new value in native AI credential management and test the model connection again. Assistant Prompts and Skills should not contain API keys. Before opening the site for production use, administrators should check generation and retrieval after restart, upload persistence, email, role permissions and downloads. Teachers should disable automatic replies on test Topics when testing ends to prevent later interactions from triggering additional calls.

## 21. 故障处理 / Troubleshooting

| 现象 / Symptom | 处理方法 / Action |
| --- | --- |
| 没有课程管理入口 / Missing management entry | 用户需要确认自己已经登录，并拥有该课程的教师权限。管理员可以检查教师资格和课程教师群组。 / Users need to confirm that they are signed in and assigned to teach the course. An administrator can check teacher eligibility and the course teacher group. |
| 助教保存后无法生成 / Generation unavailable after saving | 教师需要查看 Topic 页面显示的具体原因，并检查助教启用状态、模型授权、工作流和材料索引。审核人也必须是本课程允许的教师。 / Teachers need to inspect the reasons shown on the Topic page and check assistant status, model authorization, workflow and indexing. The reviewer must also be an authorized teacher of the course. |
| 学生回复后没有 AI 回答 / Missing automatic answer | 教师需要确认该 Topic 已保存自动回复设置、帖子由学生提交，以及依赖和后台队列正常。尚未配置 AI 的新 Topic 默认不会自动回答。 / Teachers need to confirm that automatic replies are saved for the Topic, that a student submitted the post, and that dependencies and background jobs are working. New Topics without AI configuration do not reply automatically. |
| 请求持续排队 / Request remains queued | 教师可以刷新运行记录，管理员则需要检查后台任务和模型服务连接。 / Teachers can refresh the run records, while administrators check background jobs and the model service connection. |
| 401、429 或超时 / 401, 429 or timeout | 管理员需要检查凭据、额度、供应商限流和网络。问题解决后，教师可以从界面重新生成。 / Administrators need to check credentials, quota, provider rate limits and connectivity. Teachers can regenerate from the interface once the problem is resolved. |
| 知识回答不准确 / Inaccurate knowledge answer | 教师需要检查文件是否关联到实际执行检索的助教、索引是否完成、工具是否启用，以及调用是否返回了相关片段。 / Teachers need to check that files belong to the assistant performing retrieval, that indexing is complete, that the tool is enabled, and that the call returned relevant excerpts. |
| 采样参数似乎无效 / Sampling appears ineffective | 管理员需要检查全站采样开关和供应商对相关参数的支持情况。 / Administrators need to check the site-wide sampling option and the provider's support for those parameters. |
| 缺少审核按钮 / Missing review controls | 用户需要确认自己是该 Topic 指定的审核教师，并确认课程权限和配置仍然有效。 / Users need to confirm that they are the Topic's assigned reviewer and that course permissions and configuration remain valid. |
| JSON 无法预览或创建 / JSON preview or creation fails | 教师需要按照错误中的字段路径修正文件，并检查格式版本、模型映射、工具授权和 Delegate 关系，然后重新校验。 / Teachers need to correct the fields identified in the error and check the format version, model mappings, tool authorization and Delegate relationships before validating again. |
| 记录不可用 / Record unavailable | 用户可以查看页面显示的保留期，管理员可以检查相关原生记录。已经清理的执行数据不会自动恢复。 / Users can inspect the displayed retention periods, and administrators can check the corresponding native records. Deleted execution data is not recreated automatically. |
| 无法下载报表 / Report download unavailable | 用户需要检查 Data Explorer 是否启用、当前权限、筛选范围、行数上限和浏览器下载状态。 / Users need to check whether Data Explorer is enabled, their current permissions, filters, row limits and the browser's download status. |
| 配色或语言无法切换 / Color or language switching unavailable | 管理员需要检查主题的深浅色支持，以及 `allow_user_locale` 和 `set_locale_from_cookie` 设置。 / Administrators need to check the theme's light and dark support and the `allow_user_locale` and `set_locale_from_cookie` settings. |

## 22. 角色操作示例与边界 / Walkthroughs and boundaries

管理员首先安装兼容版本的 Discourse、Flat 和插件，再建立教师资格群组、启用依赖并准备教学功能与工作流。管理员随后配置模型凭据、知识嵌入服务和授权列表，并批准教师申请。正式使用后，管理员需要定期检查用量、运行状态、保留期和备份。

An administrator first installs compatible versions of Discourse, Flat and the plugin, establishes the teacher eligibility group, enables dependencies, and prepares teaching features and the workflow. The administrator then configures model credentials, embeddings and authorization lists and approves teacher applications. During regular operation, the administrator checks usage, runtime status, retention and backups.

教师首先创建课程并管理学生成员，再配置助教、Skills、工具、知识材料和所需的 Bloc。教师发布讨论 Topic 后，需要保存该 Topic 的 AI 设置。教师可以手动生成回复，也可以在启用自动回复后处理学生新帖子触发的记录。指定审核教师完成审核后，教师可以通过报表查看讨论参与和 AI 使用情况。

A teacher first creates a course and manages student membership, then configures assistants, Skills, tools, knowledge materials and any required Bloc. After publishing a discussion Topic, the teacher saves its AI settings. The teacher can request a reply manually or enable automatic replies for subsequent student posts. After the assigned reviewer completes the review, teachers can use reports to inspect discussion participation and AI usage.

学生首先注册并登录，按需要完善个人资料和界面偏好，再加入课程。学生阅读任务与材料后，可以在教师配置的 Topic 中提交回复，查看已经发布的反馈，并参与投票或文字反馈活动。

A student first registers and signs in, updates their profile and interface preferences as needed, and joins a course. After reading the tasks and materials, the student can reply in a teacher-configured Topic, read published feedback, and participate in polls or written feedback activities.

部署方应在目标站点确认模型连接、材料索引、双 Delegate 分工、教师审核、JSON 迁移和数据导出能够按实际配置运行。生产负载、其他 Discourse 版本、附件直链保护和设备可用性需要结合部署环境检查，相关架构和运行约束见[技术参考](technical-reference.md)。

Deployments should confirm that model connections, document indexing, two-Delegate collaboration, teacher review, JSON migration and report exports work with the site's actual configuration. Production load, other Discourse versions, direct attachment protection and device usability require checks in the deployment environment. The [technical reference](technical-reference.md) explains the architecture and operational constraints.

平台目前不提供外部问卷自动同步、独立研究归档、服务器运维平台或自动学习成效判定。

The platform currently provides no automatic external survey synchronization, separate research archive, server operations platform or automatic learning-outcome assessment.

## 23. JSON 配置迁移 / JSON configuration migration

JSON 配置迁移支持单个助教和由 Dais 与 Delegate 组成的完整 Bloc。导出文件使用 UTF-8 编码，顶层包含格式标识 `discourse-educustomize/agent-config`、`schema_version: 1`、根助教引用和助教列表。文件内部通过 `key` 连接助教关系，导入时不要求目标站点具有相同数据库 ID。

JSON configuration migration supports a single assistant or a complete Bloc consisting of a Dais and its Delegates. The UTF-8 file contains the format identifier `discourse-educustomize/agent-config`, `schema_version: 1`, a root assistant reference and an assistant list. Internal `key` references connect the assistants, so the destination site does not need matching database IDs.

每个助教的配置包含名称、简介、原始 `system_prompt`、全部 Skills、模型描述、启用状态、`temperature`、`top_p`、工具和 Delegate 引用。模型描述包含供应商、模型名称和显示名称。知识库文件、上传关联、API 密钥、平台凭据、Topic 工作流、审核教师和讨论记录均不包含在文件中。

Each assistant configuration includes its name, introduction, original `system_prompt`, complete Skills list, model description, enabled state, `temperature`, `top_p`, tools and Delegate references. The model description contains the provider, model name and display name. The file excludes knowledge files, upload associations, API keys, platform credentials, Topic workflows, reviewing teachers and discussion records.

1. 教师需要打开已保存助教的编辑器并点击“导出 JSON / Export JSON”。导出使用已保存的配置，并包含该助教关联的所有 Delegate。存在未保存的助教、材料关联或 Bloc 修改时，教师需要先按提示保存。
2. 教师可以在平台外编辑 JSON 文件，但必须保留有效的格式版本和内部引用。完整约定见[配置契约](agent-configuration-format.md)、[JSON Schema](../config/agent-configuration.schema.json) 和[完整 Bloc 示例](examples/bloc.json)。
3. 教师在目标课程中打开“JSON 迁移 → 导入 JSON”，选择文件并点击“校验并预览 / Validate and preview”。页面会显示错误 JSON、不支持的版本、未知字段、类型错误、无效关系或不可用工具等问题。
4. 教师可以通过预览中的助教列表切换编辑对象，并检查名称、简介、Prompt、Skills、启用状态、采样参数、工具和 Delegate。切换对象会保留各自的修改。名称冲突时，平台会预填“副本 2”等唯一名称，教师仍可修改。Prompt 正文保留原文，教师需要检查其中引用的助教名称。
5. 平台根据供应商和模型名称匹配目标站点已授权的模型。存在唯一匹配时，平台会自动选择；文件指定的模型缺失或存在多个匹配时，教师需要选择目标模型。原配置没有指定模型时，可以保留空值，但实际生成前仍需完成模型配置。
6. 教师解决预览中的错误后，可以点击“创建副本 / Create copies”。服务器会重新校验，并在同一个事务中创建全部助教与关系；创建失败时不会留下部分助教。成功后，页面会打开新配置，教师需要重新上传知识材料，并根据需要为目标 Topic 选择新助教。

1. Teachers open a saved assistant's editor and select “Export JSON”. The export uses saved configuration and includes all associated Delegates. Teachers need to save pending assistant, material association or Bloc changes when prompted.
2. Teachers can edit the JSON file outside the platform while preserving a valid format version and internal references. The [configuration contract](agent-configuration-format.md), [JSON Schema](../config/agent-configuration.schema.json) and [complete Bloc example](examples/bloc.json) define the format.
3. Teachers open “JSON migration → Import JSON” in the destination course, choose a file, and select “Validate and preview”. The page reports invalid JSON, unsupported versions, unknown fields, incorrect types, invalid relationships and unavailable tools.
4. Teachers can switch assistants through the preview list and inspect names, introductions, Prompts, Skills, enabled states, sampling parameters, tools and Delegates. Switching assistants preserves their individual edits. Name conflicts receive unique suggestions such as “copy 2”, which teachers can change. The Prompt text remains unchanged, so teachers need to check assistant names referenced within it.
5. The platform matches the provider and model name against authorized destination models. It selects a unique match automatically. If the file specifies a model with no match or multiple matches, the teacher needs to select a destination model. A configuration without a source model can retain that empty value, but generation still requires model configuration.
6. After resolving preview errors, teachers select “Create copies”. The server validates the configuration again and creates all assistants and relationships in one transaction. A failed creation leaves no partial assistants. On success, the page opens the new configuration. Teachers need to upload knowledge materials again and select the new assistant for a destination Topic when required.

每次导入都会创建独立副本，现有助教和 Topic 绑定保持原样。管理员需要提前准备目标站点的模型和工具授权。预览中的修改会在创建前保留，导入完成后的保存与运行规则与普通助教一致。

Every import creates independent copies and preserves existing assistants and Topic bindings. Administrators need to prepare model and tool authorization on the destination site in advance. Preview edits are retained before creation, and imported assistants follow the same saving and execution rules as other assistants.

## 24. 页面内指引与保存 / In-page guidance and saving

课程管理顶部提供五个工作区的导航。桌面导航在滚动时保持可用，窄屏的“本页导航 / On this page”菜单显示当前位置。已有 `#ai` 链接继续打开 AI 助教区域。助教编辑器提供“返回助教列表”，从 Bloc 进入编辑器时还可以返回原 Bloc 配置。

Course management provides navigation among its five workspaces. Desktop navigation remains available while scrolling, and the narrow-screen “On this page” menu identifies the current workspace. Existing `#ai` links continue to open the AI assistant area. The assistant editor provides a return to the assistant list, and editing from a Bloc also allows a return to that Bloc configuration.

教师可以调整 Prompt 和技能正文输入框的高度，以便阅读和编辑较长内容。`temperature` 和 `top_p` 位于可展开的“高级模型参数”中。Bloc 选择 Dais 后会显示 Delegate 列表和数量，编辑助教与保存协作关系分别使用对应按钮。

Teachers can resize the Prompt and skill instruction fields vertically to read and edit longer content. `temperature` and `top_p` appear under the expandable “Advanced model parameters” section. Selecting a Dais displays the Delegate list and count, with separate controls for editing assistants and saving collaboration relationships.

用户点击“使用指引 / Usage guide”后，桌面会打开侧边说明面板，手机会显示适配屏幕的对话框。用户可以使用关闭按钮或 Escape 关闭指引，焦点随后返回打开指引的按钮。字段旁的说明按钮支持悬停、键盘聚焦和点击，打开帮助会保留当前输入。

Selecting “Usage guide” opens a side panel on desktop or an adapted dialog on mobile. Users can close it with the close button or Escape, after which focus returns to the button that opened it. Field help buttons support hovering, keyboard focus and clicking. Opening help preserves the current input.

管理员指引集中提供模型、凭据、课程模型授权、知识嵌入向量和工作流入口。对应原生后台页面提供教学平台指引及“返回课程配置 / Back to course setup”。数据导出和运行维护页面也提供筛选、时间范围、保留期及运行记录定位的说明。

Administrator guidance provides links to models, credentials, course model authorization, embeddings and workflows. The corresponding native administration pages provide teaching guidance and “Back to course setup”. Data export and maintenance pages also explain filters, time ranges, retention and run record navigation.

保存按钮会标明具体对象，例如“保存课程”“保存助教”“保存 Bloc”和“保存 Topic 设置”。页面会显示未保存状态，用户需要主动点击相应按钮完成保存。保存失败时，平台会保留输入并显示错误。打开帮助或使用管理员页面内部的定位链接会保留当前草稿。

Save buttons identify their objects, such as “Save course”, “Save assistant”, “Save Bloc” and “Save Topic settings”. The page shows unsaved changes, and users need to select the corresponding button to save them. A failed save preserves the input and displays an error. Opening help or using section links within the administrator page preserves the current draft.

存在未保存修改时，用户切换工作区、助教、Dais 或站内页面，会先看到“继续编辑 / Continue editing”和“放弃修改 / Discard changes”的选择。关闭或刷新浏览器页面时，浏览器会按其支持情况显示原生未保存提醒。用户应在离开前完成保存，或明确选择放弃修改。

When unsaved changes exist, switching workspaces, assistants, the Dais or in-app pages first offers “Continue editing” and “Discard changes”. Closing or reloading the browser page uses the browser's native unsaved-change prompt where supported. Users should save before leaving or explicitly choose to discard their changes.

JSON 导入预览通过根助教与 Delegate 列表切换编辑对象，各助教会保留自己的预览修改。模型映射和错误摘要会帮助用户检查配置；缺少必填内容时，页面会切换到需要修正的助教。用户最终提交时，平台会统一创建完整副本。

The JSON import preview uses the root assistant and Delegate list to switch editors while preserving each assistant's preview changes. Model mappings and the error summary help users check the configuration. Missing required content selects the assistant that needs correction. The final submission creates the complete copy together.

Topic 页面分别展示回复配置、生成操作和审核记录，并提供返回课程、返回讨论及编辑当前助教的入口。首次保存前，页面会说明初始化要求；无法生成时，页面会列出具体配置原因及处理入口。教师保存设置后，可以选择学生帖子并生成回复。

The Topic page separates reply configuration, generation controls and review records and links back to the course, discussion and current assistant. Before the first save, it explains initialization requirements. When generation is unavailable, it lists specific configuration reasons and links for resolving them. Teachers can select a student post and generate a reply after saving the settings.

待审核草稿也受到未保存保护。刷新记录、生成另一条回复、保存 Topic 设置，或审核其他记录而将重新加载已编辑草稿时，平台会先要求用户选择继续编辑或放弃修改。用户取消操作时，当前输入会保留；刷新失败时，输入也会保留。刷新运行记录还会保留尚未保存的 Topic 设置。

Pending review drafts also receive unsaved-change protection. Refreshing records, generating another reply, saving Topic settings, or reviewing another record that would reload edited drafts first asks users to continue editing or discard their changes. Cancelling the action preserves the input, as does a failed refresh. Refreshing run records also retains unsaved Topic settings.
