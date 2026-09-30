# frozen_string_literal: true

module DiscourseEducustomize
  module RandomPickerOptions
    def max_invocations
      # RandomPicker#options contains choices; the base method expects tool settings.
      DiscourseAi::Agents::Tools::Tool.instance_method(:options).bind_call(self)[
        :max_invocations
      ].to_i
    end
  end
end
