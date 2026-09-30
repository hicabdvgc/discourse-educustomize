# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::UpdateCourse do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:course_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
    it { is_expected.not_to allow_value("bad-color").for(:color) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:course) { Fabricate(:educustomize_course, created_by: acting_user) }
    let(:params) do
      {
        course_id: course.id,
        name: "Updated Course",
        description: "Updated introduction.",
        color: "BB9988",
      }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.educustomize_enabled = true
      SiteSetting.enable_category_group_moderation = true
    end

    context "when the contract is invalid" do
      let(:params) { { course_id: course.id, name: "" } }
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
      it "preserves the other course" do
        expect { result }.not_to change { another_course.category.reload.name }
      end
    end

    context "when the actor has lost their course assignment" do
      before { course.teacher_group.remove(acting_user) }
      it { is_expected.to fail_a_policy(:course_teacher) }
    end

    context "when an image belongs to another user" do
      fab!(:upload)
      let(:params) { super().merge(uploaded_logo_id: upload.id) }
      it { is_expected.to fail_a_policy(:owns_images) }
    end

    context "when the image belongs to the teacher" do
      fab!(:upload) { Fabricate(:upload, user: acting_user) }
      let(:params) { super().merge(uploaded_logo_id: upload.id) }
      it "updates course information and image" do
        expect(result).to run_successfully
        expect(course.reload.description).to eq(params[:description])
        expect(course.category.reload).to have_attributes(
          name: params[:name],
          color: params[:color],
          uploaded_logo_id: upload.id,
        )
      end
    end

    context "when another teacher retains an existing course image" do
      fab!(:upload)
      before { course.category.update!(uploaded_logo_id: upload.id) }
      let(:params) { super().merge(uploaded_logo_id: upload.id) }
      it { is_expected.to run_successfully }
    end

    context "when the information is valid" do
      it { is_expected.to run_successfully }
      it "records the actual actor" do
        expect { result }.to change { UserHistory.where(acting_user_id: acting_user.id).count }.by(
          1,
        )
      end
    end
  end
end
