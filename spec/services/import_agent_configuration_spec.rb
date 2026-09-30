# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::ImportAgentConfiguration do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:course_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:course) { Fabricate(:educustomize_course, created_by: acting_user) }
    fab!(:model, :fake_model)
    let(:document) do
      JSON.parse(File.read(File.expand_path("../fixtures/agent_configuration.json", __dir__)))
    end
    let(:params) do
      {
        course_id: course.id,
        document: document.deep_dup,
        model_mappings: document["agents"].to_h { |agent| [agent["key"], model.id] },
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.educustomize_model_ids = model.id.to_s
      SiteSetting.educustomize_tool_names = "Time"
    end

    context "when the configuration is invalid" do
      let(:document) { super().merge("schema_version" => 99) }
      it { is_expected.to fail_a_contract }
    end

    context "when the course is missing" do
      let(:params) { super().merge(course_id: -1) }
      it { is_expected.to fail_to_find_a_model(:course) }
    end

    context "when the actor teaches a different course" do
      fab!(:another_course, :educustomize_course)
      let(:params) { super().merge(course_id: another_course.id) }
      it { is_expected.to fail_a_policy(:course_teacher) }
    end

    context "when all configuration is authorized" do
      it "creates a new Dais with both Delegates and preserves every editable source field" do
        expect { result }.to change(AiAgent, :count).by(3).and change(
                DiscourseEducustomize::AgentLink,
                :count,
              ).by(3)
        expect(result).to run_successfully
        dais = result.agents.fetch("dais")
        expect(dais.subagent_ids).to eq(
          [result.agents.fetch("tutor").id, result.agents.fetch("critic").id],
        )
        document["agents"].each do |item|
          agent = result.agents.fetch(item["key"])
          link = course.agent_links.find_by!(ai_agent: agent)
          expect(link).to have_attributes(prompt: item["system_prompt"], skills: item["skills"])
          expect(agent).to have_attributes(
            name: item["name"],
            description: item["description"],
            default_llm_id: model.id,
            enabled: item["enabled"],
            temperature: item["temperature"],
            top_p: item["top_p"],
            tools: item["tools"],
            created_by_id: acting_user.id,
          )
          expect(agent.uploads).to be_empty
        end
      end
    end

    context "when a later database write is rejected" do
      before do
        ActiveRecord::Base.connection.add_check_constraint(
          :ai_agents,
          "name <> 'Import Dais'",
          name: "educustomize_spec_reject_dais",
        )
      end

      it "rolls back already-created Delegates, their links, and audit entries" do
        expect { result }.not_to change {
          [AiAgent.count, DiscourseEducustomize::AgentLink.count, UserHistory.count]
        }
        expect(result).to fail_to_find_a_model(:agents)
      end
    end
  end
end
