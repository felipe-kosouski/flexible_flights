# frozen_string_literal: true

module Search
  module Mappers
    class SearchRunMapper
      def self.apply(domain_run, search_run_record)
        search_run_record.state = domain_run.state
        search_run_record.started_at = domain_run.started_at
        search_run_record.finished_at = domain_run.finished_at
        search_run_record.error_message = domain_run.error&.message
        search_run_record
      end
    end
  end
end
