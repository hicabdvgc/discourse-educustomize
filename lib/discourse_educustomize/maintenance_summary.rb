# frozen_string_literal: true

module DiscourseEducustomize
  class MaintenanceSummary
    def initialize(data)
      @data = data
    end

    def result
      course = @data.course
      policies =
        TopicPolicy.where(course: course, topic_id: @data.topics.reorder(nil).select(:id)).includes(
          :topic,
          :ai_agent,
        )
      {
        course: {
          id: course.id,
          name: course.category.name,
        },
        topics: @data.topic_options,
        dependencies: Access.dependencies.merge(data_explorer: ReportRunner.available?),
        retention: CourseData.retention,
        policies:
          policies.map do |policy|
            {
              topic_id: policy.topic_id,
              title: policy.topic.title,
              reasons: AiConfiguration.reasons(policy),
            }
          end,
        agents:
          course
            .agent_links
            .includes(ai_agent: :uploads)
            .map do |link|
              agent = link.ai_agent
              {
                id: agent.id,
                name: agent.name,
                enabled: agent.enabled,
                model_authorized: AiConfiguration.models.exists?(id: agent.default_llm_id),
                materials: AiConfiguration.knowledge_status(agent),
              }
            end,
      }
    end
  end
end
