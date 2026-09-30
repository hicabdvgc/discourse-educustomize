# frozen_string_literal: true

module DiscourseEducustomize
  class AgentConfiguration
    class Invalid < StandardError
    end

    def self.schema
      @schema ||=
        JSON.parse(
          File.read(File.expand_path("../../config/agent-configuration.schema.json", __dir__)),
        )
    end

    attr_reader :document

    def initialize(document)
      @document = document
    end

    def errors
      schema_errors =
        JSONSchemer
          .schema(self.class.schema)
          .validate(document)
          .map { |error| schema_error_message(error) }
      return schema_errors if schema_errors.any?
      agents = document.fetch("agents")
      keys = agents.map { |agent| agent.fetch("key") }
      root = agents.find { |agent| agent["key"] == document["root"] }
      issues = []
      issues << I18n.t("educustomize.configuration.duplicate_keys") if keys.uniq != keys
      issues << I18n.t("educustomize.configuration.root_missing") unless root
      return issues if issues.any?
      expected = [root["key"], *root["delegates"]]
      unless expected.uniq == expected && expected.sort == keys.sort &&
               agents.reject { |agent| agent == root }.all? { |agent| agent["delegates"].empty? }
        issues << I18n.t("educustomize.configuration.invalid_graph")
      end
      agents.each do |agent|
        if AgentInstructions.compose(agent["system_prompt"], agent["skills"]).length >
             AgentInstructions::MAX_LENGTH
          issues << "#{agent["key"]}: #{I18n.t("educustomize.configuration.prompt_too_long")}"
        end
        unavailable = agent["tools"] - AiConfiguration.tools
        if unavailable.any?
          issues << "#{agent["key"]}: #{I18n.t("educustomize.configuration.tools_unavailable", tools: unavailable.join(", "))}"
        end
      end
      issues
    end

    def validate!
      messages = errors
      raise Invalid, messages.join("\n") if messages.any?
      self
    end

    def preview
      validate!
      copy = document.deep_dup
      used_names = AiAgent.pluck(:name).to_set
      mapping = {}
      copy["agents"].each do |agent|
        original = agent["name"]
        candidate = original
        suffix_number = 2
        while used_names.include?(candidate)
          suffix = I18n.t("educustomize.configuration.copy_suffix", number: suffix_number)
          candidate = original.first(100 - suffix.length) + suffix
          suffix_number += 1
        end
        agent["name"] = candidate
        used_names << candidate
        model = agent["model"]
        matches =
          (
            if model
              AiConfiguration
                .models
                .where(provider: model["provider"], name: model["name"])
                .pluck(:id)
            else
              []
            end
          )
        mapping[agent["key"]] = matches.one? ? matches.first : nil
      end
      { document: copy, model_mappings: mapping }
    end

    def mapping_errors(mappings)
      return [I18n.t("educustomize.configuration.invalid_mapping")] unless mappings.is_a?(Hash)
      keys = document["agents"].map { |agent| agent["key"] }
      issues = []
      issues << I18n.t("educustomize.configuration.invalid_mapping") if (mappings.keys - keys).any?
      document["agents"].each do |agent|
        model_id = mappings[agent["key"]]
        if agent["model"].nil?
          if model_id
            issues << "#{agent["key"]}: #{I18n.t("educustomize.configuration.invalid_mapping")}"
          end
        elsif !model_id.is_a?(Integer) || !AiConfiguration.models.exists?(id: model_id)
          issues << "#{agent["key"]}: #{I18n.t("educustomize.configuration.model_required")}"
        end
      end
      issues
    end

    private

    def schema_error_message(error)
      path = error.fetch("data_pointer").presence || "/"
      type = error.fetch("type")
      schema = error.fetch("schema")
      options = { path: path }
      key =
        case type
        when "required"
          options[:fields] = error.fetch("details").fetch("missing_keys").join(", ")
          "required"
        when "const"
          options[:value] = schema.fetch("const").to_json
          "constant"
        when "schema"
          schema == false ? "unknown_field" : "invalid"
        when "minItems", "maxItems", "minLength", "maxLength", "minimum", "maximum",
             "exclusiveMinimum"
          options[:limit] = schema.fetch(type)
          type
        when "pattern"
          options[:pattern] = schema.fetch("pattern")
          "pattern"
        when "uniqueItems"
          "unique_items"
        when "type", "string", "number", "integer", "boolean", "array", "object", "null"
          options[:types] = Array(schema.fetch("type")).join(", ")
          "type"
        else
          "invalid"
        end
      I18n.t("educustomize.configuration.validation.#{key}", **options)
    end
  end
end
