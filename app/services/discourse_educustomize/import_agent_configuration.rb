# frozen_string_literal: true

module DiscourseEducustomize
  class ImportAgentConfiguration
    include Service::Base

    params do
      attribute :course_id, :integer
      attribute :document
      attribute :model_mappings, default: -> { {} }

      before_validation do
        self.document = document.deep_stringify_keys if document.is_a?(Hash)
        self.model_mappings = model_mappings.stringify_keys if model_mappings.is_a?(Hash)
      end

      validates :course_id, presence: true
      validate :configuration_valid

      def configuration
        @configuration ||= AgentConfiguration.new(document)
      end

      def configuration_valid
        messages = configuration.errors
        messages += configuration.mapping_errors(model_mappings) if messages.empty?
        if messages.empty?
          names = document["agents"].map { |agent| agent["name"] }
          taken = AiAgent.where(name: names).pluck(:name)
          duplicates = names.tally.select { |_, count| count > 1 }.keys
          (taken + duplicates).uniq.each do |name|
            messages << I18n.t("educustomize.configuration.name_taken", name: name)
          end
        end
        messages.each { |message| errors.add(:document, message) }
      end
    end

    model :course
    policy :course_teacher
    transaction { model :agents, :create_agents }

    private

    def fetch_course(params:)
      Course.find_by(id: params.course_id)
    end

    def course_teacher(guardian:, course:)
      Access.teacher?(guardian.user, course)
    end

    def create_agents(params:, guardian:, course:)
      records = {}
      params.document["agents"]
        .sort_by { |agent| agent["delegates"].empty? ? 0 : 1 }
        .each do |item|
          result =
            SaveAgent.call(
              guardian: guardian,
              params:
                item.slice(
                  "name",
                  "description",
                  "system_prompt",
                  "skills",
                  "enabled",
                  "temperature",
                  "top_p",
                  "tools",
                ).merge(
                  "course_id" => course.id,
                  "default_llm_id" => params.model_mappings[item["key"]],
                  "subagent_ids" => item["delegates"].map { |key| records.fetch(key).id },
                  "upload_ids" => [],
                ),
            )
          unless result.success?
            exception = result["result.model.agent"]&.exception
            details =
              if exception.is_a?(ActiveRecord::RecordInvalid)
                exception.record.errors.full_messages.join(", ")
              elsif result["result.contract.default"]&.failure?
                result[:params].errors.full_messages.join(", ")
              else
                I18n.t("educustomize.invalid")
              end
            raise AgentConfiguration::Invalid, "#{item["key"]}: #{details}"
          end
          records[item["key"]] = result.agent
        end
      records
    end
  end
end
