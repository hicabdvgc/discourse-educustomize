# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::CreateCourse do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }
    it { is_expected.to allow_values("0099AA", "aabbcc").for(:color) }
    it { is_expected.not_to allow_values("red", "#0099AA").for(:color) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:approved_teachers, :group)
    fab!(:outsider, :user)
    let(:params) do
      { name: "Practical AI Course", description: "Study together.", color: "2288CC" }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.enable_category_group_moderation = true
      SiteSetting.educustomize_teacher_group = approved_teachers.id.to_s
      approved_teachers.add(acting_user)
    end

    context "when the contract is invalid" do
      let(:params) { { name: "" } }
      it { is_expected.to fail_a_contract }
    end

    context "when the teacher is unapproved" do
      before { approved_teachers.remove(acting_user) }
      it { is_expected.to fail_a_policy(:approved_teacher) }
      it "preserves the categories and groups" do
        expect { result }.not_to change { [Category.count, Group.count] }
      end
    end

    context "when no teacher group has been configured" do
      before { SiteSetting.educustomize_teacher_group = "" }
      it { is_expected.to fail_a_policy(:approved_teacher) }
    end
    context "when category moderation is unavailable" do
      before { SiteSetting.enable_category_group_moderation = false }
      it { is_expected.to fail_a_policy(:moderation_enabled) }
    end

    context "when the course is valid" do
      it "creates isolated native resources and scoped teacher authority" do
        expect(result).to run_successfully
        course = result.course
        expect(course.description).to eq(params[:description])
        expect(course.category.name).to eq(params[:name])
        expect(course.teacher_group.users).to include(acting_user)
        expect(course.student_group.group_users.find_by(user: acting_user)).to be_owner
        expect(acting_user.guardian.is_category_group_moderator?(course.category)).to eq(true)
        expect(outsider.guardian.can_see?(course.category)).to eq(false)
        expect(course.student_group).to be_public_admission
        expect(acting_user.reload).not_to be_moderator
      end

      it "records the actual actor" do
        expect { result }.to change { UserHistory.where(acting_user_id: acting_user.id).count }.by(
          1,
        )
      end
    end

    context "when the actor is an administrator" do
      fab!(:acting_user, :admin)
      before { approved_teachers.remove(acting_user) }
      it { is_expected.to run_successfully }
    end
  end
end
