# frozen_string_literal: true

module DiscourseEducustomize
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseEducustomize
    config.autoload_paths << File.join(config.root, "lib")
  end
end
