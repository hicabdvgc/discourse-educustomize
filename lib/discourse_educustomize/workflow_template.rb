# frozen_string_literal: true
module DiscourseEducustomize
  module WorkflowTemplate
    def self.graph
      definitions = [
        ["manual", "trigger:manual", "Manual", {}],
        ["event", "trigger:post_created", "Student post", { "topic_type" => "topics" }],
        ["generate", "action:educustomize_generate", "Generate", {}],
        [
          "needs_review",
          "condition:if",
          "Review required",
          {
            "conditions" => [
              {
                "id" => "review",
                "leftValue" => "={{ $json.require_review }}",
                "rightValue" => true,
                "operator" => {
                  "type" => "boolean",
                  "operation" => "equals",
                },
              },
            ],
          },
        ],
        [
          "notify",
          "action:modal",
          "Review notification",
          {
            "title" => I18n.t("educustomize.review_title"),
            "body" => "={{ $('Generate').first().json.review_url }}",
            "target_user" => "={{ $('Generate').first().json.reviewer }}",
            "buttons" => {
              "values" => [],
            },
          },
        ],
        [
          "edit",
          "action:form",
          "Edit",
          {
            "form_title" => I18n.t("educustomize.review_title"),
            "form_fields" => [
              {
                "field_label" => I18n.t("educustomize.draft"),
                "field_name" => "draft",
                "field_type" => "textarea",
                "default_value" => "={{ $('Generate').first().json.draft }}",
                "required_field" => true,
              },
            ],
          },
        ],
        [
          "review",
          "action:modal",
          "Review",
          {
            "title" => I18n.t("educustomize.review_title"),
            "body" => "={{ $json.draft }}",
            "target_user" => "={{ $('Generate').first().json.reviewer }}",
            "buttons" => {
              "values" => [
                { "label" => I18n.t("educustomize.approve"), "value" => "approve" },
                { "label" => I18n.t("educustomize.reject"), "value" => "reject" },
              ],
            },
          },
        ],
        [
          "approved",
          "condition:if",
          "Approved",
          {
            "conditions" => [
              {
                "id" => "approved",
                "leftValue" => "={{ $json.button }}",
                "rightValue" => "approve",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          },
        ],
        [
          "publish",
          "action:educustomize_publish",
          "Publish reviewed",
          post_parameters("={{ $('Edit').first().json.draft }}"),
        ],
        [
          "automatic",
          "action:educustomize_publish",
          "Publish automatic",
          post_parameters("={{ $('Generate').first().json.draft }}"),
        ],
      ]
      nodes =
        definitions.each_with_index.map do |(id, type, name, parameters), i|
          {
            "id" => id,
            "type" => type,
            "name" => name,
            "typeVersion" => "1.0",
            "position" => {
              "x" => i * 200,
              "y" => 0,
            },
            "parameters" => parameters,
            "credentials" => {
            },
          }
        end
      connections = {}
      [
        ["Manual", "Generate", 0],
        ["Student post", "Generate", 0],
        ["Generate", "Review required", 0],
        ["Review required", "Review notification", 0],
        ["Review required", "Publish automatic", 1],
        ["Review notification", "Edit", 0],
        ["Edit", "Review", 0],
        ["Review", "Approved", 0],
        ["Approved", "Publish reviewed", 0],
      ].each do |from, to, output|
        connections[from] ||= { "main" => [] }
        connections[from]["main"][output] ||= []
        connections[from]["main"][output] << { "node" => to, "type" => "main", "index" => 0 }
      end
      { nodes: nodes, connections: connections }
    end

    def self.post_parameters(raw)
      {
        "operation" => "create",
        "topic_id" => "={{ $('Generate').first().json.topic_id }}",
        "raw" => raw,
        "author_username" => "system",
        "reply_to_post_number" => "={{ $('Generate').first().json.post_number }}",
      }
    end

    def self.valid?(workflow)
      return false unless workflow&.active_version_id
      expected = graph
      # Labels are localized at installation; executable configuration is fixed.
      normalize =
        lambda do |nodes|
          nodes.map do |node|
            params = node["parameters"].deep_dup
            if %w[notify review edit].include?(node["id"])
              params.except!("title", "body", "form_title")
            end
            params["buttons"]&.dig("values")&.each { _1.delete("label") }
            params["form_fields"]&.each { _1.delete("field_label") }
            node.slice("id", "type", "name", "typeVersion").merge("parameters" => params)
          end
        end
      normalize.call(workflow.published_nodes) == normalize.call(expected[:nodes]) &&
        workflow.published_connections == expected[:connections]
    end

    def self.install!(admin)
      raise Discourse::InvalidAccess unless admin.admin?
      result =
        DiscourseWorkflows::Workflow::Create.call(
          guardian: admin.guardian,
          params: graph.merge(name: "Course teaching reply"),
        )
      raise "Workflow creation failed: #{result.inspect}" unless result.success?
      workflow = result[:workflow]
      publish =
        DiscourseWorkflows::Workflow::Publish.call(
          guardian: admin.guardian,
          params: {
            workflow_id: workflow.id,
          },
        )
      raise "Workflow publication failed: #{publish.inspect}" unless publish.success?
      ids = Access.ids(:educustomize_workflow_ids) | [workflow.id]
      SiteSetting.educustomize_workflow_ids = ids.join("|")
      workflow.reload
    end
  end
end
