# frozen_string_literal: true

module DiscourseEducustomize
  class ReportRunner
    PREVIEW_LIMIT = 50

    def self.available?
      defined?(::DiscourseDataExplorer::DataExplorer).present? && SiteSetting.data_explorer_enabled
    end

    def initialize(data, key, filters)
      raise Discourse::InvalidAccess unless self.class.available?
      @data = data
      @query = ReportQuery.new(data, key, filters).query
    end

    def preview
      result =
        DiscourseDataExplorer::QueryRunner.run(
          @query,
          {},
          current_user: @data.guardian.user,
          limit: PREVIEW_LIMIT + 1,
        )
      raise result[:error] if result[:error]
      result[:truncated] = result[:rows].size > PREVIEW_LIMIT
      result[:rows] = result[:rows].first(PREVIEW_LIMIT)
      result[:result_count] = result[:rows].size
      result
    end

    def download(format)
      result =
        DiscourseDataExplorer::DataExplorer.run_query(
          @query,
          {},
          current_user: @data.guardian.user,
          limit: DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT,
        )
      raise result[:error] if result[:error]
      if result[:pg_result].ntuples >= DiscourseDataExplorer::QUERY_RESULT_MAX_LIMIT
        raise LimitExceeded
      end
      DiscourseDataExplorer::ResultFormatConverter.convert(format, result, download: true)
    end

    class LimitExceeded < StandardError
    end
  end
end
