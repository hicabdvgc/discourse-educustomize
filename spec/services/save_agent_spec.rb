# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::SaveAgent do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:course_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:system_prompt) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:course) { Fabricate(:educustomize_course, created_by: acting_user) }
    let(:params) do
      {
        course_id: course.id,
        name: "Course assistant",
        description: "Guides discussion",
        system_prompt: "Ask students to explain their reasoning.",
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { SiteSetting.educustomize_enabled = true }

    context "when the contract is invalid" do
      let(:params) { super().merge(system_prompt: "") }
      it { is_expected.to fail_a_contract }
    end

    context "when the course is missing" do
      let(:params) { super().merge(course_id: -1) }
      it { is_expected.to fail_to_find_a_model(:course) }
    end

    context "when the actor teaches another course" do
      fab!(:another_course, :educustomize_course)
      let(:params) { super().merge(course_id: another_course.id) }
      it { is_expected.to fail_a_policy(:course_teacher) }
    end

    context "when the agent belongs to another course" do
      fab!(:foreign_link, :educustomize_agent_link)
      let(:params) { super().merge(agent_id: foreign_link.ai_agent_id) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when a Delegate belongs to another course" do
      fab!(:foreign_link, :educustomize_agent_link)
      let(:params) { super().merge(subagent_ids: [foreign_link.ai_agent_id]) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when the model is outside the administrator allowlist" do
      fab!(:llm_model)
      let(:params) { super().merge(default_llm_id: llm_model.id) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when a tool could retrieve unrelated discussion" do
      before { SiteSetting.educustomize_tool_names = "Search|Time" }
      let(:params) { super().merge(tools: ["Search"]) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when an uploaded document belongs to another user" do
      fab!(:upload)
      let(:params) { super().merge(upload_ids: [upload.id]) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when a knowledge upload is saved before embeddings are configured" do
      fab!(:upload) { Fabricate(:upload, user: acting_user) }
      let(:params) { super().merge(upload_ids: [upload.id]) }
      it "retains the native upload association for later indexing" do
        expect(result).to run_successfully
        expect(result.agent.uploads.pluck(:id)).to eq([upload.id])
      end
    end

    context "when a Delegate already has its own Delegates" do
      fab!(:leaf_link) { Fabricate(:educustomize_agent_link, course:) }
      fab!(:dais_link) do
        Fabricate(
          :educustomize_agent_link,
          course:,
          ai_agent: Fabricate(:ai_agent, subagent_ids: [leaf_link.ai_agent_id]),
        )
      end
      let(:params) { super().merge(subagent_ids: [dais_link.ai_agent_id]) }
      it { is_expected.to fail_a_policy(:references_authorized) }
    end
    context "when no model is configured" do
      it "saves a disabled native agent and its course association" do
        expect(result).to run_successfully
        expect(result.agent).to have_attributes(
          default_llm_id: nil,
          enabled: false,
          system_prompt: params[:system_prompt],
          allowed_group_ids: [course.teacher_group_id],
        )
        expect(course.agent_links.pluck(:ai_agent_id)).to eq([result.agent.id])
      end
    end

    context "when model and tools are authorized" do
      fab!(:llm_model)
      before do
        SiteSetting.educustomize_model_ids = llm_model.id.to_s
        SiteSetting.educustomize_tool_names = "Time"
      end
      let(:params) { super().merge(default_llm_id: llm_model.id, tools: ["Time"], enabled: true) }
      it "saves authorized native configuration" do
        expect(result).to run_successfully
        expect(result.agent).to have_attributes(
          default_llm_id: llm_model.id,
          tools: ["Time"],
          enabled: true,
        )
      end
    end

    context "when composing a Bloc with two existing course Delegates" do
      fab!(:delegate_link) { Fabricate(:educustomize_agent_link, course:) }
      fab!(:second_delegate_link) { Fabricate(:educustomize_agent_link, course:) }
      let(:params) do
        super().merge(subagent_ids: [delegate_link.ai_agent_id, second_delegate_link.ai_agent_id])
      end
      it "stores the native subagent relationship" do
        expect(result).to run_successfully
        expect(result.agent.subagent_ids).to eq(
          [delegate_link.ai_agent_id, second_delegate_link.ai_agent_id],
        )
      end
    end

    context "when an assistant has ordered Skills" do
      let(:skills) do
        [
          {
            "name" => "Evidence",
            "description" => "Use references.",
            "instructions" => "Ask for supporting evidence.",
          },
          {
            "name" => "Reflection",
            "description" => "",
            "instructions" => "Ask for an alternative explanation.",
          },
        ]
      end
      let(:params) { super().merge(skills: skills.deep_dup) }

      it "stores editable source fields independently and composes native instructions in list order" do
        expect(result).to run_successfully
        link = course.agent_links.find_by!(ai_agent: result.agent)
        expect(link).to have_attributes(prompt: params[:system_prompt], skills: skills)
        expect(result.agent.system_prompt).to eq(
          "Ask students to explain their reasoning.\n\n## Skills\n\n### Evidence\n\nUse references.\n\nAsk for supporting evidence.\n\n### Reflection\n\n\n\nAsk for an alternative explanation.",
        )
      end
    end

    context "when an agent references itself" do
      fab!(:delegate_link) { Fabricate(:educustomize_agent_link, course:) }
      let(:params) do
        super().merge(
          agent_id: delegate_link.ai_agent_id,
          subagent_ids: [delegate_link.ai_agent_id],
        )
      end
      it { is_expected.to fail_a_policy(:references_authorized) }
    end

    context "when updating a course assistant" do
      fab!(:delegate_link) { Fabricate(:educustomize_agent_link, course:) }
      let(:params) { super().merge(agent_id: delegate_link.ai_agent_id) }
      it "keeps the existing association and logs the actual actor" do
        expect { result }.not_to change(DiscourseEducustomize::AgentLink, :count)
        expect(result).to run_successfully
        expect(delegate_link.ai_agent.reload.system_prompt).to eq(params[:system_prompt])
        expect(UserHistory.where(acting_user_id: acting_user.id).count).to eq(1)
      end
    end
  end
end
