# frozen_string_literal: true
namespace :educustomize do
  desc "Install and authorize the controlled native course workflow (ADMIN_USERNAME required)"
  task install_workflow: :environment do
    admin = User.find_by!(username: ENV.fetch("ADMIN_USERNAME"))
    workflow = DiscourseEducustomize::WorkflowTemplate.install!(admin)
    puts "Installed workflow #{workflow.id}"
  end
end
