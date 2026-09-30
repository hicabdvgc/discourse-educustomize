# frozen_string_literal: true

module DiscourseEducustomize
  module DeepseekCompatibility
    def self.applies?(model)
      unless SiteSetting.educustomize_enabled && model.provider == "open_ai" &&
               model.respond_to?(:name) && model.name == "deepseek-flash"
        return false
      end
      uri = URI.parse(model.url.to_s)
      uri.scheme == "https" && uri.host == "api.deepseek.com" &&
        %w[/chat/completions /v1/chat/completions].include?(uri.path)
    rescue URI::InvalidURIError
      false
    end

    module EndpointSelection
      def endpoint_for(model)
        return DeepseekEndpoint if DeepseekCompatibility.applies?(model)
        super
      end
    end

    module DialectSelection
      def dialect_for(model)
        return DeepseekDialect if DeepseekCompatibility.applies?(model)
        super
      end
    end
  end
end
