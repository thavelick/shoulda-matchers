module Shoulda
  module Matchers
    module Doublespeak
      class MethodCall
        attr_accessor :return_value
        attr_reader :method_name, :args, :block, :object, :double

        def initialize(
          method_name:,
          args:,
          block: nil,
          object: nil,
          double: nil
        )
          @method_name = method_name
          @args = args
          @block = block
          @double = double
          @object = object
        end

        def with_return_value(return_value)
          dup.tap do |call|
            call.return_value = return_value
          end
        end
      end
    end
  end
end
