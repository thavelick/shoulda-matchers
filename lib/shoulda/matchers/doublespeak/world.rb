module Shoulda
  module Matchers
    module Doublespeak
      # @private
      class World
        def double_collection_for(klass)
          double_collections_by_class[klass] ||=
            DoubleCollection.new(self, klass)
        end

        def original_method_for(klass, method_name)
          original_methods_by_class[klass] ||=
            klass.instance_method(method_name)
        end

        def with_doubles_activated
          activate
          yield
        ensure
          deactivate
        end

        private

        def activate
          double_collections_by_class.each do |klass, double_collection|
            double_collection.activate
          end
        end

        def deactivate
          double_collections_by_class.each do |klass, double_collection|
            double_collection.deactivate
          end
        end

        def double_collections_by_class
          @_double_collections_by_class ||= {}
        end

        def original_methods_by_class
          @_original_methods_by_class ||= {}
        end
      end
    end
  end
end
