# frozen_string_literal: true

module DiscourseEducustomize
  # Reuse native reasoning decoding and tool-batch attribution without vLLM request options.
  class DeepseekEndpoint < DiscourseAi::Completions::Endpoints::Vllm
    def provider_id
      AiApiAuditLog::Provider::OpenAI
    end

    private

    def prepare_payload(prompt, model_params, dialect)
      DiscourseAi::Completions::Endpoints::OpenAi.instance_method(:prepare_payload).bind_call(
        self,
        prompt,
        model_params,
        dialect,
      )
    end

    def prepare_request(payload)
      DiscourseAi::Completions::Endpoints::OpenAi.instance_method(:prepare_request).bind_call(
        self,
        payload,
      )
    end

    def resolve_thinking_config(model_params)
      DiscourseAi::Completions::Endpoints::OpenAi.instance_method(
        :resolve_thinking_config,
      ).bind_call(self, model_params)
    end
  end
end
