# frozen_string_literal: true
DiscourseEducustomize::Engine.routes.draw do
  get "/admin" => "admin#index"
  post "/admin/workflow" => "admin#install_workflow"
  post "/admin/teaching" => "admin#prepare_teaching"
  put "/admin/workflow-retention" => "admin#workflow_retention"
  put "/admin/sampling" => "admin#sampling"
  get "/" => "courses#index"
  resources :courses, only: %i[index create show update] do
    post :join, on: :member
    get "learning" => "learning#show"
    resources :agents, only: %i[index create update]
    get "agents/:agent_id/configuration" => "agent_configurations#show"
    post "agent-configurations/preview" => "agent_configurations#preview"
    post "agent-configurations" => "agent_configurations#create"
    post "knowledge-upload" => "agents#upload"
    get "reports" => "reports#index"
    post "reports/:key/preview" => "reports#preview"
    post "reports/:key/download" => "reports#download"
    get "maintenance" => "maintenance#show"
    get "runs" => "maintenance#runs"
  end
  get "/topics/:topic_id" => "topics#show"
  put "/topics/:topic_id" => "topics#update"
  get "/topics/:topic_id/runs" => "runs#index"
  post "/topics/:topic_id/runs" => "runs#create"
  put "/topics/:topic_id/runs/:id" => "runs#update"
end
Discourse::Application.routes.draw do
  get "/admin/plugins/discourse-educustomize/courses" => "discourse_educustomize/admin#show",
      :constraints => AdminConstraint.new
  mount DiscourseEducustomize::Engine, at: "/educustomize"
end
