import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import EduDirtyGuard from "discourse/plugins/discourse-educustomize/discourse/components/edu-dirty-guard";
import EduHelp from "discourse/plugins/discourse-educustomize/discourse/components/edu-help";

export default class EduAdmin extends Component {
  @service router;

  @tracked retentionApi;
  @tracked samplingApi;
  @tracked busy = false;
  @tracked prepared = false;
  @tracked retentionSaved = false;
  @tracked teachingPrepared = false;
  @tracked samplingSaved = false;
  skipDirtyCheck = () => false;

  get dirty() {
    return this.retentionApi?.isDirty || this.samplingApi?.isDirty;
  }

  @action
  registerApi(kind, api) {
    if (kind === "retention") {
      this.retentionApi = api;
    } else {
      this.samplingApi = api;
    }
  }

  @action
  async saveSampling(data) {
    try {
      await ajax("/educustomize/admin/sampling.json", {
        type: "PUT",
        data: { enabled: data.enabled },
      });
      this.samplingApi.commit();
      this.samplingSaved = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get featureChecks() {
    return Object.entries(this.args.model.teaching?.features || {}).map(
      ([key, ready]) => ({
        label: i18n("educustomize.learning.features." + key),
        state: i18n(
          "educustomize.dependency." + (ready ? "enabled" : "disabled")
        ),
      })
    );
  }

  @action
  async prepareTeaching() {
    this.busy = true;
    try {
      await ajax("/educustomize/admin/teaching.json", { type: "POST" });
      this.teachingPrepared = true;
      await this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async saveRetention(data) {
    try {
      await ajax("/educustomize/admin/workflow-retention.json", {
        type: "PUT",
        data: { days: data.days },
      });
      this.retentionApi.commit();
      this.args.model.retention.workflow_days = Number(data.days);
      this.retentionSaved = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get dependencies() {
    return Object.entries(this.args.model.dependencies).map(
      ([key, enabled]) => ({
        name: i18n("educustomize.dependency." + key),
        status: i18n(
          enabled
            ? "educustomize.dependency.enabled"
            : "educustomize.dependency.disabled"
        ),
      })
    );
  }

  get unavailable() {
    return !Object.values(this.args.model.dependencies).every(Boolean);
  }

  @action
  async prepare() {
    this.busy = true;
    try {
      await ajax("/educustomize/admin/workflow.json", { type: "POST" });
      this.prepared = true;
      await this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <section class="educustomize">
      <h2>{{i18n "educustomize.admin.title"}}</h2>
      <EduDirtyGuard @isDirty={{this.dirty}} />
      <nav
        class="educustomize__workspace-nav"
        aria-label={{i18n "educustomize.ui.navigation"}}
      >
        <div class="educustomize__actions">
          <a href="#edu-admin-teaching">{{i18n
              "educustomize.learning.prepare_title"
            }}</a>
          <a href="#edu-admin-models">{{i18n "educustomize.model"}}</a>
          <a href="#edu-admin-workflow">{{i18n "educustomize.workflow"}}</a>
          <a href="#edu-admin-reports">{{i18n
              "educustomize.research.title"
            }}</a>
          <a href="#edu-admin-platform">{{i18n
              "educustomize.learning.system_admin"
            }}</a>
        </div>
        <EduHelp @context="admin" />
      </nav>
      <p>{{i18n "educustomize.admin.help"}}</p>
      <nav class="educustomize__actions">
        <a
          class="btn"
          href="/admin/site_settings/category/all_results?filter=educustomize"
        >{{i18n "educustomize.admin.settings"}}</a>
        <a class="btn" href="/admin/plugins/discourse-ai/ai-llms">{{i18n
            "educustomize.admin.models"
          }}</a>
        <a class="btn" href="/admin/plugins/discourse-ai/ai-secrets">{{i18n
            "educustomize.ui.credentials"
          }}</a>
        <a class="btn" href="/admin/plugins/discourse-ai/ai-embeddings">{{i18n
            "educustomize.ui.embeddings"
          }}</a>
        <a class="btn" href="/admin/groups">{{i18n
            "educustomize.admin.teachers"
          }}</a>
        <a class="btn" href="/educustomize">{{i18n "educustomize.title"}}</a>
      </nav>
      <section class="educustomize__card" id="edu-admin-teaching">
        <h3>{{i18n "educustomize.dependencies"}}</h3>
        <ul>{{#each this.dependencies as |dependency|}}<li>{{dependency.name}}:
              {{dependency.status}}</li>{{/each}}</ul>
        <h3>{{i18n "educustomize.learning.prepare_title"}}</h3>
        <p>{{i18n "educustomize.learning.prepare_help"}}</p>
        <DButton
          @label="educustomize.learning.prepare"
          @action={{this.prepareTeaching}}
          @disabled={{this.busy}}
        />
        {{#if this.teachingPrepared}}<p role="status">{{i18n
              "educustomize.saved"
            }}</p>{{/if}}
        <ul>{{#each this.featureChecks as |check|}}<li>{{check.label}}:
              {{check.state}}</li>{{/each}}</ul>
        <ul>
          <li>{{i18n "educustomize.learning.teacher_requests"}}:
            {{#if @model.teaching.teacher_requests_ready}}{{i18n
                "educustomize.learning.configured"
              }}{{else}}{{i18n
                "educustomize.learning.setup_needed"
              }}{{/if}}</li>
          <li>{{i18n "educustomize.learning.teacher_permissions"}}:
            {{#if @model.teaching.teacher_permissions_ready}}{{i18n
                "educustomize.learning.configured"
              }}{{else}}{{i18n
                "educustomize.learning.setup_needed"
              }}{{/if}}</li>
          <li>{{i18n "educustomize.learning.files"}}:
            {{#if @model.teaching.files_ready}}{{i18n
                "educustomize.learning.configured"
              }}{{else}}{{i18n
                "educustomize.learning.setup_needed"
              }}{{/if}}</li>
          <li>{{i18n "educustomize.learning.templates"}}:
            {{#if @model.teaching.templates_ready}}{{i18n
                "educustomize.learning.configured"
              }}{{else}}{{i18n
                "educustomize.learning.setup_needed"
              }}{{/if}}</li>
        </ul>
        {{#if @model.teaching.teacher_group_url}}<a
            class="btn"
            href={{@model.teaching.teacher_group_url}}
          >{{i18n "educustomize.learning.teacher_requests"}}</a>{{/if}}
      </section>
      <section class="educustomize__card" id="edu-admin-models">
        <h3>{{i18n "educustomize.admin.model_list"}}</h3>
        <p>{{i18n "educustomize.admin.sampling_help"}}</p>
        <Form
          @data={{hash enabled=@model.sampling_enabled}}
          @onSubmit={{this.saveSampling}}
          @onRegisterApi={{fn this.registerApi "sampling"}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form|
        >
          <form.Field
            @name="enabled"
            @title={{i18n "educustomize.admin.sampling_enabled"}}
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Submit @label="educustomize.ui.save_sampling" />
        </Form>
        {{#if this.samplingSaved}}<p role="status">{{i18n
              "educustomize.saved"
            }}</p>{{/if}}
        <p>{{i18n "educustomize.admin.model_help"}}</p>
        <ul>{{#each @model.models as |model|}}<li>{{model.name}}
              (ID:
              {{model.id}})</li>{{else}}<li>{{i18n
                "educustomize.admin.no_models"
              }}</li>{{/each}}</ul>
      </section>
      <section class="educustomize__card" id="edu-admin-workflow">
        <h3>{{i18n "educustomize.workflow"}}</h3>
        <p>{{i18n "educustomize.admin.workflow_help"}}</p>
        <DButton
          @label="educustomize.admin.prepare"
          @action={{this.prepare}}
          @disabled={{this.unavailable}}
          @isLoading={{this.busy}}
        />
        {{#if this.prepared}}<p role="status">{{i18n
              "educustomize.admin.prepared"
            }}</p>{{/if}}
        <ul>{{#each @model.workflows as |workflow|}}<li>{{workflow.name}}
              (ID:
              {{workflow.id}})</li>{{/each}}</ul>
      </section>
      <section class="educustomize__card" id="edu-admin-reports">
        <h3>{{i18n "educustomize.research.title"}}</h3>
        <p>{{#if @model.explorer_available}}{{i18n
              "educustomize.dependency.enabled"
            }}{{else}}{{i18n "educustomize.research.unavailable"}}{{/if}}</p>
        <nav class="educustomize__actions">
          <a
            class="btn"
            href="/admin/site_settings/category/all_results?filter=data_explorer_enabled"
          >{{i18n "educustomize.research.configure"}}</a>
          <a class="btn" href="/admin/plugins/discourse-data-explorer">{{i18n
              "educustomize.dependency.data_explorer"
            }}</a>
          <a class="btn" href="/admin/plugins/discourse-ai/ai-usage">{{i18n
              "educustomize.maintenance.ai_usage"
            }}</a>
          <a class="btn" href="/admin/plugins/discourse-ai/ai-logs">{{i18n
              "educustomize.maintenance.ai_logs"
            }}</a>
          <a class="btn" href="/admin/plugins/discourse-workflows">{{i18n
              "educustomize.workflow"
            }}</a>
        </nav>
        <ul>{{#each @model.courses as |course|}}
            <li>{{course.name}}:
              <a
                href={{concat "/educustomize/courses/" course.id "/reports"}}
              >{{i18n "educustomize.research.title"}}</a>
              ·
              <a
                href={{concat
                  "/educustomize/courses/"
                  course.id
                  "/maintenance"
                }}
              >{{i18n "educustomize.maintenance.title"}}</a>
            </li>
          {{/each}}</ul>
        <h3>{{i18n "educustomize.maintenance.retention_title"}}</h3>
        <p>{{i18n
            "educustomize.research.retention"
            workflow=@model.retention.workflow_days
            ai=@model.retention.ai_days
          }}</p>
        <Form
          @data={{hash days=@model.retention.workflow_days}}
          @onSubmit={{this.saveRetention}}
          @onRegisterApi={{fn this.registerApi "retention"}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form|
        >
          <form.Field
            @name="days"
            @title={{i18n "educustomize.maintenance.retention_days"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control @type="number" /></form.Field>
          <form.Submit @label="educustomize.ui.save_retention" />
        </Form>
        {{#if this.retentionSaved}}<p role="status">{{i18n
              "educustomize.saved"
            }}</p>{{/if}}
      </section>
      <section class="educustomize__card" id="edu-admin-platform">
        <h3>{{i18n "educustomize.learning.system_admin"}}</h3>
        <nav class="educustomize__actions">
          <a class="btn" href="/admin/users">{{i18n
              "educustomize.learning.accounts"
            }}</a>
          <a class="btn" href="/admin/customize/themes">{{i18n
              "educustomize.learning.themes"
            }}</a>
          <a class="btn" href="/admin/plugins">{{i18n
              "educustomize.learning.plugins"
            }}</a>
          <a class="btn" href="/admin/backups">{{i18n
              "educustomize.learning.backups"
            }}</a>
          <a class="btn" href="/admin/logs/staff_action_logs">{{i18n
              "educustomize.learning.audit"
            }}</a>
          <a class="btn" href="/logs">{{i18n
              "educustomize.learning.errors"
            }}</a>
          <a class="btn" href="/sidekiq">{{i18n
              "educustomize.learning.jobs"
            }}</a>
        </nav>
      </section>
    </section>
  </template>
}
