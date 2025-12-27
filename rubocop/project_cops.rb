# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Project
      # Flags obvious ActiveRecord calls in ERB templates to discourage view-layer queries.
      class ArCallsInViews < Base
        include RangeHelp

        MSG = 'Avoid ActiveRecord calls in views; move data loading to a controller/service/presenter.'
        AR_CALL_REGEX = /\b([A-Z][A-Za-z0-9_:]+)\s*\.(find_by!?|find|where|order|sum|pluck|count|joins|includes|group)\b/.freeze

        def on_new_investigation
          return unless processed_source.path&.end_with?('.erb')

          processed_source.lines.each_with_index do |line, index|
            match = AR_CALL_REGEX.match(line)
            next unless match

            add_offense(range_for(line_number: index + 1, match: match))
          end
        end

        private

        def range_for(line_number:, match:)
          source_range(processed_source.buffer, line_number, match.begin(0), match[0].length)
        end
      end
    end
  end
end
