# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::PrepareTeaching do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:teacher_group, :group)
    fab!(:course, :educustomize_course)
    let(:params) { {} }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.educustomize_teacher_group = teacher_group.id.to_s
    end

    context "when the actor is a teacher" do
      fab!(:acting_user, :user)
      it { is_expected.to fail_a_policy(:administrator) }
    end

    context "when the teacher group is missing" do
      before { SiteSetting.educustomize_teacher_group = "" }
      it { is_expected.to fail_to_find_a_model(:teacher_group) }
    end

    context "when the teacher group is automatic" do
      before { SiteSetting.educustomize_teacher_group = Group::AUTO_GROUPS[:everyone].to_s }
      it { is_expected.to fail_to_find_a_model(:teacher_group) }
    end

    context "when the teacher group permits unreviewed admission" do
      before { teacher_group.update!(public_admission: true) }
      it { is_expected.to fail_a_policy(:reviewed_membership) }
    end

    context "when a non-administrator can approve teacher applications" do
      fab!(:owner, :user)
      before { teacher_group.add_owner(owner) }
      it { is_expected.to fail_a_policy(:reviewed_membership) }
    end

    context "when the teaching group has reviewed membership" do
      fab!(:existing_group, :group)
      fab!(:existing_template_category, :category)
      before do
        SiteSetting.assign_allowed_on_groups = existing_group.id.to_s
        SiteSetting.create_policy_allowed_groups = existing_group.id.to_s
        SiteSetting.discourse_post_event_allowed_on_groups = existing_group.id.to_s
        SiteSetting.discourse_templates_categories = existing_template_category.id.to_s
        SiteSetting.authorized_extensions = "jpg|png|svg"
        SiteSetting.workflow_executions_retention_days = 71
        SiteSetting.ai_audit_logs_purge_after_days = 91
      end

      it "prepares native teaching capabilities while retaining existing authorization and retention" do
        original_groups =
          DiscourseEducustomize::TeachingFeatures::GROUP_SETTINGS.to_h do |setting|
            [setting, DiscourseEducustomize::Access.ids(setting)]
          end
        expect(result).to run_successfully
        expect(teacher_group.reload).to have_attributes(
          allow_membership_requests: true,
          public_admission: false,
          visibility_level: Group.visibility_levels[:public],
        )
        expect(teacher_group.group_users.where(owner: true).pluck(:user_id)).to eq([acting_user.id])
        DiscourseEducustomize::TeachingFeatures::SWITCHES.each do |setting|
          expect(SiteSetting.public_send(setting)).to eq(true)
        end
        DiscourseEducustomize::TeachingFeatures::GROUP_SETTINGS.each do |setting|
          expect(DiscourseEducustomize::Access.ids(setting)).to match_array(
            original_groups.fetch(setting) | [teacher_group.id],
          )
        end
        expect(SiteSetting.authorized_extensions.split("|")).to contain_exactly(
          "jpg",
          "png",
          "svg",
          "pdf",
          "txt",
          "md",
          "docx",
          "pptx",
          "xlsx",
          "csv",
        )
        expect(SiteSetting.workflow_executions_retention_days).to eq(71)
        expect(SiteSetting.ai_audit_logs_purge_after_days).to eq(91)
        expect(
          Tag.where(
            name: %w[edu-discussion edu-announcement edu-material edu-question edu-feedback],
          ).count,
        ).to eq(5)
        expect(result.template_category.category_groups.pluck(:group_id, :permission_type)).to eq(
          [[teacher_group.id, CategoryGroup.permission_types[:full]]],
        )
        expect(
          DiscourseEducustomize::Access.ids(:discourse_templates_categories),
        ).to contain_exactly(existing_template_category.id, result.template_category.id)
        expect(course.category.reload.custom_fields["enable_accepted_answers"]).to eq("t")
        expect(
          UserHistory
            .where(acting_user_id: acting_user.id, action: UserHistory.actions[:custom_staff])
            .last
            .custom_type,
        ).to eq("educustomize_teaching_prepared")
      end

      it "reuses the teaching template category and tags on subsequent preparation" do
        expect(result).to run_successfully
        expect do
          repeated = described_class.call(params:, **dependencies)
          expect(repeated).to run_successfully
          expect(repeated.template_category.id).to eq(result.template_category.id)
        end.not_to change { [Category.count, Tag.count] }
      end
    end
  end
end
