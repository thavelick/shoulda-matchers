module Shoulda
  module Matchers
    module Doublespeak
      # @private
      class ProxyImplementation
        extend Forwardable

        DoubleImplementationRegistry.register(self, :proxy)

        def_delegators :stub_implementation, :returns

        def self.create
          new(StubImplementation.new)
        end

        def initialize(stub_implementation)
          @stub_implementation = stub_implementation
        end

        def call(call)
          call.double.call_original_method(call).tap do |return_value|
            stub_implementation.call(call.with_return_value(return_value))
          end
        end

        protected

        attr_reader :stub_implementation
      end
    end
  end
end
