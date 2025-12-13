module ActionDispatch
  module Routing
    class Mapper
      module Resources
        unless method_defined?(:resource_with_keyword_args)
          alias_method :resource_without_keyword_args, :resource

          def resource_with_keyword_args(name, *rest, **options, &block)
            if rest.first.is_a?(Hash)
              options = rest.shift.symbolize_keys.merge(options)
            end

            resource_without_keyword_args(name, **options, &block)
          end

          alias_method :resource, :resource_with_keyword_args
        end
      end
    end
  end
end
