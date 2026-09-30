import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import confirmEduDiscard from "../lib/confirm-edu-discard";
import EduDirtyGuard from "./edu-dirty-guard";
import EduFieldHelp from "./edu-field-help";
import EduHelp from "./edu-help";
import EduReview from "./edu-review";

export default class EduTopic extends Component {
  @service router;
  @service dialog;
  @service currentUser;

  @tracked formApi;
  @tracked runs = [];
  @tracked saved = false;
  @tracked queued = false;
  @tracked reviewEditors = [];
  skipDirtyCheck = () => false;

  get dirtyReviews() {
    return this.reviewEditors.filter(
      (editor) => !editor.isDestroying && !editor.isDestroyed && editor.dirty
    );
  }

  get dirty() {
    return this.formApi?.isDirty || this.dirtyReviews.length > 0;
  }

  get courseUrl() {
    return `/educustomize/courses/${this.args.model.course_id}`;
  }

  get assistantUrl() {
    return `${this.courseUrl}#ai-${this.args.model.policy.ai_agent_id}`;
  }

  get reasons() {
    return (this.args.model.readiness_reasons || []).map((code) =>
      i18n(`educustomize.maintenance.reasons.${code}`)
    );
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  registerReview(editor) {
    schedule("afterRender", () => {
      if (!this.isDestroying && !this.isDestroyed) {
        this.reviewEditors = [
          ...this.reviewEditors.filter((item) => !item.isDestroyed),
          editor,
        ];
      }
    });
  }

  @action
  refreshRecords() {
    return confirmEduDiscard(this.dialog, this.dirtyReviews.length > 0, () =>
      this.refresh()
    );
  }

  get topicUrl() {
    return "/t/" + this.args.model.topic_id;
  }

  get base() {
    return "/educustomize/topics/" + this.args.model.topic_id;
  }

  @action
  async refresh() {
    if (!this.args.model.policy_id) {
      this.runs = [];
      return;
    }
    try {
      this.runs = (
        await ajax(this.base + "/runs.json", {
          data: { run_id: this.args.model.run_id },
        })
      ).runs.map((run) => ({
        ...run,
        status_label: i18n(
          "educustomize.status." + (run.outcome || run.status)
        ),
      }));
      const selected = this.runs.find(
        (run) => String(run.id) === String(this.args.model.run_id)
      );
      if (selected) {
        DiscourseURL.jumpToElement("run-" + selected.id);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  save(data) {
    return confirmEduDiscard(
      this.dialog,
      this.dirtyReviews.length > 0,
      async () => {
        try {
          await ajax(this.base + ".json", {
            type: "PUT",
            data: {
              policy: {
                ...data,
                ai_agent_id: data.ai_agent_id || null,
                workflow_id: data.workflow_id || null,
              },
            },
          });
          this.formApi.commit();
          await Promise.all(
            this.dirtyReviews.map((editor) => editor.formApi.reset())
          );
          this.saved = true;
          this.router.refresh();
        } catch (error) {
          popupAjaxError(error);
        }
      }
    );
  }

  async queueReply(postId) {
    await ajax(this.base + "/runs.json", {
      type: "POST",
      data: { post_id: postId, request_key: crypto.randomUUID() },
    });
    this.queued = true;
  }

  @action
  generate(data) {
    return confirmEduDiscard(
      this.dialog,
      this.dirtyReviews.length > 0,
      async () => {
        try {
          await this.queueReply(data.post_id);
          await this.refresh();
        } catch (error) {
          popupAjaxError(error);
        }
      }
    );
  }

  @action
  decide(run, decision, data, onSuccess) {
    const otherDrafts = this.dirtyReviews.some(
      (editor) => editor.args.run.id !== run.id
    );
    return confirmEduDiscard(this.dialog, otherDrafts, async () => {
      try {
        await ajax(this.base + "/runs/" + run.id + ".json", {
          type: "PUT",
          data: { decision, draft: data?.draft || run.draft },
        });
        onSuccess?.();
        try {
          if (decision === "regenerate") {
            await this.queueReply(run.post_id);
          }
        } finally {
          await this.refresh();
        }
      } catch (error) {
        popupAjaxError(error);
      }
    });
  }

  <template>
    <main
      class="educustomize"
      {{didInsert this.refresh}}
      {{didUpdate this.refresh @model}}
    >
      <EduDirtyGuard @isDirty={{this.dirty}} />
      <nav
        class="educustomize__actions"
        aria-label={{i18n "educustomize.learning.navigation"}}
      >
        <a href={{this.courseUrl}}>{{i18n "educustomize.ui.back_to_course"}}</a>
        <a href={{this.topicUrl}}>{{i18n "educustomize.ui.back_to_topic"}}</a>
        {{#if @model.policy.ai_agent_id}}<a href={{this.assistantUrl}}>{{i18n
              "educustomize.ui.edit_assistant"
            }}</a>{{/if}}
        <EduHelp @context="topics" @courseId={{@model.course_id}} />
      </nav>
      <p>{{@model.title}}</p>
      <h1>{{i18n "educustomize.ai_settings"}}</h1>
      <p class="educustomize__notice">{{#if @model.ready}}{{i18n
            "educustomize.ready"
          }}{{else}}{{i18n "educustomize.not_ready"}}{{/if}}</p>
      {{#unless @model.policy_id}}<p>{{i18n
            "educustomize.ui.initialize_topic"
          }}</p>{{/unless}}
      {{#if this.reasons}}<ul class="educustomize__readiness">{{#each
            this.reasons
            as |reason|
          }}<li>{{reason}}</li>{{/each}}</ul>
        <nav class="educustomize__actions"><a
            href={{concat this.courseUrl "/maintenance"}}
          >{{i18n "educustomize.maintenance.title"}}</a>{{#if
            this.currentUser.admin
          }}<a href="/admin/plugins/discourse-educustomize">{{i18n
                "educustomize.admin.title"
              }}</a>{{/if}}</nav>
      {{/if}}
      <section class="educustomize__card"><h2>{{i18n
            "educustomize.ui.topic_configuration"
          }}</h2>
        <Form
          @data={{@model.policy}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.registerApi}}
          @onDirtyCheck={{this.skipDirtyCheck}}
          @commitOnSubmit={{false}}
          as |form|
        >
          <form.Field
            @name="ai_agent_id"
            @title={{i18n "educustomize.binding"}}
            @type="select"
            as |field|
          >
            <field.Control as |control|>{{#each
                @model.agents
                as |item|
              }}<control.Option
                  @value={{item.id}}
                >{{item.name}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <form.Field
            @name="workflow_id"
            @title={{i18n "educustomize.workflow"}}
            @type="select"
            as |field|
          >
            <field.Control as |control|>{{#each
                @model.workflows
                as |item|
              }}<control.Option
                  @value={{item.id}}
                >{{item.name}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <form.Field
            @name="reviewer_id"
            @title={{i18n "educustomize.reviewer"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control as |control|>{{#each
                @model.reviewers
                as |item|
              }}<control.Option
                  @value={{item.id}}
                >{{item.name}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <form.Field
            @name="auto_reply"
            @title={{i18n "educustomize.auto_reply"}}
            @type="checkbox"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @name="memory"
            @title={{i18n "educustomize.memory"}}
            @type="checkbox"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @name="require_review"
            @title={{i18n "educustomize.review"}}
            @type="checkbox"
            as |field|
          ><field.Control /></form.Field>
          <p>{{i18n "educustomize.ui.topic_help"}}
            <EduFieldHelp
              @title={{i18n "educustomize.workflow"}}
              @text={{i18n "educustomize.ui.workflow_help"}}
            /></p>
          <div class="educustomize__save-bar"><form.Submit
              @label="educustomize.ui.save_topic"
            /><span role="status">{{if
                this.formApi.isDirty
                (i18n "educustomize.ui.unsaved")
              }}</span></div>
        </Form>
        {{#if this.saved}}<p role="status">{{i18n
              "educustomize.saved"
            }}</p>{{/if}}
      </section>
      <section class="educustomize__card"><h2>{{i18n
            "educustomize.generate"
          }}</h2>
        <Form @onSubmit={{this.generate}} as |form|>
          <form.Field
            @name="post_id"
            @title={{i18n "educustomize.post"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control as |control|>{{#each
                @model.posts
                as |post|
              }}<control.Option
                  @value={{post.id}}
                >{{post.name}}</control.Option>{{/each}}</field.Control>
          </form.Field>
          <form.Submit
            @disabled={{or (not @model.ready) this.formApi.isDirty}}
            @label="educustomize.generate"
          />
        </Form>
        {{#if this.queued}}<p role="status">{{i18n
              "educustomize.pending"
            }}</p>{{/if}}
        {{#if this.formApi.isDirty}}<p role="status">{{i18n
              "educustomize.ui.save_before_generate"
            }}</p>{{/if}}
      </section>
      <h2>{{i18n "educustomize.runs"}}</h2>
      <DButton @label="educustomize.refresh" @action={{this.refreshRecords}} />
      {{#each this.runs as |run|}}
        <article class="educustomize__card" id={{concat "run-" run.id}}>
          <p>#{{run.id}} · {{run.status_label}}</p>
          {{#if run.published_post_id}}
            <a href={{concat "/p/" run.published_post_id}}>{{i18n
                "educustomize.view_published"
              }}</a>
          {{/if}}
          <EduReview
            @run={{run}}
            @onDecide={{this.decide}}
            @onRegister={{this.registerReview}}
          />
        </article>
      {{/each}}
    </main>
  </template>
}
