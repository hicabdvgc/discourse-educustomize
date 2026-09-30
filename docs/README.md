# 0.3.1 文档 / Documentation

本目录介绍 discourse-educustomize 0.3.1 的安装、使用和技术实现。管理员可以从安装指南开始，教师和学生可以按用户手册完成日常操作，维护人员可以查阅技术参考及数据契约。

This directory documents the installation, use and implementation of discourse-educustomize 0.3.1. Administrators can begin with the installation guide, teachers and students can follow the user manual, and maintainers can consult the technical reference and data contracts.

| 文档 / Document | 用途 / Purpose |
| --- | --- |
| [安装指南 / Installation guide](installation.md) | 本指南说明兼容版本、部署步骤、依赖启用、模型接入和升级方法。 / This guide explains compatible versions, deployment, dependencies, model connections and upgrades. |
| [用户手册 / User manual](user-manual.md) | 本手册以中英文介绍管理员、教师和学生的完整操作流程。 / This bilingual manual explains the complete workflows for administrators, teachers and students. |
| [技术参考 / Technical reference](technical-reference.md) | 本文说明架构、权限、数据存储、AI 执行、接口及运行维护要求。 / This reference explains the architecture, permissions, storage, AI execution, interfaces and maintenance requirements. |
| [JSON 配置契约 / JSON configuration contract](agent-configuration-format.md) | 本文说明助教配置的字段、关系、模型映射和导入导出行为。 / This contract explains assistant fields, relationships, model mappings and import/export behavior. |
| [JSON Schema](../config/agent-configuration.schema.json) | 此文件定义配置格式的机器校验规则。 / This file defines the machine-readable validation rules for the configuration format. |
| [完整 Bloc 示例 / Complete Bloc example](examples/bloc.json) | 此示例包含一个 Dais 和两个 Delegate，可用于了解文件结构和编辑配置。 / This example contains one Dais and two Delegates and demonstrates how to structure and edit a configuration. |
| [报表字段说明 / Report field reference](report-fields.md) | 本文解释八种报表的字段、筛选口径、空值和导出限制。 / This reference explains the fields, filters, missing values and export limits for all eight reports. |

示例中的模型描述需要在目标站点映射到管理员授权的模型。模型凭据、知识文件和运行数据由部署方配置和保存。

The example's model descriptors must be mapped to models authorized on the destination site. The deployment administrator configures and stores credentials, knowledge files and runtime data.
