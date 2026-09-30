# frozen_string_literal: true

module DiscourseEducustomize
  # The native vLLM dialect preserves reasoning_content and groups tools from one response.
  class DeepseekDialect < DiscourseAi::Completions::Dialects::Vllm
    def max_prompt_tokens
      DiscourseAi::Completions::Dialects::ChatGpt.instance_method(:max_prompt_tokens).bind_call(
        self,
      )
    end

    def embed_user_ids?
      DiscourseAi::Completions::Dialects::ChatGpt.instance_method(:embed_user_ids?).bind_call(self)
    end
  end
end
